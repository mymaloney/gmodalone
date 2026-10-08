--[[
	World/skybox fog from time_info "fog" blocks, daytime city fogs
	(amod_city_fogs.txt) and FogCubeTrigger fog_* overrides, with smooth
	blending (fog_lerp_system_lerp_time).

	When a map has no override we return nothing and the map's own
	env_fog_controller is used.
]]

local CV = HL2A.ConVars
local TI = HL2A.TimeInfo

local FIELDS = {
	start = "fog_start", finish = "fog_end", density = "fog_maxdensity",
	skyStart = "fog_startskybox", skyFinish = "fog_endskybox", skyDensity = "fog_maxdensityskybox",
}

local current -- numeric state being blended toward the target

local function buildTarget()
	if CV.amod_fog_disabled:GetBool() then return { none = true } end

	local fog = table.Copy( TI.GetSubTable( "fog" ) )
	local overridden = tobool( fog.fog_override )

	if HL2A.IsDay() and TI.CityFogs and TI.CityFogs[ HL2A.Map() ] then
		table.Merge( fog, TI.CityFogs[ HL2A.Map() ] )
		overridden = true
	end

	local ply = LocalPlayer()
	local vars = IsValid( ply ) and TI.GetTriggerVars( ply:EyePos() )
	if vars then
		for k, v in pairs( vars ) do
			if k:StartWith( "fog_" ) then fog[ k ] = v; overridden = true end
		end
	end

	if not overridden then return nil end
	if fog.fog_enable == "0" then return { none = true } end
	-- "fog_override 1" with no distances = keep the map's fog values
	if not fog.fog_start and not fog.fog_end then return nil end

	local t = { lerp = tonumber( fog.fog_lerp_system_lerp_time ) or 1 }
	for field, key in pairs( FIELDS ) do t[ field ] = tonumber( fog[ key ] ) end
	t.start = t.start or 0
	t.finish = t.finish or 10000
	t.density = t.density or 1
	t.color = HL2A.ParseColor( fog.fog_color ) or Color( 128, 128, 128 )
	t.skyEnabled = fog.fog_enableskybox ~= "0"
	t.skyStart = t.skyStart or t.start
	t.skyFinish = t.skyFinish or t.finish
	t.skyDensity = t.skyDensity or t.density
	t.skyColor = HL2A.ParseColor( fog.fog_colorskybox ) or t.color
	return t
end

local function approach( cur, target, frac )
	for field in pairs( FIELDS ) do cur[ field ] = Lerp( frac, cur[ field ], target[ field ] ) end
	for _, c in ipairs( { "color", "skyColor" } ) do
		cur[ c ] = Color(
			Lerp( frac, cur[ c ].r, target[ c ].r ),
			Lerp( frac, cur[ c ].g, target[ c ].g ),
			Lerp( frac, cur[ c ].b, target[ c ].b ) )
	end
	cur.skyEnabled = target.skyEnabled
end

hook.Add( "Think", "hl2a.fog", function()
	local target = buildTarget()

	if not target or target.none then
		current = target
		return
	end

	if not current or current.none then
		current = table.Copy( target )
		return
	end

	approach( current, target, math.min( 1, FrameTime() * 3 / math.max( target.lerp, 0.01 ) ) )
end )

local function setup( start, finish, density, color )
	render.FogMode( MATERIAL_FOG_LINEAR )
	render.FogStart( start )
	render.FogEnd( finish )
	render.FogMaxDensity( density )
	render.FogColor( color.r, color.g, color.b )
end

hook.Add( "SetupWorldFog", "hl2a.fog", function()
	if not current then return end
	if current.none then render.FogMode( MATERIAL_FOG_NONE ) return true end
	setup( current.start, current.finish, current.density, current.color )
	return true
end )

hook.Add( "SetupSkyboxFog", "hl2a.fog", function( scale )
	if not current then return end
	if current.none or not current.skyEnabled then render.FogMode( MATERIAL_FOG_NONE ) return true end
	setup( current.skyStart * scale, current.skyFinish * scale, current.skyDensity, current.skyColor )
	return true
end )
