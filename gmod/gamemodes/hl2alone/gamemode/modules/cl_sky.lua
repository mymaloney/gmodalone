--[[
	Clouds, stars and horizon fog. The original drew these with engine
	changes (client.dll view render); here they're Lua meshes drawn right
	after the 2D skybox, so the world and the 3D skybox cover them as before.

	Per-map settings are the time_info "clouds" / "stars" / "horizon" blocks
	(r_clouds*, r_stars*, r_horizonfog* keys, defaults from client.dll).
	What the original did, recovered from the DLL:
	  clouds   a 32x16 sphere of radius r_clouds_scale_multiplyer (900),
	           scaled by r_clouds_scale_x/y/z, rotated by r_clouds_angle_*,
	           centred on the view + r_clouds_offset_*; texture
	           r_clouds_material, scrolling at r_clouds_scrollrate_*, tiled
	           every r_clouds_material_scale_* units; colour
	           rgb / 255 * alpha / 255 (alpha may exceed 255)
	  stars    nature/stars01 on a sphere of radius r_stars_raduis
	  horizon  nature/horizon_fog band with top/mid/bottom colours
	Shown when the map turns them on and the player allows it
	(r_clouds_enable, r_stars_enable, r_horizonfog_enable), or when the map
	or player forces them (r_clouds_force, r_stars_force, r_horizonfog_force).
]]

local CV = HL2A.ConVars
local TI = HL2A.TimeInfo

local DEFAULTS = {
	clouds = {
		r_clouds = 0, r_clouds_force = 0, r_clouds_material = "nature/clouds/cloud001",
		r_clouds_red = 104, r_clouds_green = 211, r_clouds_blue = 255, r_clouds_alpha = 100,
		r_clouds_scrollrate_x = 0.01, r_clouds_scrollrate_y = 0.01,
		r_clouds_offset_x = 0, r_clouds_offset_y = 0, r_clouds_offset_z = -30,
		r_clouds_scale_x = 0.5, r_clouds_scale_y = 1.1, r_clouds_scale_z = 2.0,
		r_clouds_angle_x = 50, r_clouds_angle_y = 90, r_clouds_angle_z = 0,
		r_clouds_material_scale_x = 600, r_clouds_material_scale_y = 600, r_clouds_scale_multiplyer = 900,
	},
	stars = {
		r_stars = 0, r_stars_size = 32, r_stars_raduis = 256,
		r_stars_offset_x = 0, r_stars_offset_y = 0, r_stars_offset_z = 0,
		r_stars_red = 255, r_stars_green = 255, r_stars_blue = 255, r_stars_alpha = 255,
	},
	horizon = {
		r_horizonfog = 0, r_horizonfog_force = 0, r_horizonfog_pitch = 0, r_horizonfog_yaw = 0,
		r_horizonfog_width = 360, r_horizonfog_height = 1.0, r_horizonfog_scale = 0.5,
		r_horizonfog_offset_x = 0, r_horizonfog_offset_y = 0, r_horizonfog_offset_z = 0,
		r_horizonfog_top_r = 0.5, r_horizonfog_top_g = 0.7, r_horizonfog_top_b = 1.0,
		r_horizonfog_mid_r = 1.0, r_horizonfog_mid_g = 0.5, r_horizonfog_mid_b = 0.2,
		r_horizonfog_bot_r = 0.1, r_horizonfog_bot_g = 0.1, r_horizonfog_bot_b = 0.05,
		r_horizonfog_alpha = 1,
	},
}

HL2A.Sky = HL2A.Sky or {}
local S = HL2A.Sky

--- The current map's settings for "clouds" / "stars" / "horizon"
function S.Settings( block )
	local out = table.Copy( DEFAULTS[ block ] )
	for k, v in pairs( TI.GetSubTable( block ) ) do
		if out[ k ] ~= nil then out[ k ] = isnumber( out[ k ] ) and ( tonumber( v ) or out[ k ] ) or v end
	end
	return out
end

local clouds, stars, horizon -- settings, rebuilt on map load / theme change
local cloudMesh, starMesh, horizonMesh
local cloudMat, starMat, horizonMat

