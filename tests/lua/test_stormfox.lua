-- With StormFox 2: the map's weather is handed over; its settings are session-only and restored
SetCV( "hl2a_stormfox", 1 ) SetCV( "hl2a_stormfox_fog", 0 ) SetCV( "hl2a_stormfox_sky", 0 )
SetCV( "hl2a_stormfox_time", "23:30" ) SetCV( "hl2a_stormfox_time_flow", 0 ) SetCV( "hl2a_stormfox_maplight", 0 )
SetCV( "amod_weather_thunder", 1 )
local sf = { enable = true, auto_weather = true, day_length = 12, night_length = 12, maplight_auto = true, enable_svfog = true,
	enable_skybox = true, real_time = false, random_time = false, openweathermap_enabled = false, maplight_lightenv = false,
	maplight_colormod = false, maplight_dynamic = false, maplight_lightstyle = false, allow_weather_lightchange = true }
local saved, calls = {}, {}
StormFox2 = {
	Setting = { GetObject = function( n ) return sf[ n ] ~= nil end, Get = function( n ) return sf[ n ] end,
		Set = function( n, v, nosave ) sf[ n ] = v if not nosave then saved[ n ] = v end end },
	Time = { Set = function( t ) calls.time = t end },
	Weather = { Set = function( n, p ) calls.weather = { n, p } end },
	Temperature = { Set = function( t ) calls.temp = t end },
	Thunder = { SetEnabled = function( on ) calls.thunder = on end },
}
GM_LOAD( "modules/sh_stormfox.lua" )
GLOBALS[ "hl2a.weather.type" ], GLOBALS[ "hl2a.weather.active" ], GLOBALS[ "hl2a.weather.density" ] = 1, true, 0.003
hook.Run( "InitPostEntity" ) Tick( 1.1 )
assert( calls.time == 23 * 60 + 30 and calls.weather[ 1 ] == "Rain" and calls.temp == 12 and calls.thunder == true )
assert( sf.auto_weather == false and sf.day_length == 0 and sf.enable_skybox == false and sf.maplight_auto == false )
assert( next( saved ) == nil, "nothing written to StormFox's settings file" )
GLOBALS[ "hl2a.weather.type" ] = 2 Tick( 2.1 )
assert( calls.temp == -6 and calls.thunder == false, "snow: rain below freezing, no thunder" )
hook.Run( "ShutDown" )
assert( sf.auto_weather == true and sf.day_length == 12 and sf.enable_skybox == true, "restored on exit" )
