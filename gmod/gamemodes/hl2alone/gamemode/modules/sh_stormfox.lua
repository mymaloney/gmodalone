--[[
	StormFox 2 compatibility (https://github.com/Nak2/StormFox2).

	hl2a_stormfox 1 (default): when StormFox 2 is installed it takes over the
	weather and time (and the sky with hl2a_stormfox_sky 1; by default the
	maps keep their own night sky, clouds and stars). Each map's own settings (time_info / the Weather
	panel: rain or snow, intensity, intervals, thunder) are fed to it, at
	night, with time stopped. The port's own rain/snow particles and
	ambience, thunder, clouds, stars, horizon fog, skybox and sun step aside;
	its per-map fog and colour grade stay (hl2a_stormfox_fog 1 hands the fog
	to StormFox too). The maps' baked night lighting is left alone.

	hl2a_stormfox 0: the port keeps its own weather and sky, and StormFox is
	switched off while playing.

	StormFox settings changed here are only for the session (not saved), and
	the previous values are put back when the game shuts down.
]]

local CV = HL2A.ConVars

--- StormFox is installed (and running)
function HL2A.StormFoxInstalled()
	return istable( StormFox2 ) and istable( StormFox2.Setting ) and isfunction( StormFox2.Setting.Set )
end

--- StormFox is handling the weather (clients: as published by the server)
function HL2A.StormFoxActive()
	if CLIENT then return GetGlobal2Bool( "hl2a.stormfox", false ) end
	return HL2A.StormFoxInstalled() and CV.hl2a_stormfox:GetBool()
end

--- StormFox is drawing the sky too (hl2a_stormfox_sky)
function HL2A.StormFoxSky()
	if not HL2A.StormFoxActive() then return false end
	if CLIENT then return GetGlobal2Bool( "hl2a.stormfox.sky", false ) end
	return CV.hl2a_stormfox_sky:GetBool()
end

-- Session-only StormFox settings ------------------------------------------------------------

local originals = {} -- setting -> value before we changed it

local function setSF( name, value )
	local S = StormFox2.Setting
	if not S.GetObject or not S.GetObject( name ) then return end
	if originals[ name ] == nil then originals[ name ] = S.Get( name ) end
	S.Set( name, value, true ) -- true: don't write StormFox's settings file
end

local function restoreSF()
	if not HL2A.StormFoxInstalled() then return end
	for name, value in pairs( originals ) do StormFox2.Setting.Set( name, value ) end
	originals = {}
end
hook.Add( "ShutDown", "hl2a.stormfox", function() restoreSF() end )

if CLIENT then
	-- The port's fog unless hl2a_stormfox_fog: turn StormFox's (client setting) off
	local function applyClient()
		if not HL2A.StormFoxInstalled() then return end
		local keepOurFog = HL2A.StormFoxActive() and not GetGlobal2Bool( "hl2a.stormfox.fog", false )
		local own = originals.enable_fog
		if own == nil then own = StormFox2.Setting.Get( "enable_fog" ) end
		setSF( "enable_fog", ( not keepOurFog ) and own or false ) -- the player's own choice otherwise
	end
	timer.Create( "hl2a.stormfox.client", 2, 0, applyClient )
	return
end

-- Server: hand the map's weather to StormFox ------------------------------------------------

local NIGHT_DEFAULT = 23 * 60 + 30 -- 23:30, in StormFox minutes

local function nightTime()
	local t = CV.hl2a_stormfox_time:GetString()
	local h, m = t:match( "^(%d+):(%d+)$" )
	if h then return ( tonumber( h ) % 24 ) * 60 + tonumber( m ) % 60 end
	return NIGHT_DEFAULT
end

-- RainIntensity / amod_weather_rain_density (0.0002..0.006) -> StormFox amount (0.3..1)
local function amount( density )
	local d = math.Clamp( tonumber( density ) or 0.001, 0.0002, 0.006 )
	return 0.3 + ( d - 0.0002 ) / 0.0058 * 0.7
end

local last = {}

local function desired()
	-- What sv_weather.lua worked out: the port's weather, else the map's own rain/snow
	local kind = GetGlobal2Int( "hl2a.weather.type", 0 )
	local falling = GetGlobal2Bool( "hl2a.weather.active", false )
	if kind == 0 then kind = GetGlobal2Int( "hl2a.weather.maptype", 0 ) falling = kind ~= 0 end
	local d = GetGlobal2Float( "hl2a.weather.density", 0.001 )
	if not falling or kind == 0 then return "Clear", 1, nil end
	if kind == 1 then return "Rain", amount( d ), 12 end
	if kind == 2 then return "Rain", amount( d ), -6 end -- StormFox snows below freezing
	return "Cloud", 0.8, nil -- ash: overcast
