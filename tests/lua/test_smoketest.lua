-- The smoke test walks the maps and reports errors, missing models and stuck fades per map
GM_LOAD( "core/sh_instrument.lua" )
HL2A.ModMaps = function() return { "d1_a_d", "d1_b_d" } end
HL2A.CheckpointInfo = function() return true, 2 end
HL2A.SoundscapeCount = function() return 3 end
util.IsValidModel = function( m ) return m ~= "models/missing.mdl" end
sound = { GetProperties = function() return {} end }
ents.Create = function( c ) return MakeEnt( c ) end
file.Open = function() return nil end
GM_LOAD( "modules/sh_smoketest.lua" )

CMD_hl2a_smoketest( nil, "hl2a_smoketest", { "start", "5" } )
Tick( 1.1 )
assert( CMDS[ #CMDS ][ 1 ] == "map" and CMDS[ #CMDS ][ 2 ] == "d1_a_d", "loads the first map" )

-- map 1 loads: an error, a missing model, a fade left on
MAP = "d1_a_d"
hook.Run( "InitPostEntity" )
local P = MakePlayer( "p" )
hook.Run( "PlayerSpawn", P )
MakeEnt( "prop_physics", { model = "models/missing.mdl" } )
HL2A.RecordError( "boom", "trace", "Think hl2a.x" )
local fade = MakeEnt( "env_fade", { name = "fade_out", spawnflags = 8 } )
hook.Run( "AcceptInput", fade, "Fade" )
Tick( 5.5 ) Tick( 2.1 ) Tick( 1.1 )
assert( CMDS[ #CMDS ][ 2 ] == "d1_b_d", "moves on to the next map" )

local report = FILES[ "hl2alone/smoketest_report.txt" ]
assert( report, "report written" )
assert( report:find( "== d1_a_d  3 issue(s)", 1, true ), report )
assert( report:find( "models/missing.mdl", 1, true ) and report:find( "boom", 1, true ) and report:find( "fade_out", 1, true ) )
assert( report:find( "checkpoint: yes (2 autosaves)   soundscapes: 3", 1, true ) )
