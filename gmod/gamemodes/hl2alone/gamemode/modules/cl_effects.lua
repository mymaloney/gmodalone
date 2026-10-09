--[[
	The Effects panel's effects (panel UI in cl_effectspanel.lua).
	Recovered from client.dll (CEffectsPanel* and the view render code):

	View page   amod_view_* / amod_camera_* convars, drawn after the 3D view in
	            the original order: lens dirt, blue TV (binoculars), TV
	            (bodycam), black boxes, blur, filter_for_video1-8.
	            Black boxes: bars of amod_view_square_width/_height (+0.01) in
	            screen half-units. Claustrophobia: the view's aspect ratio set
	            to amod_view_claustrophobia_amt, plus its own fov.
	            Camera editor: per-frame lag (amt = blend factor), offsets in
	            view space, pitch limits.
	Lists       ConVars / Overlays / Lighting entries, each active while any of
	            its "active type" conditions holds (a bitmask, bit order below).
	Presets     the original .amf KeyValues ("AloneModFilter"), stored in
	            data/hl2alone/effects/<name>.txt.

	Lens dirt and blur recreate the mod's own shaders exactly (see drawBlur);
	other custom-shader materials fall back to stock rendering.
]]

local CV = HL2A.ConVars
local KV = HL2A.KV

HL2A.Effects = HL2A.Effects or {}
local E = HL2A.Effects

-- Conditions --------------------------------------------------------------------------

local LOW_HEALTH = 25

E.CONDITIONS = {
	{ "Always", function() return true end },
	{ "WhenFlashlightOn", function( p ) return p:GetNW2Bool( "hl2a.flashlight" ) end },
	{ "WhenFlashlightOff", function( p ) return not p:GetNW2Bool( "hl2a.flashlight" ) end },
	{ "WhenWalking", function( p ) return p:OnGround() and p:GetVelocity():Length2D() > 10 and not p:KeyDown( IN_SPEED ) end },
	{ "WhenSprinting", function( p ) return p:OnGround() and p:GetVelocity():Length2D() > 10 and p:KeyDown( IN_SPEED ) end },
	{ "WhenCrouching", function( p ) return p:Crouching() end },
	{ "WhenOnGround", function( p ) return p:OnGround() end },
	{ "WhenInAir", function( p ) return not p:OnGround() and p:WaterLevel() < 2 and p:GetMoveType() == MOVETYPE_WALK end },
	{ "WhenUnderWater", function( p ) return p:WaterLevel() >= 3 end },
	{ "WhenHealthLow", function( p ) return p:Health() <= LOW_HEALTH end },
	{ "WhenHoldingObject", function( p ) return p:GetNW2Bool( "hl2a.holding" ) end },
	{ "WhenUsingSuitZoom", function( p ) return p:KeyDown( IN_ZOOM ) end },
}

function E.Active( mask )
	local ply = LocalPlayer()
	if not IsValid( ply ) or not ply:Alive() then return false end
	mask = tonumber( mask ) or 0
	for i, c in ipairs( E.CONDITIONS ) do
		if bit.band( mask, bit.lshift( 1, i - 1 ) ) ~= 0 and c[ 2 ]( ply ) then return true end
	end
	return false
end

-- State (lists) -----------------------------------------------------------------------

local function emptyState() return { convars = {}, overlays = {}, lights = {} } end
E.State = E.State or emptyState()

local DIR = "hl2alone/effects/"
local SESSION = DIR .. "_session.json"

function E.SaveSession()
	file.CreateDir( "hl2alone/effects" )
	file.Write( SESSION, util.TableToJSON( E.State ) )
end

-- Screen materials ----------------------------------------------------------------------

local STOCK_SHADERS = {
	unlitgeneric = true, vertexlitgeneric = true, refract = true, screenspace_general = true,
	modulate = true, sprite = true, spritecard = true, unlittwotexture = true, lightmappedgeneric = true,
	wireframe = true, water = true, teeth = true, eyes = true, cable = true, shadow = true,
}

local function readVMT( path )
	local text = file.Read( "materials/" .. path .. ".vmt", "GAME" )
	if not text then return nil end
	local root = KV.Parse( text )
	local first = root and root[ 1 ]
	if not first then return nil end
	return first.key:lower(), istable( first.value ) and KV.ToTable( first.value ) or {}
end

local matCache = {}

--- Material for a full-screen overlay. Materials on the mod's custom shaders
-- are rebuilt as additive UnlitGeneric from their base texture.
function E.ScreenMaterial( path )
	path = path:gsub( "\\", "/" ):gsub( "%.vmt$", "" ):gsub( "%.$", "" ):lower()
	if matCache[ path ] ~= nil then return matCache[ path ] or nil end

	local shader, keys = readVMT( path )
	local mat
	if shader and not STOCK_SHADERS[ shader ] then
		local tex = keys[ "$basetexture" ]
		if not tex then
			for k, v in pairs( keys ) do if k:find( "texture", 1, true ) and isstring( v ) then tex = v break end end
		end
		if tex then
			mat = CreateMaterial( "hl2a_fx_" .. path:gsub( "[^%w]", "_" ), "UnlitGeneric", {
				[ "$basetexture" ] = tex, [ "$additive" ] = 1, [ "$vertexcolor" ] = 1, [ "$vertexalpha" ] = 1,
			} )
		end
	else
		mat = Material( path )
		if mat:IsError() then mat = nil end
	end

	matCache[ path ] = mat or false
	return mat
end