-- Materials ----------------------------------------------------------------------------

--- Texture name for a material or texture path, or nil if neither exists.
-- (A missing texture used to leave the layer as a solid tinted dome.)
local function textureOf( path )
	path = path:gsub( "\\", "/" ):gsub( "%.vtf$", "" ):gsub( "%.vmt$", "" ):lower()
	if file.Exists( "materials/" .. path .. ".vmt", "GAME" ) then
		local tex = Material( path ):GetTexture( "$basetexture" )
		if tex and not tex:IsError() then return tex:GetName() end
	end
	-- r_clouds_material can also name a texture directly
	if file.Exists( "materials/" .. path .. ".vtf", "GAME" ) then return path end
	return nil
end

-- Blend mode of one of the mod's sky materials (nature/clouds_sphere,
-- nature/stars01): additive only if its .vmt says so, else translucent.
-- Cloud textures are typically white with the clouds in the alpha channel,
-- so drawing them additively just tints the whole sky.
local function vmtFlags( path )
	local text = file.Read( "materials/" .. path .. ".vmt", "GAME" )
	local root = text and HL2A.KV.Parse( text )
	local body = root and root[ 1 ] and istable( root[ 1 ].value ) and HL2A.KV.ToTable( root[ 1 ].value ) or {}
	return {
		shader = root and root[ 1 ] and root[ 1 ].key or "?",
		additive = tobool( body[ "$additive" ] ),
	}
end

local function skyMaterial( name, tex, additive )
	if not tex then return nil end
	-- The texture and blend flags only take effect when a material is created,
	-- so each combination gets its own material
	local id = "hl2a_sky_" .. name .. "_" .. tex:gsub( "[^%w]", "_" ) .. ( additive and "_add" or "_blend" )
	return CreateMaterial( id, "UnlitGeneric", {
		[ "$basetexture" ] = tex, [ "$nocull" ] = 1, [ "$vertexcolor" ] = 1, [ "$vertexalpha" ] = 1,
		[ "$additive" ] = additive and 1 or 0, [ "$translucent" ] = additive and 0 or 1, [ "$nofog" ] = 1,
	} )
end

-- Meshes -----------------------------------------------------------------------------------

local LON, LAT = 32, 16

local function spherePoint( i, j )
	local lon, lat = i / LON * math.pi * 2, j / LAT * math.pi
	return Vector( math.sin( lat ) * math.cos( lon ), math.sin( lat ) * math.sin( lon ), math.cos( lat ) )
end

--- Unit sphere; uv( p ) gives texture coordinates for a unit-sphere point
local function buildSphere( uv )
	local m = Mesh()
	mesh.Begin( m, MATERIAL_TRIANGLES, LON * LAT * 2 )
	local function vert( p )
		local u, v = uv( p )
		mesh.Position( p )
		mesh.TexCoord( 0, u, v )
		mesh.Color( 255, 255, 255, 255 )
		mesh.AdvanceVertex()
	end
	for i = 0, LON - 1 do
		for j = 0, LAT - 1 do
			local a, b, c, d = spherePoint( i, j ), spherePoint( i + 1, j ), spherePoint( i + 1, j + 1 ), spherePoint( i, j + 1 )
			vert( a ) vert( b ) vert( c )
			vert( a ) vert( c ) vert( d )
		end
	end
	mesh.End()
	return m
end

