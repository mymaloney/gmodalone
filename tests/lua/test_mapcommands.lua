-- Map-fired commands: give works (everyone gets weapons/suit), quit is blocked, fadein lifts fades
SINGLEPLAYER = false
HL2A.FixHintText = function( v ) return v end
GM_LOAD( "modules/sv_mapcommands.lua" )
local A, B = MakePlayer( "a" ), MakePlayer( "b" )
A.suit, B.suit = false, false
local cc = MakeEnt( "point_clientcommand", { name = "c" } )

assert( hook.Run( "AcceptInput", cc, "Command", A, cc, "give weapon_physcannon" ) == true )
assert( A.weapons.weapon_physcannon and B.weapons.weapon_physcannon, "weapons go to every player" )
hook.Run( "AcceptInput", cc, "Command", NULL, cc, "give item_suit" )
assert( A.suit and B.suit, "the suit too" )
hook.Run( "AcceptInput", cc, "Command", A, cc, "give item_healthvial" )
assert( A.weapons.item_healthvial and not B.weapons.item_healthvial, "other items only to whoever set it off" )

CMDS = nil
assert( hook.Run( "AcceptInput", cc, "Command", A, cc, "quit" ) == true, "quit swallowed" )
for _, c in ipairs( CMDS or {} ) do assert( c[ 1 ] ~= "quit", "quit never runs" ) end

local lifted = false
hook.Add( "HL2A_ScreenFadeIn", "test", function() lifted = true end )
hook.Run( "AcceptInput", cc, "Command", A, cc, "fadein 1" )
assert( lifted, "fadein handled" )
