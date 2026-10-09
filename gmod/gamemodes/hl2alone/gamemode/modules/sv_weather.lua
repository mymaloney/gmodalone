--[[
	Weather state (server-authoritative, rendered in cl_weather.lua).

	Settings come from the map's time_info "weather" block, or from the
	amod_weather_* convars when amod_weather_override is 1. Supports running
	in intervals (on for a random wait, off for a random wait). Rain, snow and
	thunder sounds are played client-side (cl_weathersound.lua).

	Networked via GlobalVar2:
		hl2a.weather.type     0 none, 1 rain, 2 snow, 3 ash
		hl2a.weather.active   currently precipitating
		hl2a.weather.density  RainIntensity / amod_weather_rain_density
		hl2a.weather.splashes
		hl2a.weather.radius   r_RainRadius from cfg/rain/<map>.cfg (0 = no weather on this map)
		hl2a.weather.thunder  amod_weather_thunder
		hl2a.weather.maptype  the map's own func_precipitation (1 rain, 2 snow) while ours is off
]]

local CV = HL2A.ConVars
local TI = HL2A.TimeInfo

local DEFAULT_RADIUS = 2000

local function rainRadius()
	local cfg = HL2A.ReadFile( "cfg/rain/" .. HL2A.Map() .. ".cfg" )
	if not cfg then return DEFAULT_RADIUS end
	for line in cfg:gmatch( "[^\r\n]+" ) do
		local r = line:match( "^%s*r_[Rr]ain[Rr]adius%s+(%S+)" )
		if r then return tonumber( r ) or DEFAULT_RADIUS end
	end
	return DEFAULT_RADIUS
end

local function settings()
	if CV.amod_weather_override:GetBool() then
		return {
			enabled = CV.hl2a_weather_enable:GetBool(),
			type = CV.amod_weather_type:GetInt(),
			intervals = CV.amod_weather_do_in_intervals:GetBool(),
			waitMin = CV.amod_weather_wait_min:GetFloat(),
			waitMax = CV.amod_weather_wait_max:GetFloat(),
			density = CV.amod_weather_rain_density:GetFloat(),
			splashes = CV.amod_weather_rain_splashes:GetBool(),
		}
	end

	local w = TI.GetSubTable( "weather" )
	return {
		enabled = tobool( w.weatherenabled ),
		type = tonumber( w.weathertype ) or 0,
		intervals = tobool( w.weatherruninintervals ),
		waitMin = tonumber( w.weatherwaittimemin ) or 300,
		waitMax = tonumber( w.weatherwaittimemax ) or 600,
		density = tonumber( w.rainintensity ) or 0.001,
		splashes = w.rainsplashparticles ~= "0",
	}
end

local cfg

-- The map's own precipitation (func_precipitation "preciptype"), so the
-- client plays rain/snow ambience on maps that rain by themselves.
-- 0 rain, 1 snow, 2 ash, 3 snowfall, 4 particle rain, 5 particle ash,
-- 6 particle rainstorm, 7 particle snow
local MAP_PRECIP = { [ 0 ] = 1, [ 1 ] = 2, [ 3 ] = 2, [ 4 ] = 1, [ 6 ] = 1, [ 7 ] = 2 }
local precipTypes = {} -- func_precipitation -> preciptype (default 0, rain)
local mapPrecip

hook.Add( "OnEntityCreated", "hl2a.weather.mapprecip", function( ent )
	if ent:GetClass() == "func_precipitation" then precipTypes[ ent ] = 0 end
end )

hook.Add( "EntityKeyValue", "hl2a.weather.mapprecip", function( ent, key, value )
	if key:lower() == "preciptype" and ent:GetClass() == "func_precipitation" then
		precipTypes[ ent ] = tonumber( value ) or 0
	end
end )

-- Worked out once, before our weather may remove the brushes. Rain wins if a map mixes types.
local function mapPrecipType()
	if mapPrecip then return mapPrecip end
	mapPrecip = 0
	for _, t in pairs( precipTypes ) do
		local kind = MAP_PRECIP[ t ]
		if kind and ( mapPrecip == 0 or kind == 1 ) then mapPrecip = kind end
	end
	return mapPrecip
end

local function setActive( active )
	SetGlobal2Bool( "hl2a.weather.active", active )
	if cfg.intervals then
		timer.Create( "hl2a.weather.interval", math.Rand( cfg.waitMin, cfg.waitMax ), 1, function()
			setActive( not GetGlobal2Bool( "hl2a.weather.active" ) )
		end )
	end
end

function HL2A.ApplyWeather()
	cfg = settings()
	local radius = rainRadius()
	local on = cfg.enabled and cfg.type ~= 0 and radius > 0

	SetGlobal2Int( "hl2a.weather.type", on and cfg.type or 0 )
	-- Our weather replaces the map's own (removed below), so it only counts when ours is off
	SetGlobal2Int( "hl2a.weather.maptype", on and 0 or mapPrecipType() )
	SetGlobal2Float( "hl2a.weather.density", cfg.density )
	SetGlobal2Bool( "hl2a.weather.splashes", cfg.splashes )
	SetGlobal2Float( "hl2a.weather.radius", radius )
	SetGlobal2Bool( "hl2a.weather.thunder", CV.amod_weather_thunder:GetBool() )

	timer.Remove( "hl2a.weather.interval" )
	if on then setActive( not cfg.intervals ) else SetGlobal2Bool( "hl2a.weather.active", false ) end

	-- The maps' own brush rain would play alongside (e.g. rain under the
	-- snowey coast theme's snow), so remove it while our weather is on.
	-- It comes back on the next map load.
	if on then
		for _, ent in ipairs( ents.FindByClass( "func_precipitation" ) ) do SafeRemoveEntity( ent ) end
	end
end

hook.Add( "InitPostEntity", "hl2a.weather", function() HL2A.ApplyWeather() end )

for _, name in ipairs( { "hl2a_timeinfo_theme", "amod_weather_override", "hl2a_weather_enable",
	"amod_weather_type", "amod_weather_do_in_intervals", "amod_weather_wait_min", "amod_weather_wait_max",
	"amod_weather_rain_density", "amod_weather_rain_splashes", "amod_weather_thunder" } ) do
	cvars.AddChangeCallback( name, function() timer.Simple( 0, HL2A.ApplyWeather ) end, "hl2a.weather" )
end