local function drawScreenMaterial( mat, color, alpha )
	if not mat then return end
	render.UpdateScreenEffectTexture()
	render.UpdateRefractTexture()

	local oldColor, oldAlpha
	if color then
		oldColor, oldAlpha = mat:GetVector( "$color" ), mat:GetFloat( "$alpha" )
		mat:SetVector( "$color", color )
		mat:SetFloat( "$alpha", alpha or 1 )
	end
	render.SetMaterial( mat )
	render.DrawScreenQuad()
	if color then
		mat:SetVector( "$color", oldColor or Vector( 1, 1, 1 ) )
		mat:SetFloat( "$alpha", oldAlpha or 1 )
	end
end

-- The mod's own screen shaders, recreated from their decompiled pixel
-- shaders (shaders/fxc/*_ps20b.vcs; settings from game_shader_dx9.dll):
--   blur:      5 horizontal taps at 0, +-0.001a, +-0.002a (UV), weights
--              0.4, 0.2, 0.1, then lerp( a, blurred, screen )   a = amod_blur_amount
--   lens dirt: screen + saturate( alpha ) * dirt * screen * intensity
--              (amod_lensdirt_intensity 1, amod_lensdirt_alpha 0.775)
-- Drawn with blend states into a scratch render target.

local fxRT, fxMat, screenMat
local function scratch()
	if fxRT then return end
	fxRT = GetRenderTargetEx( "hl2a_fx_scratch", ScrW(), ScrH(), RT_SIZE_FULL_FRAME_BUFFER,
		MATERIAL_RT_DEPTH_NONE, 0, 0, IMAGE_FORMAT_RGB888 )
	fxMat = CreateMaterial( "hl2a_fx_scratch", "UnlitGeneric", {
		[ "$basetexture" ] = fxRT:GetName(), [ "$ignorez" ] = 1, [ "$vertexcolor" ] = 1, [ "$vertexalpha" ] = 1, [ "$translucent" ] = 1,
	} )
	screenMat = CreateMaterial( "hl2a_fx_screen", "UnlitGeneric", {
		[ "$basetexture" ] = "_rt_FullFrameFB", [ "$ignorez" ] = 1, [ "$vertexcolor" ] = 1,
	} )
end

local BLUR_TAPS = { { 0, 0.4 }, { -0.001, 0.2 }, { 0.001, 0.2 }, { -0.002, 0.1 }, { 0.002, 0.1 } }

local function drawBlur( amount )
	if amount <= 0 then return end
	scratch()
	render.UpdateScreenEffectTexture()
	local w, h = ScrW(), ScrH()

	render.PushRenderTarget( fxRT )
		render.Clear( 0, 0, 0, 255 )
		cam.Start2D()
			render.OverrideBlend( true, BLEND_ONE, BLEND_ONE, BLENDFUNC_ADD )
			surface.SetMaterial( screenMat )
			for _, tap in ipairs( BLUR_TAPS ) do
				local du = tap[ 1 ] * amount
				local c = 255 * tap[ 2 ]
				surface.SetDrawColor( c, c, c, 255 )
				surface.DrawTexturedRectUV( 0, 0, w, h, du, 0, 1 + du, 1 )
			end
			render.OverrideBlend( false )
		cam.End2D()
	render.PopRenderTarget()

	-- lerp( amount, blurred, screen )
	cam.Start2D()
		surface.SetMaterial( fxMat )
		surface.SetDrawColor( 255, 255, 255, 255 * math.Clamp( amount, 0, 1 ) )
		surface.DrawTexturedRect( 0, 0, w, h )
	cam.End2D()
end

local dirtMats = {}

-- The dirt texture named in effects/view/lense_dirt.vmt (or an overlay's material)
local function dirtMaterial( path )
	if dirtMats[ path ] ~= nil then return dirtMats[ path ] or nil end
	local _, keys = readVMT( path )
	local tex
	for k, v in pairs( keys or {} ) do
		if isstring( v ) and k:find( "texture", 1, true ) and not v:lower():StartWith( "_rt_" ) then tex = v break end
	end
	tex = tex or path
	local m = file.Exists( "materials/" .. tex .. ".vtf", "GAME" )
		and CreateMaterial( "hl2a_fx_dirt_" .. tex:gsub( "[^%w]", "_" ), "UnlitGeneric", { [ "$basetexture" ] = tex, [ "$ignorez" ] = 1 } )
	dirtMats[ path ] = m or false
	return m or nil
end

--- strength = intensity * alpha; tint multiplies the dirt (overlays page colour)
local function drawLensDirt( path, strength, tint )
	local dirt = dirtMaterial( path )
	if not dirt or strength <= 0 then return end
	scratch()
	render.UpdateScreenEffectTexture()

	-- scratch = dirt * screen
	render.PushRenderTarget( fxRT )
		render.OverrideBlend( true, BLEND_ONE, BLEND_ZERO, BLENDFUNC_ADD )
		render.DrawTextureToScreen( render.GetScreenEffectTexture() )
		render.OverrideBlend( true, BLEND_DST_COLOR, BLEND_ZERO, BLENDFUNC_ADD )
		render.SetMaterial( dirt )
		render.DrawScreenQuad()
		render.OverrideBlend( false )
	render.PopRenderTarget()

	-- screen += scratch * strength
	tint = tint or Vector( 1, 1, 1 )
	cam.Start2D()
		render.OverrideBlend( true, BLEND_ONE, BLEND_ONE, BLENDFUNC_ADD )
		surface.SetMaterial( fxMat )
		surface.SetDrawColor( math.min( 255 * strength * tint.x, 255 ), math.min( 255 * strength * tint.y, 255 ), math.min( 255 * strength * tint.z, 255 ), 255 )
		surface.DrawTexturedRect( 0, 0, ScrW(), ScrH() )
		render.OverrideBlend( false )
	cam.End2D()
end

local LENS_DIRT = "effects/view/lense_dirt"

-- View page: screen effects ----------------------------------------------------------------

local VIEW_OVERLAYS = {
	{ "amod_view_binoculars", "effects/combine_binocoverlay" },
	{ "amod_view_bodycam", "effects/view/bodycam" },
}

local function drawBlackBoxes()
	local w, h = ScrW(), ScrH()
	-- Bar sizes are in screen half-units: 1 = half the screen
	local bw = math.Clamp( CV.amod_view_square_width:GetFloat() + 0.01, 0, 1 ) * w / 2
	local bh = math.Clamp( CV.amod_view_square_height:GetFloat() + 0.01, 0, 1 ) * h / 2
	cam.Start2D()
		surface.SetDrawColor( 0, 0, 0, 255 )
		surface.DrawRect( 0, 0, bw, h )
		surface.DrawRect( w - bw, 0, bw, h )
		surface.DrawRect( 0, 0, w, bh )
		surface.DrawRect( 0, h - bh, w, bh )
	cam.End2D()
end

hook.Add( "RenderScreenspaceEffects", "hl2a.effects", function()
	if not HL2A.PostProcessOn() then return end -- F2 (cl_screenfilter.lua)
	if CV.hl2a_noir:GetBool() then
		DrawColorModify( {
			[ "$pp_colour_addr" ] = 0, [ "$pp_colour_addg" ] = 0, [ "$pp_colour_addb" ] = 0,
			[ "$pp_colour_brightness" ] = -0.02, [ "$pp_colour_contrast" ] = 1.15, [ "$pp_colour_colour" ] = 0,
			[ "$pp_colour_mulr" ] = 0, [ "$pp_colour_mulg" ] = 0, [ "$pp_colour_mulb" ] = 0,
		} )
	end

	if CV.amod_view_lense_dirt:GetBool() then
		drawLensDirt( LENS_DIRT, CV.amod_lensdirt_intensity:GetFloat() * math.Clamp( CV.amod_lensdirt_alpha:GetFloat(), 0, 1 ) )
	end
	for _, o in ipairs( VIEW_OVERLAYS ) do
		if CV[ o[ 1 ] ]:GetBool() then drawScreenMaterial( E.ScreenMaterial( o[ 2 ] ) ) end
	end

	if CV.amod_view_square:GetBool() then drawBlackBoxes() end
	if CV.amod_view_blur:GetBool() then drawBlur( CV.amod_blur_amount:GetFloat() ) end

	for i = 1, 8 do
		if CV[ "amod_view_filter_video" .. i ]:GetBool() then
			drawScreenMaterial( E.ScreenMaterial( "effects/view/filter_for_video" .. i ) )
		end
	end

	-- Overlays page, in list order
	for _, o in ipairs( E.State.overlays ) do
		if E.Active( o.type ) then
			if o.name == LENS_DIRT then
				-- The lens dirt shader: the overlay's alpha is its alpha, the colour tints the dirt
				drawLensDirt( LENS_DIRT, CV.amod_lensdirt_intensity:GetFloat() * o.a / 255, Vector( o.r, o.g, o.b ) / 255 )
			else
				drawScreenMaterial( E.ScreenMaterial( o.name ), Vector( o.r / 255, o.g / 255, o.b / 255 ), o.a / 255 )
			end
		end
	end
end )

-- Viewmodel ---------------------------------------------------------------------------

hook.Add( "PreDrawViewModel", "hl2a.effects", function()
	if CV.hl2a_hide_viewmodel:GetBool() then return true end
end )

-- viewmodel_fov is an engine setting: set it while overriding, put it back after
local savedVMFov
local function applyViewmodelFov()
	if CV.hl2a_viewmodel_fov_override:GetBool() then
		local cvar = GetConVar( "viewmodel_fov" )
		if not cvar then return end
		savedVMFov = savedVMFov or cvar:GetString()
		RunConsoleCommand( "viewmodel_fov", tostring( math.Clamp( CV.hl2a_viewmodel_fov:GetFloat(), 5, 179 ) ) )
	elseif savedVMFov then
		RunConsoleCommand( "viewmodel_fov", savedVMFov )
		savedVMFov = nil
	end
end
cvars.AddChangeCallback( "hl2a_viewmodel_fov_override", function() timer.Simple( 0, applyViewmodelFov ) end, "hl2a.effects" )
cvars.AddChangeCallback( "hl2a_viewmodel_fov", function() timer.Simple( 0, applyViewmodelFov ) end, "hl2a.effects" )
hook.Add( "InitPostEntity", "hl2a.effects.vmfov", applyViewmodelFov )
hook.Add( "ShutDown", "hl2a.effects.vmfov", function()
	if savedVMFov then RunConsoleCommand( "viewmodel_fov", savedVMFov ) end
end )

-- Camera (CalcView is called from cl_view.lua) --------------------------------------------------

--- Aspect ratio to render with, or nil (claustrophobia; used by the RenderScene hook)
function E.Aspect()
	if CV.amod_view_claustrophobia:GetBool() then return math.max( CV.amod_view_claustrophobia_amt:GetFloat(), 0.05 ) end
end

local smoothPos, smoothAng
local lastEye, lastEyeAng

-- Blend factor for this frame: the original applied amt once per frame
local function blend( amt )
	return 1 - ( 1 - math.Clamp( amt, 0.001, 1 ) ) ^ ( FrameTime() * 60 )
end

function E.CalcView( ply, view )
	if CV.amod_view_claustrophobia:GetBool() then view.fov = CV.hl2a_claustrophobia_fov:GetFloat() end

	if not CV.amod_camera_cinematic:GetBool() then
		smoothPos, smoothAng = nil, nil
		return
	end

	lastEye, lastEyeAng = view.origin * 1, view.angles * 1

	local target, targetAng = view.origin, view.angles
	if not smoothPos or smoothPos:DistToSqr( target ) > 256 * 256 then smoothPos, smoothAng = target * 1, targetAng * 1 end

	smoothPos = CV.amod_camera_cinematic_lag_origin:GetBool()
		and LerpVector( blend( CV.amod_camera_cinematic_lag_origin_amt:GetFloat() ), smoothPos, target ) or target * 1
	smoothAng = CV.amod_camera_cinematic_lag_angles:GetBool()
		and LerpAngle( blend( CV.amod_camera_cinematic_lag_angles_amt:GetFloat() ), smoothAng, targetAng ) or targetAng * 1

	local off = HL2A.ParseVector( CV.amod_view_override_xyz_amt:GetString() ) or vector_origin
	local angOff = HL2A.ParseVector( CV.amod_view_override_pyr_amt:GetString() ) or vector_origin

	view.angles = smoothAng + Angle( angOff.x, angOff.y, angOff.z )
	view.origin = smoothPos + smoothAng:Forward() * off.x + smoothAng:Right() * off.y + smoothAng:Up() * off.z
end

-- Viewmodel follows the smoothed camera
hook.Add( "CalcViewModelView", "hl2a.effects", function( wep, vm, oldPos, oldAng, pos, ang )
	if not smoothPos or not lastEye or not CV.amod_camera_cinematic:GetBool() or not CV.amod_camera_cinematic_fix:GetBool() then return end
	local _, localAng = WorldToLocal( vector_origin, ang, vector_origin, lastEyeAng )
	local localPos = WorldToLocal( pos, angle_zero, lastEye, lastEyeAng )
	local newPos = LocalToWorld( localPos, angle_zero, smoothPos, smoothAng )
	local _, newAng = LocalToWorld( vector_origin, localAng, vector_origin, smoothAng )
	return newPos, newAng
end )

-- Pitch limits (cl_pitchdown / cl_pitchup in the original)
hook.Add( "CreateMove", "hl2a.effects", function( cmd )
	if not CV.amod_camera_cinematic:GetBool() then return end
	local down, up = math.min( CV.hl2a_pitch_down:GetFloat(), 89 ), math.min( CV.hl2a_pitch_up:GetFloat(), 89 )
	if down >= 89 and up >= 89 then return end
	local ang = cmd:GetViewAngles()
	local p = math.Clamp( ang.p, -up, down )
	if p ~= ang.p then
		ang.p = p
		cmd:SetViewAngles( ang )
	end
end )

-- ConVars page ------------------------------------------------------------------------------

-- Original engine convars and their equivalents in the port
E.CONVAR_ALIASES = {
	r_flashlightfov = "hl2a_flashlight_fov", r_flashlightfar = "hl2a_flashlight_far",
	hidehud = "hl2a_hidehud", sv_rollangle = "hl2a_rollangle",
}

local applied = {} -- convar -> { original = value before us, value = what we set }

local function updateConVars()
	local want = {}
	for _, c in ipairs( E.State.convars ) do
		local name = E.CONVAR_ALIASES[ c.name:lower() ] or c.name
		if E.Active( c.type ) then want[ name ] = c.value end
	end

	for name, value in pairs( want ) do
		local cvar = GetConVar( name )
		local a = applied[ name ]
		if cvar and ( not a or a.value ~= value ) then
			applied[ name ] = { original = a and a.original or cvar:GetString(), value = value }
			setConVar( name, value )
		end
	end
	for name, a in pairs( applied ) do
		if want[ name ] == nil then
			setConVar( name, a.original )
			applied[ name ] = nil
		end
	end
end

timer.Create( "hl2a.effects.convars", 0.1, 0, updateConVars )

hook.Add( "ShutDown", "hl2a.effects.convars", function()
	for name, a in pairs( applied ) do
		if HL2A.ClientConVars[ name ] or not HL2A.ConVars[ name ] then RunConsoleCommand( name, a.original ) end
	end
end )

-- Lighting page -----------------------------------------------------------------------------

E.LIGHT_TYPES = { "Dynamic", "DynamicELight", "DynamicFlashLight" }
E.MOVEMENT_MODES = { "Static", "FollowEyes", "ParentToMuzzle", "ParentToEntCName", "ParentToEntName",
	"ParentToEntMName", "ParentToAllEntCName", "ParentToAllEntName", "ParentToAllEntMName" }

local MAX_TARGETS = 16
local projected = {} -- key -> ProjectedTexture

local function findEntities( mode, value )
	value = ( value or "" ):lower()
	if value == "" then return {} end
	local out = {}
	local kind = ( mode - 4 ) % 3 -- 0 classname, 1 targetname, 2 model
	for _, ent in ipairs( ents.GetAll() ) do
		local v
		if kind == 0 then v = ent:GetClass()
		elseif kind == 1 then v = ent:GetName()
		else v = ent:GetModel() end
		if v and v:lower() == value then
			out[ #out + 1 ] = ent
			if mode <= 6 or #out >= MAX_TARGETS then break end -- single-entity modes stop at the first
		end
	end
	return out
end

local function attachmentOf( ent, name )
	if name and name ~= "" then
		local id = ent:LookupAttachment( name )
		local att = id and id > 0 and ent:GetAttachment( id )
		if att then return att.Pos, att.Ang end
	end
	return ent:GetPos(), ent:GetAngles()
end

--- World positions/angles a light sits at this frame
function E.LightPlacements( l )
	local ply = LocalPlayer()
	local mode = ( tonumber( l.movement ) or 0 ) + 1
	local bases = {}

	if mode == 1 then
		bases[ 1 ] = { l.origin, l.angle }
	elseif mode == 2 then
		bases[ 1 ] = { ply:EyePos(), ply:EyeAngles() }
	elseif mode == 3 then
		local vm = ply:GetViewModel()
		local id = IsValid( vm ) and vm:LookupAttachment( "muzzle" ) or 0
		local att = id > 0 and vm:GetAttachment( id )
		bases[ 1 ] = att and { att.Pos, att.Ang } or { ply:EyePos(), ply:EyeAngles() }
	else
		for _, ent in ipairs( findEntities( mode, l.entity ) ) do
			bases[ #bases + 1 ] = { attachmentOf( ent, l.attachment ) }
		end
	end

	local out = {}
	for i, b in ipairs( bases ) do
		local pos, ang = b[ 1 ], b[ 2 ]
		local o, ao = l.offset, l.angleOffset
		out[ i ] = {
			pos = pos + ang:Forward() * o.x + ang:Right() * o.y + ang:Up() * o.z,
			ang = ang + Angle( ao.x, ao.y, ao.z ),
		}
	end
	return out
end

local function removeProjected( key )
	if IsValid( projected[ key ] ) then projected[ key ]:Remove() end
	projected[ key ] = nil
end

hook.Add( "Think", "hl2a.effects.lights", function()
	local ply = LocalPlayer()
	if not IsValid( ply ) then return end

	local used = {}
	for li, l in ipairs( E.State.lights ) do
		if E.Active( l.type ) then
			local c = l.color
			for pi, p in ipairs( E.LightPlacements( l ) ) do
				local mode = tonumber( l.mode ) or 0
				if mode == 2 then
					local key = li .. ":" .. pi
					used[ key ] = true
					local pt = projected[ key ]
					if not IsValid( pt ) then
						pt = ProjectedTexture()
						pt:SetTexture( "effects/flashlight001" )
						projected[ key ] = pt
					end
					pt:SetPos( p.pos )
					pt:SetAngles( p.ang )
					pt:SetFarZ( math.max( l.distance, 16 ) )
					pt:SetFOV( math.Clamp( l.fov, 1, 179 ) )
					pt:SetColor( Color( c.r, c.g, c.b ) )
					pt:SetBrightness( c.a / 255 * 2 )
					pt:Update()
				else
					local d = DynamicLight( 4000 + li * MAX_TARGETS + pi, mode == 1 )
					if d then
						d.pos = p.pos
						d.r, d.g, d.b = c.r, c.g, c.b
						d.brightness = c.a / 255 * 2
						d.decay = 0
						d.size = l.distance
						d.dietime = CurTime() + 0.2
					end
				end
			end
		end
	end

	for key in pairs( projected ) do
		if not used[ key ] then removeProjected( key ) end
	end
end )

hook.Add( "ShutDown", "hl2a.effects.lights", function()
	for key in pairs( projected ) do removeProjected( key ) end
end )

-- Lighting debug: where each light is and what it is
hook.Add( "PostDrawTranslucentRenderables", "hl2a.effects.lightdebug", function( _, sky )
	if sky or not CV.amod_lighting_debug:GetBool() then return end
	for _, l in ipairs( E.State.lights ) do
		local active = E.Active( l.type )
		for _, p in ipairs( E.LightPlacements( l ) ) do
			render.DrawWireframeSphere( p.pos, 4, 8, 8, active and Color( 0, 255, 0 ) or Color( 255, 0, 0 ), true )
			render.DrawLine( p.pos, p.pos + p.ang:Forward() * 32, Color( 255, 255, 0 ), true )
		end
	end
end )

hook.Add( "HUDPaint", "hl2a.effects.lightdebug", function()
	if not CV.amod_lighting_debug:GetBool() then return end
	for _, l in ipairs( E.State.lights ) do
		for _, p in ipairs( E.LightPlacements( l ) ) do
			local s = p.pos:ToScreen()
			if s.visible then
				local kind = ( { "dynamic light", "environmental light", "flashlight" } )[ ( tonumber( l.mode ) or 0 ) + 1 ]
				draw.SimpleText( "Name = " .. l.name, "DebugFixed", s.x, s.y, color_white )
				draw.SimpleText( "Type = " .. ( kind or "?" ), "DebugFixed", s.x, s.y + 12, color_white )
			end
		end
	end
end )

-- Presets (.amf) -------------------------------------------------------------------------------

local function vec( str ) return HL2A.ParseVector( str ) or Vector( 0, 0, 0 ) end
local function num( v, d ) return tonumber( v ) or d end

local function parseColor( str )
	local r, g, b, a = ( str or "" ):match( "(%-?%d+)%s+(%-?%d+)%s+(%-?%d+)%s*(%-?%d*)" )
	return { r = num( r, 255 ), g = num( g, 255 ), b = num( b, 255 ), a = num( a, 255 ) }
end

function E.NewLight()
	return {
		name = "Light 1", mode = 0, movement = 0, type = 1,
		offset = Vector( 0, 0, 0 ), angleOffset = Vector( 0, 0, 0 ),
		origin = Vector( 0, 0, 0 ), angle = Angle( 0, 0, 0 ),
		entity = "", attachment = "", color = { r = 255, g = 255, b = 255, a = 255 },
		distance = 750, fov = 45,
	}
end

-- View keys <-> convars. Slider units are the panel's; see cl_effectspanel.lua.
local function smoothSlider( lagName )
	return CV[ lagName ]:GetBool() and math.Round( CV[ lagName .. "_amt" ]:GetFloat() / 0.002 ) or 50
end

E.VIEW_KEYS = {
	{ "ViewModel:Draw", function() return CV.hl2a_hide_viewmodel:GetBool() and 0 or 1 end,
		function( v ) RunConsoleCommand( "hl2a_hide_viewmodel", tobool( v ) and "0" or "1" ) end },
	{ "ViewModel:OverrideFov", "hl2a_viewmodel_fov_override" },
	{ "ViewModel:FovAmount", function() return CV.hl2a_viewmodel_fov:GetInt() end,
		function( v ) RunConsoleCommand( "hl2a_viewmodel_fov", tostring( math.Clamp( num( v, 54 ), 5, 360 ) ) ) end },
	{ "Filter:BlackAndWhite", "hl2a_noir" },
	{ "Filter:LenseDirt", "amod_view_lense_dirt" },
	{ "Filter:TvView", "amod_view_bodycam" },
	{ "Filter:ColoredTvView", "amod_view_binoculars" },
	{ "Filter:BluredView", "amod_view_blur" },
	{ "Filter:BlackBoxes:Enable", "amod_view_square" },
	{ "Filter:BlackBoxes:Width", function() return math.Round( CV.amod_view_square_width:GetFloat() * 30 ) end,
		function( v ) RunConsoleCommand( "amod_view_square_width", tostring( num( v, 0 ) / 30 ) ) end },
	{ "Filter:BlackBoxes:Height", function() return math.Round( CV.amod_view_square_height:GetFloat() * 30 ) end,
		function( v ) RunConsoleCommand( "amod_view_square_height", tostring( num( v, 6 ) / 30 ) ) end },
	{ "Filter:Claustraphobia:Enable", "amod_view_claustrophobia" },
	{ "Filter:Claustraphobia:Amount", function() return math.Round( CV.amod_view_claustrophobia_amt:GetFloat() * 4 ) end,
		function( v ) RunConsoleCommand( "amod_view_claustrophobia_amt", tostring( num( v, 7 ) * 0.25 ) ) end },
	{ "Filter:Claustraphobia:Fov", "hl2a_claustrophobia_fov" },
	{ "Camera:EnableEditor", "amod_camera_cinematic" },
	{ "Camera:ViewmodelFix", "amod_camera_cinematic_fix" },
	{ "Camera:SmoothAnglesAmount", function() return smoothSlider( "amod_camera_cinematic_lag_angles" ) end,
		function( v ) E.SetSmooth( "amod_camera_cinematic_lag_angles", num( v, 50 ) ) end },
	{ "Camera:SmoothOriginAmount", function() return smoothSlider( "amod_camera_cinematic_lag_origin" ) end,
		function( v ) E.SetSmooth( "amod_camera_cinematic_lag_origin", num( v, 50 ) ) end },
	{ "Camera:MinPitch", function() return CV.hl2a_pitch_down:GetInt() >= 89 and 181 or CV.hl2a_pitch_down:GetInt() end,
		function( v ) E.SetPitch( "hl2a_pitch_down", num( v, 181 ) ) end },
	{ "Camera:MaxPitch", function() return CV.hl2a_pitch_up:GetInt() >= 89 and 181 or CV.hl2a_pitch_up:GetInt() end,
		function( v ) E.SetPitch( "hl2a_pitch_up", num( v, 181 ) ) end },
	{ "Camera:OriginOffset", "amod_view_override_xyz_amt" },
	{ "Camera:AngleOffset", "amod_view_override_pyr_amt" },
}

--- Smoothing slider (50 = off ... 2 = smoothest) -> lag convars, as the original panel did
function E.SetSmooth( lagName, slider )
	RunConsoleCommand( lagName, slider ~= 50 and "1" or "0" )
	RunConsoleCommand( lagName .. "_amt", tostring( slider * 0.002 ) )
end

--- Pitch slider (181 = no limit) -> degrees
function E.SetPitch( name, slider )
	RunConsoleCommand( name, tostring( slider == 181 and 89 or slider ) )
end

function E.GetViewValue( entry )
	local get = entry[ 2 ]
	if isfunction( get ) then return get() end
	return CV[ get ]:GetString()
end

function E.SetViewValue( entry, value )
	local set = entry[ 3 ] or entry[ 2 ]
	if isfunction( set ) then set( value ) else RunConsoleCommand( set, tostring( value ) ) end
end

function E.ResetView()
	for _, entry in ipairs( E.VIEW_KEYS ) do
		local name = entry[ 2 ]
		if isstring( name ) then RunConsoleCommand( name, CV[ name ]:GetDefault() ) end
	end
	for _, name in ipairs( { "hl2a_hide_viewmodel", "hl2a_viewmodel_fov", "amod_view_square_width", "amod_view_square_height",
		"amod_view_claustrophobia_amt", "amod_camera_cinematic_lag_angles", "amod_camera_cinematic_lag_angles_amt",
		"amod_camera_cinematic_lag_origin", "amod_camera_cinematic_lag_origin_amt", "hl2a_pitch_down", "hl2a_pitch_up" } ) do
		RunConsoleCommand( name, CV[ name ]:GetDefault() )
	end
end

function E.Reset()
	E.ResetView()
	E.State = emptyState()
	E.SaveSession()
end

--- Adds a parsed .amf ("AloneModFilter") to the current effects: view values
-- are applied, list entries appended (same-named overlays/lights replaced).
function E.Apply( root )
	local view = KV.Get( root, "View" )
	if istable( view ) then
		for _, entry in ipairs( E.VIEW_KEYS ) do
			local v = KV.Get( view, entry[ 1 ] )
			if v ~= nil then E.SetViewValue( entry, v ) end
		end
	end

	for _, c in ipairs( KV.GetAll( KV.Get( root, "ConVars" ), "Convar" ) ) do
		if istable( c ) and KV.Get( c, "Convar" ) then
			E.State.convars[ #E.State.convars + 1 ] = { name = KV.Get( c, "Convar" ), value = KV.Get( c, "value" ) or "", type = num( KV.Get( c, "type" ), 1 ) }
		end
	end

	for _, o in ipairs( KV.GetAll( KV.Get( root, "Overlays" ), "Overlay" ) ) do
		if istable( o ) and KV.Get( o, "OverlayName" ) then
			local name = KV.Get( o, "OverlayName" ):lower()
			for i = #E.State.overlays, 1, -1 do
				if E.State.overlays[ i ].name == name then table.remove( E.State.overlays, i ) end
			end
			E.State.overlays[ #E.State.overlays + 1 ] = {
				name = name, r = num( KV.Get( o, "Red" ), 255 ), g = num( KV.Get( o, "Green" ), 255 ),
				b = num( KV.Get( o, "Blue" ), 255 ), a = num( KV.Get( o, "Alpha" ), 255 ), type = num( KV.Get( o, "DrawType" ), 1 ),
			}
		end
	end

	for _, l in ipairs( KV.GetAll( KV.Get( root, "Lighting" ), "Light" ) ) do
		if istable( l ) then
			local light = E.NewLight()
			light.name = KV.Get( l, "Name" ) or light.name
			light.mode = num( KV.Get( l, "Mode" ), 0 )
			light.movement = num( KV.Get( l, "MovementMode" ), 0 )
			light.type = num( KV.Get( l, "ActiveType" ), 1 )
			light.offset = vec( KV.Get( l, "Offset" ) )
			light.angleOffset = vec( KV.Get( l, "AngleOffset" ) )
			light.origin = vec( KV.Get( l, "Origin" ) )
			local a = vec( KV.Get( l, "Angle" ) )
			light.angle = Angle( a.x, a.y, a.z )
			light.entity = KV.Get( l, "Entity" ) or ""
			light.attachment = KV.Get( l, "EntityAttachment" ) or ""
			light.color = parseColor( KV.Get( l, "Color" ) )
			light.distance = num( KV.Get( l, "Distance" ), 750 )
			light.fov = num( KV.Get( l, "Fov" ), 45 )
			for i = #E.State.lights, 1, -1 do
				if E.State.lights[ i ].name == light.name then table.remove( E.State.lights, i ) end
			end
			E.State.lights[ #E.State.lights + 1 ] = light
		end
	end

	E.SaveSession()
end

local function q( s ) return '"' .. tostring( s ):gsub( '"', "'" ) .. '"' end
local function v3( v ) return string.format( "%.4f %.4f %.4f", v.x or v.p or 0, v.y or 0, v.z or v.r or 0 ) end
local function a3( a ) return string.format( "%.4f %.4f %.4f", a.p, a.y, a.r ) end

--- The current effects as .amf text
function E.Serialize()
	local out = { '"AloneModFilter"', "{", '\t"View"', "\t{" }
	for _, entry in ipairs( E.VIEW_KEYS ) do
		out[ #out + 1 ] = "\t\t" .. q( entry[ 1 ] ) .. "\t\t" .. q( E.GetViewValue( entry ) )
	end
	out[ #out + 1 ] = "\t}"

	out[ #out + 1 ] = '\t"ConVars"'
	out[ #out + 1 ] = "\t{"
	for _, c in ipairs( E.State.convars ) do
		out[ #out + 1 ] = '\t\t"Convar"\n\t\t{\n\t\t\t"Convar"\t\t' .. q( c.name ) .. '\n\t\t\t"value"\t\t' .. q( c.value )
			.. '\n\t\t\t"type"\t\t' .. q( c.type ) .. "\n\t\t}"
	end
	out[ #out + 1 ] = "\t}"

	out[ #out + 1 ] = '\t"Overlays"'
	out[ #out + 1 ] = "\t{"
	for _, o in ipairs( E.State.overlays ) do
		out[ #out + 1 ] = '\t\t"Overlay"\n\t\t{\n\t\t\t"OverlayName"\t\t' .. q( o.name ) .. '\n\t\t\t"Red"\t\t' .. q( o.r )
			.. '\n\t\t\t"Green"\t\t' .. q( o.g ) .. '\n\t\t\t"Blue"\t\t' .. q( o.b ) .. '\n\t\t\t"Alpha"\t\t' .. q( o.a )
			.. '\n\t\t\t"DrawType"\t\t' .. q( o.type ) .. "\n\t\t}"
	end
	out[ #out + 1 ] = "\t}"

	out[ #out + 1 ] = '\t"Lighting"'
	out[ #out + 1 ] = "\t{"
	for _, l in ipairs( E.State.lights ) do
		local c = l.color
		local fields = {
			{ "Name", l.name }, { "Mode", l.mode }, { "MovementMode", l.movement }, { "Offset", v3( l.offset ) },
			{ "AngleOffset", v3( l.angleOffset ) }, { "ActiveType", l.type }, { "Origin", v3( l.origin ) },
			{ "Angle", a3( l.angle ) }, { "Entity", l.entity }, { "EntityAttachment", l.attachment },
			{ "Color", string.format( "%d %d %d %d", c.r, c.g, c.b, c.a ) }, { "Distance", l.distance }, { "Fov", l.fov },
		}
		local lines = { '\t\t"Light"', "\t\t{" }
		for _, f in ipairs( fields ) do lines[ #lines + 1 ] = "\t\t\t" .. q( f[ 1 ] ) .. "\t\t" .. q( f[ 2 ] ) end
		lines[ #lines + 1 ] = "\t\t}"
		out[ #out + 1 ] = table.concat( lines, "\n" )
	end
	out[ #out + 1 ] = "\t}"
	out[ #out + 1 ] = "}"
	return table.concat( out, "\n" ) .. "\n"
end

local function cleanName( name )
	return ( name or "" ):lower():gsub( "%.amf$", "" ):gsub( "%.txt$", "" ):gsub( "[^%w_%-%. /]", "_" ):gsub( "^/+", "" )
end

function E.SavePreset( name )
	name = cleanName( name )
	if name == "" then return false end
	local path = DIR .. name .. ".txt"
	file.CreateDir( ( path:match( "^(.*)/" ) ) )
	file.Write( path, E.Serialize() )
	return file.Exists( path, "DATA" ), path
end

local EXAMPLES = "scripts/filters examples/"

--- Saved presets ("name") and the mod's bundled examples ("examples/name")
function E.ListPresets()
	local out = {}
	for _, f in ipairs( file.Find( DIR .. "*.txt", "DATA" ) ) do
		if f ~= "_session.txt" then out[ #out + 1 ] = f:gsub( "%.txt$", "" ) end
	end
	local _, dirs = file.Find( DIR .. "*", "DATA" )
	for _, d in ipairs( dirs or {} ) do out[ #out + 1 ] = d .. "/" end
	for _, rel in ipairs( HL2A.FindFiles( EXAMPLES .. "*.txt" ) ) do
		out[ #out + 1 ] = "examples/" .. rel:sub( #EXAMPLES + 1 ):gsub( "%.amf%.txt$", "" ):gsub( "%.txt$", "" )
	end
	table.sort( out )
	return out
end

local function readPreset( name )
	if name:StartWith( "examples/" ) then
		local base = EXAMPLES .. name:sub( 10 )
		return HL2A.ReadFile( base .. ".amf" ) or HL2A.ReadFile( base )
	end
	return file.Read( DIR .. cleanName( name ) .. ".txt", "DATA" )
end

function E.LoadPreset( name )
	local text = readPreset( name )
	local root = text and KV.Parse( text )
	local block = root and KV.Get( root, "AloneModFilter" )
	if not istable( block ) then return false end
	E.Apply( block )
	return true
end

-- Autoload ------------------------------------------------------------------------------

function E.AutoloadList()
	local out = {}
	for part in CV.amod_effects_panel_autoload_files:GetString():gmatch( "[^;]+" ) do
		part = part:Trim()
		if part ~= "" then out[ #out + 1 ] = part end
	end
	return out
end

function E.SetAutoloadList( list )
	RunConsoleCommand( "amod_effects_panel_autoload_files", table.concat( list, ";" ) )
end

-- A file named after a map only loads on that map
local function mapAllows( name )
	local base = name:match( "([^/]+)$" ) or name
	local isMap = file.Exists( "maps/" .. base .. ".bsp", "GAME" )
	return not isMap or base == HL2A.Map()
end

function E.RunAutoload()
	for _, entry in ipairs( E.AutoloadList() ) do
		if entry:EndsWith( "/" ) then
			local folder = cleanName( entry:sub( 1, -2 ) )
			for _, f in ipairs( file.Find( DIR .. folder .. "/*.txt", "DATA" ) ) do
				local name = folder .. "/" .. f:gsub( "%.txt$", "" )
				if mapAllows( name ) then E.LoadPreset( name ) end
			end
		elseif mapAllows( entry ) then
			E.LoadPreset( entry )
		end
	end
end

hook.Add( "InitPostEntity", "hl2a.effects.load", function()
	if CV.hl2a_effects_autoload:GetBool() then
		-- Lists start empty each map and are rebuilt from the autoload presets
		E.State = emptyState()
		E.RunAutoload()
	else
		-- Otherwise the effects carry over from the last map
		local saved = util.JSONToTable( file.Read( SESSION, "DATA" ) or "" )
		if istable( saved ) then
			E.State = emptyState()
			for k in pairs( E.State ) do
				if istable( saved[ k ] ) then E.State[ k ] = saved[ k ] end
			end
			for _, l in ipairs( E.State.lights ) do
				-- JSON keeps vectors/angles as tables
				l.offset = Vector( l.offset.x or 0, l.offset.y or 0, l.offset.z or 0 )
				l.angleOffset = Vector( l.angleOffset.x or 0, l.angleOffset.y or 0, l.angleOffset.z or 0 )
				l.origin = Vector( l.origin.x or 0, l.origin.y or 0, l.origin.z or 0 )
				l.angle = Angle( l.angle.p or l.angle.pitch or 0, l.angle.y or l.angle.yaw or 0, l.angle.r or l.angle.roll or 0 )
			end
		end
	end
end )

concommand.Add( "hl2a_effects_load", function( _, _, _, argStr )
	MsgN( E.LoadPreset( argStr:Trim() ) and "[HL2A] loaded effects preset " .. argStr or "[HL2A] couldn't load preset '" .. argStr .. "'" )
end, nil, "Add an Effects panel preset (see hl2a_effects_list)" )

concommand.Add( "hl2a_effects_list", function()
	for _, n in ipairs( E.ListPresets() ) do MsgN( "  " .. n ) end
end, nil, "List Effects panel presets" )

concommand.Add( "hl2a_effects_reset", function() E.Reset() end, nil, "Clear every Effects panel effect" )
