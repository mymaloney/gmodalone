--[[
	Weather state (server-authoritative, rendered in cl_weather.lua).

	Settings come from the map's time_info "weather" block, or from the
	amod_weather_* convars when amod_weather_override is 1. Supports running
	in intervals (on for a random wait, off for a random wait) and thunder at
	the map's resource/thunder_locations.txt origins.

	Networked via GlobalVar2:
		hl2a.weather.type     0 none, 1 rain, 2 snow, 3 ash
		hl2a.weather.active   currently precipitating
		hl2a.weather.density  RainIntensity / amod_weather_rain_density
		hl2a.weather.splashes
		hl2a.weather.radius   r_RainRadius from cfg/rain/<map>.cfg (0 = no weather on this map)
]]

local CV = HL2A.ConVars
local TI = HL2A.TimeInfo

util.AddNetworkString( "hl2a.thunder" )

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
	SetGlobal2Float( "hl2a.weather.density", cfg.density )
	SetGlobal2Bool( "hl2a.weather.splashes", cfg.splashes )
	SetGlobal2Float( "hl2a.weather.radius", radius )

	timer.Remove( "hl2a.weather.interval" )
	if on then setActive( not cfg.intervals ) else SetGlobal2Bool( "hl2a.weather.active", false ) end
end

local function thunder()
	timer.Create( "hl2a.thunder", math.Rand( 8, 30 ), 1, thunder )

	if not CV.amod_weather_thunder:GetBool() then return end
	if not GetGlobal2Bool( "hl2a.weather.active" ) or GetGlobal2Int( "hl2a.weather.type" ) ~= 1 then return end

	local spots = TI.GetThunderLocations()
	if #spots == 0 then return end
	local pos = spots[ math.random( #spots ) ]

	EmitSound( "weather.thunder", pos, 0 )
	net.Start( "hl2a.thunder" )
		net.WriteVector( pos )
	net.Broadcast()
end

hook.Add( "InitPostEntity", "hl2a.weather", function()
	HL2A.ApplyWeather()
	thunder()
end )

for _, name in ipairs( { "amod_day", "hl2a_timeinfo_theme", "amod_weather_override", "hl2a_weather_enable",
	"amod_weather_type", "amod_weather_do_in_intervals", "amod_weather_wait_min", "amod_weather_wait_max",
	"amod_weather_rain_density", "amod_weather_rain_splashes" } ) do
	cvars.AddChangeCallback( name, function() timer.Simple( 0, HL2A.ApplyWeather ) end, "hl2a.weather" )
end
