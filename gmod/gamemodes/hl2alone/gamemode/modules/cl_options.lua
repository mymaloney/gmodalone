--[[
	Options panel (ToggleOptionsPanel), laid out like the mod's
	resource/panels/OptionsPanel.txt and using its localization strings.
	Changes are staged and sent to the server on "Apply Settings".

	Left out on purpose: Daytime (shelved) and the Credits / Ending
	controls. The original's filter section, saturation and vignette now
	live on the Post-Processing & Effects panel's Look tab.

	Also implements the mirrored view (amod_mirrored).
]]

local CV = HL2A.ConVars

--- Sets convars from { { name, value } }: client settings directly, the
-- gamemode's server settings through the server (listen host only)
function HL2A.SetConVars( list )
	local server = {}
	for _, kv in ipairs( list ) do
		local cvar = GetConVar( kv[ 1 ] )
		if HL2A.ClientConVars[ kv[ 1 ] ] or not HL2A.ConVars[ kv[ 1 ] ] then
			RunConsoleCommand( kv[ 1 ], tostring( kv[ 2 ] ) )
		elseif cvar then
			server[ #server + 1 ] = kv
		end
	end
	if #server == 0 then return end
	net.Start( "hl2a.options" )
		net.WriteUInt( #server, 8 )
		for _, kv in ipairs( server ) do net.WriteString( kv[ 1 ] ) net.WriteString( tostring( kv[ 2 ] ) ) end
	net.SendToServer()
end

--- Puts every convar in names back to its default
function HL2A.ResetConVars( names )
	local list = {}
	for _, name in ipairs( names ) do
		local cvar = GetConVar( name )
		if cvar then list[ #list + 1 ] = { name, cvar:GetDefault() } end
	end
	HL2A.SetConVars( list )
end

local function phrase( token ) return language.GetPhrase( ( token:gsub( "^#", "" ) ) ) end

-- x, y, w, h are the original panel's VGUI coordinates (475 x 405 panel)
local LAYOUT = {
	{ "label", 35, 19, 225, 20, "#AMod_OptionsPanel_ViewTitle" },
	{ "check", 5, 35, 225, "hl2a_nofootsteps", "#AMod_OptionsPanel_View_DisableFootstepSounds" },
	{ "check", 5, 53, 225, "hl2a_hidehud", "#AMod_OptionsPanel_View_DisableHud", "#AMod_OptionsPanel_View_DisableHud_ToolTip" },
	{ "check", 5, 71, 225, "amod_mirrored", "#AMod_OptionsPanel_View_EnableMirroredView", "#AMod_OptionsPanel_View_EnableMirroredView_Tooltip" },
	{ "check", 5, 89, 225, "amod_viewbob_enabled", "#AMod_OptionsPanel_View_EnableCameraBob", "#AMod_OptionsPanel_View_EnableCameraBob_ToolTip" },
	{ "check", 5, 108, 225, "amod_standbob_enabled", "#AMod_OptionsPanel_View_EnableCameraStandBob", "#AMod_OptionsPanel_View_EnableCameraStandBob_ToolTip" },
	{ "check", 5, 126, 225, "amod_jump_punch_enable", "#AMod_OptionsPanel_View_EnableJumpViewpunch", "#AMod_OptionsPanel_View_EnableJumpViewpunch_ToolTip" },
	{ "check", 5, 144, 225, "amod_land_punch_enable", "#AMod_OptionsPanel_View_EnableLandViewpunch", "#AMod_OptionsPanel_View_EnableLandViewpunch_ToolTip" },
	{ "slider", 10, 167, 115, "hl2a_rollangle", 0, 10 },
	{ "label", 130, 163, 110, 30, "#AMod_OptionsPanel_View_EnableCameraRoll_Text" },
	{ "divider", 0, 197, 236, 2 },
	-- Look (colour grade, faded, saturation, vignette, bloom) moved to the
	-- Post-Processing & Effects panel
	{ "button", 5, 210, 225, 24, "Post-Processing & Effects...", function() HL2A.ToggleEffectsPanel() end },
	{ "divider", 235, 0, 2, 405 },

	{ "label", 285, 10, 150, 20, "#AMod_OptionsPanel_FlashlightTitle" },
	{ "combo", 245, 36, 158, "hl2a_flashlight_far", {
		{ "#AMod_OptionsPanel_Flashlight_Strength_VeryLow", 450 },
		{ "#AMod_OptionsPanel_Flashlight_Strength_Low", 700 },
		{ "#AMod_OptionsPanel_Flashlight_Strength_Medium", 1250 },
		{ "#AMod_OptionsPanel_Flashlight_Strength_High", 1875 },
		{ "#AMod_OptionsPanel_Flashlight_Strength_VeryHigh", 2500 },
		{ "#AMod_OptionsPanel_Flashlight_Strength_ExtremelyHigh", 4000 },
	} },
	{ "label", 410, 30, 65, 30, "#AMod_OptionsPanel_Flashlight_StrengthText" },
	{ "combo", 245, 68, 158, "hl2a_flashlight_fov", {
		{ "#AMod_OptionsPanel_Flashlight_Fov_Low", 35 },
		{ "#AMod_OptionsPanel_Flashlight_Fov_Medium", 45 },
		{ "#AMod_OptionsPanel_Flashlight_Fov_High", 60 },
		{ "#AMod_OptionsPanel_Flashlight_Fov_VeryHigh", 75 },
		{ "#AMod_OptionsPanel_Flashlight_Fov_ExtremelyHigh", 100 },
		{ "#AMod_OptionsPanel_Flashlight_Fov_Full360", 170 },
	} },
	{ "label", 410, 62, 65, 30, "#AMod_OptionsPanel_Flashlight_FovText" },
	{ "check", 240, 98, 235, "amod_flashlightflicker", "#AMod_OptionsPanel_Flashlight_EnableFlicker" },
	{ "check", 240, 120, 235, "amod_flashlightlag", "#AMod_OptionsPanel_Flashlight_EnableLag", "#AMod_OptionsPanel_Flashlight_EnableLag_ToolTip" },
	{ "divider", 236, 148, 239, 2 },

	{ "label", 305, 151, 170, 20, "#Amod_OptionsPanel_OtherTitle" },
	{ "check", 240, 170, 235, "amod_enable_god", "#Amod_OptionsPanel_Other_EnableGod" },
	{ "check", 240, 189, 235, "amod_soundscapes_disable", "#Amod_OptionsPanel_Other_DisableSoundscapes", "#Amod_OptionsPanel_Other_DisableSoundscapes_Tooltip" },
	{ "check", 240, 208, 235, "amod_music_disable", "#Amod_OptionsPanel_Other_DisableMusic" },
	{ "check", 240, 227, 235, "amod_songs_transition_through_levels", "#Amod_OptionsPanel_Other_MusicTransitionThroughLevels" },
	{ "check", 240, 246, 235, "amod_do_citadel_timer", "#Amod_OptionsPanel_Other_CitadelTimer", "#Amod_OptionsPanel_Other_CitadelTimer_Tooltip" },
	{ "check", 240, 265, 235, "amod_do_core_timer", "#Amod_OptionsPanel_Other_CoreTimer", "#Amod_OptionsPanel_Other_CoreTimer_Tooltip" },
	{ "check", 240, 284, 235, "hl2a_achievement_notifications_disable", "#Amod_OptionsPanel_Other_DisableAchievementNotifications", "#Amod_OptionsPanel_Other_DisableAchievementNotifications_Tooltip" },
	{ "divider", 236, 324, 239, 2 },
	{ "reset", 247, 336, 219, 24, "Reset everything" },
	{ "apply", 247, 370, 219, 26, "#Amod_OptionsPanel_ApplySettings" },
}

local W, H = 475, 405
local panel

local function buildPanel()
	local s = math.Clamp( math.floor( ScrH() / 540 * 4 ) / 4, 1, 2 ) -- scale the original 475x405 layout
	local pending = {}

	local function S( v ) return math.floor( v * s ) end

	surface.CreateFont( "HL2A.Options", { font = "Tahoma", size = S( 13 ), weight = 500 } )
	surface.CreateFont( "HL2A.OptionsTitle", { font = "Tahoma", size = S( 13 ), weight = 800 } )

	local frame = vgui.Create( "DFrame" )
	frame:SetTitle( phrase( "#AMod_OptionsPanel_Title" ) )
	frame:SetSize( S( W ), S( H ) + 24 )
	frame:Center()
	frame:SetDeleteOnClose( true )
	HL2A.OptionsPending = pending
	frame.OnRemove = function() if HL2A.OptionsPending == pending then HL2A.OptionsPending = nil end end

	local body = frame:Add( "DPanel" )
	body:SetPos( 0, 24 )
	body:SetSize( S( W ), S( H ) )
	body:SetPaintBackground( false )

	local function value( name ) return pending[ name ] or GetConVar( name ):GetString() end

	for _, c in ipairs( LAYOUT ) do
		local kind = c[ 1 ]

		if kind == "label" then
			local l = body:Add( "DLabel" )
			l:SetPos( S( c[ 2 ] ), S( c[ 3 ] ) )
			l:SetSize( S( c[ 4 ] ), S( c[ 5 ] ) )
			l:SetFont( "HL2A.OptionsTitle" )
			l:SetWrap( true )
			l:SetText( ( phrase( c[ 6 ] ):gsub( "\\n", "\n" ) ) )

		elseif kind == "check" then
			local name = c[ 5 ]
			local cb = body:Add( "DCheckBoxLabel" )
			cb:SetPos( S( c[ 2 ] ), S( c[ 3 ] ) )
			cb:SetWide( S( c[ 4 ] ) )
			cb:SetFont( "HL2A.Options" )
			cb:SetText( phrase( c[ 6 ] ) )
			cb:SetValue( tobool( value( name ) ) )
			if c[ 7 ] then cb:SetTooltip( ( phrase( c[ 7 ] ):gsub( "\\n", "\n" ) ) ) end
			cb.OnChange = function( _, on ) pending[ name ] = on and "1" or "0" end

		elseif kind == "slider" then
			local name = c[ 5 ]
			local sl = body:Add( "DNumSlider" )
			sl:SetPos( S( c[ 2 ] ), S( c[ 3 ] ) )
			sl:SetSize( S( c[ 4 ] ), S( 22 ) )
			sl:SetMinMax( c[ 6 ], c[ 7 ] )
			sl:SetDecimals( 0 )
			sl:SetValue( tonumber( value( name ) ) or 0 )
			-- No built-in label: the original put its text in a separate label
			sl.Label:SetVisible( false )
			sl.PerformLayout = function( self ) self.Label:SetWide( 0 ) end
			if c[ 8 ] then sl:SetTooltip( ( phrase( c[ 8 ] ):gsub( "\\n", "\n" ) ) ) end
			sl.OnValueChanged = function( _, v ) pending[ name ] = tostring( math.Round( v ) ) end

		elseif kind == "combo" then
			local name, presets = c[ 5 ], c[ 6 ]
			local cur = tonumber( value( name ) )
			local box = body:Add( "DComboBox" )
			box:SetPos( S( c[ 2 ] ), S( c[ 3 ] ) )
			box:SetSize( S( c[ 4 ] ), S( 22 ) )
			box:SetSortItems( false )
			local matched = false
			for _, p in ipairs( presets ) do
				local sel = cur == p[ 2 ]
				matched = matched or sel
				box:AddChoice( phrase( p[ 1 ] ), p[ 2 ], sel )
			end
			if not matched then box:AddChoice( "Custom (" .. tostring( cur ) .. ")", cur, true ) end
			box.OnSelect = function( _, _, _, v ) pending[ name ] = tostring( v ) end

		elseif kind == "divider" then
			local d = body:Add( "DPanel" )
			d:SetPos( S( c[ 2 ] ), S( c[ 3 ] ) )
			d:SetSize( math.max( 1, S( c[ 4 ] ) ), math.max( 1, S( c[ 5 ] ) ) )
			d.Paint = function( _, w, h ) surface.SetDrawColor( 90, 90, 90 ) surface.DrawRect( 0, 0, w, h ) end

		elseif kind == "reset" then
			local b = body:Add( "DButton" )
			b:SetPos( S( c[ 2 ] ), S( c[ 3 ] ) )
			b:SetSize( S( c[ 4 ] ), S( c[ 5 ] ) )
			b:SetText( c[ 6 ] )
			b.DoClick = function()
				Derma_Query( "Put every option on this panel back to the mod's defaults?", c[ 6 ], "Reset", function()
					local names = {}
					for _, e in ipairs( LAYOUT ) do
						if ( e[ 1 ] == "check" or e[ 1 ] == "slider" or e[ 1 ] == "combo" ) and isstring( e[ 5 ] ) then names[ #names + 1 ] = e[ 5 ] end
					end
					HL2A.ResetConVars( names )
					frame:Close()
					timer.Simple( 0.3, HL2A.ToggleOptionsPanel )
				end, "Cancel" )
			end

		elseif kind == "button" then
			local b = body:Add( "DButton" )
			b:SetPos( S( c[ 2 ] ), S( c[ 3 ] ) )
			b:SetSize( S( c[ 4 ] ), S( c[ 5 ] ) )
			b:SetText( phrase( c[ 6 ] ) )
			b.DoClick = c[ 7 ]

		elseif kind == "apply" then
			local b = body:Add( "DButton" )
			b:SetPos( S( c[ 2 ] ), S( c[ 3 ] ) )
			b:SetSize( S( c[ 4 ] ), S( c[ 5 ] ) )
			b:SetText( phrase( c[ 6 ] ) )
			b.DoClick = function()
				-- Client settings apply here; server settings go to the server
				local list = {}
				for name, v in pairs( pending ) do list[ #list + 1 ] = { name, v } end
				HL2A.SetConVars( list )
				frame:Close()
			end
		end
	end

	return frame
end

function HL2A.ToggleOptionsPanel()
	if IsValid( panel ) then panel:Close() return end
	panel = buildPanel()
	panel:MakePopup()
end

concommand.Add( "ToggleOptionsPanel", HL2A.ToggleOptionsPanel, nil, "Toggles The Alone Mod Options Panel" )

-- Mirrored view -----------------------------------------------------------------------
-- The whole 3D view (world, viewmodel, screen effects) is rendered into a
-- render target and drawn flipped in one step. Flipping the finished frame
-- in RenderScreenspaceEffects instead left the viewmodel drawn un-mirrored
-- on top after a map load. The HUD isn't part of the scene, so it stays
-- readable. Mouse and strafe input are flipped too so controls match.

local mirrorMat = CreateMaterial( "hl2a_mirror", "UnlitGeneric", { [ "$basetexture" ] = "_rt_FullFrameFB" } )
local mirrorRT, mirrorW, mirrorH
local inMirror = false

hook.Add( "RenderScene", "hl2a.mirror", function( origin, angles, fov )
	if inMirror then return end
	local mirrored = CV.amod_mirrored:GetBool()
	-- Claustrophobia (cl_effects.lua) renders with its own aspect ratio
	local aspect = HL2A.Effects and HL2A.Effects.Aspect and HL2A.Effects.Aspect()
	if not mirrored and not aspect then return end

	local w, h = ScrW(), ScrH()
	if not mirrored then
		inMirror = true
		render.RenderView( { origin = origin, angles = angles, fov = fov, aspect = aspect, x = 0, y = 0, w = w, h = h,
			drawhud = false, drawviewmodel = true, dopostprocess = true } )
		inMirror = false
		return true
	end

	if not mirrorRT or mirrorW ~= w or mirrorH ~= h then
		mirrorRT = GetRenderTarget( "hl2a_mirror_" .. w .. "x" .. h, w, h )
		mirrorW, mirrorH = w, h
	end

	inMirror = true
	render.PushRenderTarget( mirrorRT )
		render.Clear( 0, 0, 0, 255, true, true )
		render.RenderView( { origin = origin, angles = angles, fov = fov, aspect = aspect, x = 0, y = 0, w = w, h = h,
			drawhud = false, drawviewmodel = true, dopostprocess = true } )
	render.PopRenderTarget()
	inMirror = false

	mirrorMat:SetTexture( "$basetexture", mirrorRT )
	cam.Start2D()
		surface.SetDrawColor( 255, 255, 255 )
		surface.SetMaterial( mirrorMat )
		surface.DrawTexturedRectUV( 0, 0, w, h, 1, 0, 0, 1 )
	cam.End2D()

	return true
end )

hook.Add( "InputMouseApply", "hl2a.mirror", function( cmd, x, y, ang )
	if not CV.amod_mirrored:GetBool() then return end
	-- x and y already include sensitivity (and zoom scaling); the engine would do ang.y - x * m_yaw
	ang.y = ang.y + x * GetConVar( "m_yaw" ):GetFloat()
	ang.p = math.Clamp( ang.p + y * GetConVar( "m_pitch" ):GetFloat(), -89, 89 )
	cmd:SetViewAngles( ang )
	return true
end )

hook.Add( "CreateMove", "hl2a.mirror", function( cmd )
	if CV.amod_mirrored:GetBool() then cmd:SetSideMove( -cmd:GetSideMove() ) end
end )
