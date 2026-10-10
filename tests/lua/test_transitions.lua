-- Co-op level exits: reach the exit, gather, countdown, changelevel; gear and story flags carried
SINGLEPLAYER = false
MAP = "d1_canals_01_d"
SetCV( "hl2a_mp_transitions", 1 ) SetCV( "hl2a_mp_gather_radius", 768 ) SetCV( "hl2a_mp_exit_reach", 128 )
SetCV( "hl2a_mp_transition_delay", 3 ) SetCV( "hl2a_mp_gather_timeout", 0 )
EXISTS = function( p ) return p == "maps/d1_canals_02_d.bsp" end
GM_LOAD( "modules/sv_transitions.lua" )

local trig = MakeEnt( "trigger_changelevel", { mins = Vector( 0, 0, 0 ), maxs = Vector( 100, 100, 100 ), iv = { m_bDisabled = false } } )
MakeEnt( "info_landmark", { name = "lm1", pos = Vector( 50, 50, 0 ) } )
hook.Run( "EntityKeyValue", trig, "map", "D1_canals_02_d" )
hook.Run( "EntityKeyValue", trig, "landmark", "lm1" )
local g = MakeEnt( "env_global" )
hook.Run( "EntityKeyValue", g, "globalstate", "antlion_allied" )

local A = MakePlayer( "a", Vector( 600, 600, 0 ) )
local B = MakePlayer( "b", Vector( 3000, 0, 0 ) )
A:Give( "weapon_crowbar" ) A.health = 80

Tick( 0.2 ) assert( not GLOBALS[ "hl2a.gather" ], "nobody near the exit" )
A.pos = Vector( -130, 50, 10 ) Tick( 0.2 )
assert( GLOBALS[ "hl2a.gather" ] == true, "within reach of the exit starts gathering" )
assert( GLOBALS[ "hl2a.gather.have" ] == 1 and GLOBALS[ "hl2a.gather.need" ] == 2 )
assert( ( GLOBALS[ "hl2a.gather.ends" ] or 0 ) == 0, "no countdown while someone's missing" )

B.pos = Vector( 400, 400, 0 ) A.pos = Vector( 300, 300, 0 ) Tick( 0.2 )
assert( GLOBALS[ "hl2a.gather.have" ] == 2 and GLOBALS[ "hl2a.gather.ends" ] == 0, "everyone near but nobody at the exit: no countdown" )

A.pos = Vector( 50, 50, 10 ) Tick( 0.2 )
assert( GLOBALS[ "hl2a.gather.ends" ] > 0, "countdown" )
GSTATE = { antlion_allied = 1 }
Tick( 4 )
local changed = false
for _, c in ipairs( CMDS or {} ) do if c[ 1 ] == "changelevel" and c[ 2 ] == "d1_canals_02_d" then changed = true end end
assert( changed, "changelevel issued" )

-- Next map: arriving by transition
local saved = FILES[ "hl2alone/mp_carry.json" ]
assert( saved, "carry written" )
HOOKS, TIMERS, ONCE, ENTS, PLAYERS, CMDS, GSTATE = {}, {}, {}, {}, {}, nil, {}
FILES = { [ "hl2alone/mp_carry.json" ] = saved }
MAP = "d1_canals_02_d"
GM_LOAD( "modules/sv_transitions.lua" )
MakeEnt( "info_landmark", { name = "lm1", pos = Vector( 1000, 1000, 0 ) } )
local auto = MakeEnt( "logic_auto" )
assert( hook.Run( "EntityKeyValue", auto, "OnNewGame", "door,Open,,0,-1" ) == "hl2a_no_such_entity,Kill,,0,-1", "OnNewGame dropped on a co-op arrival" )
hook.Run( "EntityKeyValue", auto, "OnMapTransition", "relay_arrive,Trigger,,0,-1" )
MakeEnt( "logic_relay", { name = "relay_arrive" } )
hook.Run( "InitPostEntity" )
assert( GSTATE.antlion_allied == 1, "story flag carried" )

local A2 = MakePlayer( "a", Vector( 0, 0, 0 ) ) A2.weapons, A2.health = {}, 100
assert( HL2A.RestoreTransitionCarry( A2 ) == true )
assert( A2.weapons.weapon_crowbar and A2.health == 80, "gear carried" )
hook.Run( "PlayerSpawn", A2 )
Tick( 0.5 )
assert( A2.pos.x ~= 0, "placed relative to the landmark" )
local arrived = false
for _, f in ipairs( FIRED or {} ) do if f == "relay_arrive.Trigger()" then arrived = true end end
assert( arrived, "OnMapTransition fired" )