end

local function sync( force )
	if not HL2A.StormFoxActive() then return end
	local name, pct, temp = desired()
	local thunder = CV.amod_weather_thunder:GetBool() and name == "Rain" and temp ~= nil and temp > 0
	local key = string.format( "%s|%.2f|%s|%s", name, pct, tostring( temp ), tostring( thunder ) )
	if not force and key == last.weather then return end
	last.weather = key

	if temp and StormFox2.Temperature and StormFox2.Temperature.Set then StormFox2.Temperature.Set( temp, 2 ) end
	if StormFox2.Weather and StormFox2.Weather.Set then StormFox2.Weather.Set( name, pct, force and 0 or 8 ) end
	if StormFox2.Thunder and StormFox2.Thunder.SetEnabled then
		if thunder then StormFox2.Thunder.SetEnabled( true, 3, 60 * 60 ) else StormFox2.Thunder.SetEnabled( false ) end
	end
	MsgN( "[HL2A] StormFox: " .. key )
end

local function takeOver()
	if not HL2A.StormFoxInstalled() then return end
	SetGlobal2Bool( "hl2a.stormfox", HL2A.StormFoxActive() )
	SetGlobal2Bool( "hl2a.stormfox.fog", CV.hl2a_stormfox_fog:GetBool() )
	SetGlobal2Bool( "hl2a.stormfox.sky", CV.hl2a_stormfox_sky:GetBool() )

	if not HL2A.StormFoxActive() then
		setSF( "enable", false ) -- the port keeps its own weather: StormFox stays out
		return
	end
	setSF( "enable", true )
	-- The campaign's weather and night, not StormFox's own forecast/clock
	setSF( "auto_weather", false )
	setSF( "openweathermap_enabled", false )
	setSF( "real_time", false )
	setSF( "random_time", false )
	if not CV.hl2a_stormfox_time_flow:GetBool() then
		setSF( "day_length", 0 )
		setSF( "night_length", 0 )
	end
	-- The maps carry baked night lighting; don't relight them
	if not CV.hl2a_stormfox_maplight:GetBool() then
		for _, name in ipairs( { "maplight_auto", "maplight_lightenv", "maplight_colormod", "maplight_dynamic",
			"maplight_lightstyle", "allow_weather_lightchange" } ) do setSF( name, false ) end
	end
	setSF( "enable_svfog", CV.hl2a_stormfox_fog:GetBool() )
	-- Its sky, sun and moon, or the maps' own night sky (the default)
	setSF( "enable_skybox", CV.hl2a_stormfox_sky:GetBool() )

	if StormFox2.Time and StormFox2.Time.Set then StormFox2.Time.Set( nightTime() ) end
	sync( true )
end

hook.Add( "InitPostEntity", "hl2a.stormfox", function() timer.Simple( 1, takeOver ) end )
hook.Add( "HL2A_PublishSettings", "hl2a.stormfox", function() takeOver() end )
timer.Create( "hl2a.stormfox.sync", 2, 0, function() sync( false ) end )

for _, name in ipairs( { "hl2a_stormfox", "hl2a_stormfox_fog", "hl2a_stormfox_sky", "hl2a_stormfox_time", "hl2a_stormfox_time_flow",
	"hl2a_stormfox_maplight", "amod_weather_thunder" } ) do
	cvars.AddChangeCallback( name, function() timer.Simple( 0, takeOver ) end, "hl2a.stormfox" )
end

concommand.Add( "hl2a_stormfox_status", function( ply )
	if IsValid( ply ) and not ply:IsListenServerHost() then return end
	if not HL2A.StormFoxInstalled() then MsgN( "[HL2A] StormFox 2 isn't installed" ) return end
	MsgN( "[HL2A] StormFox 2 installed; " .. ( HL2A.StormFoxActive() and "handling weather and sky" or "switched off (hl2a_stormfox 0)" ) )
	local name, pct, temp = desired()
	MsgN( string.format( "  map wants: %s %.2f%s", name, pct, temp and ( " at " .. temp .. " C" ) or "" ) )
	if StormFox2.Weather and StormFox2.Weather.GetCurrent then
		local w = StormFox2.Weather.GetCurrent()
		MsgN( "  StormFox has: " .. tostring( w and w.Name ) .. " " .. tostring( StormFox2.Weather.GetPercent and StormFox2.Weather.GetPercent() ) )
	end
	for k, v in pairs( originals ) do MsgN( string.format( "  session override: %s (was %s)", k, tostring( v ) ) ) end
end, nil, "StormFox 2 integration state" )