--- Horizon band: bottom, middle and top rows coloured from the settings,
-- fading out at the top and bottom edges
local function buildHorizon( h )
	local segs = 32
	local width = math.rad( math.Clamp( h.r_horizonfog_width, 1, 360 ) )
	local half = math.Clamp( h.r_horizonfog_height, 0.01, 4 )
	local a = math.Clamp( h.r_horizonfog_alpha, 0, 1 ) * 255
	local rows = {
		{ z = -half, c = { h.r_horizonfog_bot_r, h.r_horizonfog_bot_g, h.r_horizonfog_bot_b }, a = 0 },
		{ z = -half * 0.35, c = { h.r_horizonfog_bot_r, h.r_horizonfog_bot_g, h.r_horizonfog_bot_b }, a = a },
		{ z = 0, c = { h.r_horizonfog_mid_r, h.r_horizonfog_mid_g, h.r_horizonfog_mid_b }, a = a },
		{ z = half, c = { h.r_horizonfog_top_r, h.r_horizonfog_top_g, h.r_horizonfog_top_b }, a = 0 },
	}
	local m = Mesh()
	mesh.Begin( m, MATERIAL_TRIANGLES, segs * ( #rows - 1 ) * 2 )
	local function vert( s, r )
		local ang = -width / 2 + width * s / segs
		local row = rows[ r ]
		mesh.Position( Vector( math.cos( ang ), math.sin( ang ), row.z ) )
		mesh.TexCoord( 0, s / segs, ( r - 1 ) / ( #rows - 1 ) )
		mesh.Color( math.Clamp( row.c[ 1 ], 0, 1 ) * 255, math.Clamp( row.c[ 2 ], 0, 1 ) * 255, math.Clamp( row.c[ 3 ], 0, 1 ) * 255, row.a )
		mesh.AdvanceVertex()
	end
	for s = 0, segs - 1 do
		for r = 1, #rows - 1 do
			vert( s, r ) vert( s + 1, r ) vert( s + 1, r + 1 )
			vert( s, r ) vert( s + 1, r + 1 ) vert( s, r + 1 )
		end
	end
	mesh.End()
	return m
end

local function free( m ) if m then m:Destroy() end end

function S.Rebuild()
	free( cloudMesh ) free( starMesh ) free( horizonMesh )
	cloudMesh, starMesh, horizonMesh = nil, nil, nil

	clouds, stars, horizon = S.Settings( "clouds" ), S.Settings( "stars" ), S.Settings( "horizon" )

	-- Clouds: texture tiled every material_scale units of the (unscaled) sphere
	local R = clouds.r_clouds_scale_multiplyer
	local msx, msy = math.max( clouds.r_clouds_material_scale_x, 1 ), math.max( clouds.r_clouds_material_scale_y, 1 )
	cloudMesh = buildSphere( function( p ) return p.x * R / msx, p.y * R / msy end )
	S.CloudFlags = vmtFlags( "nature/clouds_sphere" )
	cloudMat = skyMaterial( "clouds", textureOf( clouds.r_clouds_material ), S.CloudFlags.additive )

	-- Stars: r_stars_size repeats around the sphere
	local n = math.max( stars.r_stars_size, 1 )
	starMesh = buildSphere( function( p )
		return ( math.atan2( p.y, p.x ) / ( math.pi * 2 ) + 0.5 ) * n, math.acos( math.Clamp( p.z, -1, 1 ) ) / math.pi * n / 2
	end )
	S.StarFlags = vmtFlags( "nature/stars01" )
	starMat = skyMaterial( "stars", textureOf( "nature/stars01" ), S.StarFlags.additive )

	horizonMesh = buildHorizon( horizon )
	horizonMat = skyMaterial( "horizon", "vgui/white", false )
end

-- Drawing ----------------------------------------------------------------------------------

local function shown( mapOn, enable, mapForce, force )
	return ( tobool( mapOn ) and enable ) or tobool( mapForce ) or force
end

local function drawMesh( m, mat, pos, ang, scale, color )
	local mtx = Matrix()
	mtx:Translate( pos )
	mtx:Rotate( ang )
	mtx:Scale( scale )
	if color then mat:SetVector( "$color", color ) end
	render.SetMaterial( mat )
	cam.PushModelMatrix( mtx )
		m:Draw()
	cam.PopModelMatrix()
end

hook.Add( "PostDraw2DSkyBox", "hl2a.sky", function()
	if not clouds then return end
	local showStars = starMat and shown( stars.r_stars, CV.r_stars_enable:GetBool(), 0, CV.r_stars_force:GetBool() )
	local showHorizon = shown( horizon.r_horizonfog, CV.r_horizonfog_enable:GetBool(), horizon.r_horizonfog_force, false )
	local showClouds = cloudMat and shown( clouds.r_clouds, CV.r_clouds_enable:GetBool(), clouds.r_clouds_force, false )
	if not ( showStars or showHorizon or showClouds ) then return end

	local vs = render.GetViewSetup and render.GetViewSetup()
	cam.Start3D( vector_origin, EyeAngles(), vs and vs.fov or nil, nil, nil, nil, nil, 1, 200000 )
	render.OverrideDepthEnable( true, false )
	render.FogMode( MATERIAL_FOG_NONE )

	-- Same order as the original: stars, horizon, clouds
	if showStars then
		local s = stars
		local a = s.r_stars_alpha / 255
		drawMesh( starMesh, starMat, Vector( s.r_stars_offset_x, s.r_stars_offset_y, s.r_stars_offset_z ), angle_zero,
			Vector( 1, 1, 1 ) * s.r_stars_raduis, Vector( s.r_stars_red, s.r_stars_green, s.r_stars_blue ) / 255 * a )
	end

	if showHorizon then
		local h = horizon
		local R = 2000 * h.r_horizonfog_scale
		drawMesh( horizonMesh, horizonMat, Vector( h.r_horizonfog_offset_x, h.r_horizonfog_offset_y, h.r_horizonfog_offset_z ),
			Angle( h.r_horizonfog_pitch, h.r_horizonfog_yaw, 0 ), Vector( R, R, R ) )
	end

	if showClouds then
		local c = clouds
		local r, g, b = c.r_clouds_red, c.r_clouds_green, c.r_clouds_blue
		if CV.r_clouds_color_override:GetBool() then
			r, g, b = CV.r_clouds_red_override:GetInt(), CV.r_clouds_green_override:GetInt(), CV.r_clouds_blue_override:GetInt()
		end
		local a = c.r_clouds_alpha / 255
		-- Texture scroll, as the material's $scrollrate proxy did
		local t = CurTime()
		local scroll = Matrix()
		scroll:Translate( Vector( ( t * c.r_clouds_scrollrate_x ) % 1, ( t * c.r_clouds_scrollrate_y ) % 1, 0 ) )
		cloudMat:SetMatrix( "$basetexturetransform", scroll )

		local R = c.r_clouds_scale_multiplyer
		drawMesh( cloudMesh, cloudMat, Vector( c.r_clouds_offset_x, c.r_clouds_offset_y, c.r_clouds_offset_z ),
			Angle( c.r_clouds_angle_x, c.r_clouds_angle_y, c.r_clouds_angle_z ),
			Vector( c.r_clouds_scale_x, c.r_clouds_scale_y, c.r_clouds_scale_z ) * R,
			Vector( r, g, b ) / 255 * a )
	end

	render.OverrideDepthEnable( false )
	cam.End3D()
end )

hook.Add( "InitPostEntity", "hl2a.sky", function() S.Rebuild() end )
hook.Add( "HL2A_TimeInfoChanged", "hl2a.sky", S.Rebuild )
cvars.AddChangeCallback( "hl2a_timeinfo_theme", function() timer.Simple( 0.1, S.Rebuild ) end, "hl2a.sky" )

concommand.Add( "hl2a_sky_reload", S.Rebuild, nil, "Rebuild the clouds, stars and horizon fog from time_info" )
concommand.Add( "hl2a_sky_dump", function()
	local tex = cloudMat and cloudMat:GetTexture( "$basetexture" )
	MsgN( "cloud texture: " .. ( tex and tex:GetName() or "MISSING - clouds not drawn" ) )
	for name, f in pairs( { clouds_sphere = S.CloudFlags, stars01 = S.StarFlags } ) do
		MsgN( string.format( "nature/%s: shader %s, %s", name, f.shader, f.additive and "additive" or "translucent" ) )
	end
	for _, block in ipairs( { "clouds", "stars", "horizon" } ) do
		MsgN( block .. ":" )
		local set = S.Settings( block )
		local keys = table.GetKeys( set )
		table.sort( keys )
		for _, k in ipairs( keys ) do MsgN( "  " .. k .. " = " .. tostring( set[ k ] ) ) end
	end
end, nil, "Show the current map's cloud / star / horizon settings" )
