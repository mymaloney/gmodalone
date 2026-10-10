-- Our callbacks are wrapped (timed, errors caught), others' aren't; return values pass through
GM_LOAD( "core/sh_instrument.lua" )
local otherFn = function() return 42 end
local f = loadstring( 'hook.Add( "Think", "other", OTHER )', "@addons/x/lua/autorun/y.lua" )
OTHER = otherFn
f()
assert( HOOKS.Think.other == otherFn, "another addon's hook is untouched" )

local ours = loadstring( [[
	hook.Add( "SetupWorldFog", "hl2a.fog", function() return true end )
	hook.Add( "PlayerNoClip", "hl2a.sandbox", function() return false end )
	hook.Add( "Think", "hl2a.broken", function() error( "kaboom" ) end )
]], "@gamemodes/hl2alone/gamemode/modules/x.lua" )
ours()
assert( HOOKS.SetupWorldFog[ "hl2a.fog" ]() == true )
assert( HOOKS.PlayerNoClip[ "hl2a.sandbox" ]() == false )
assert( HOOKS.Think[ "hl2a.broken" ]() == nil, "an error doesn't propagate" )
assert( #HL2A.Log.errors == 1 and HL2A.Log.errors[ 1 ].where == "Think hl2a.broken" )
assert( HL2A.Perf.calls[ "SetupWorldFog hl2a.fog" ] == 1 )
MsgN( "captured line" )
assert( HL2A.Log.lines[ #HL2A.Log.lines ] == "captured line" )
