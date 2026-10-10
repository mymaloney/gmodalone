-- Dying brings you back at the last autosave with that kit, plus HL2 weapons picked up since
SINGLEPLAYER = true
SetCV( "hl2a_checkpoints", 1 ) SetCV( "amod_enable_god", 0 )
GM_LOAD( "modules/sv_transitions.lua" )
GM_LOAD( "modules/sv_checkpoints.lua" )

local P = MakePlayer( "gordon", Vector( 100, 0, 0 ) )
P:Give( "weapon_crowbar" )
hook.Run( "InitPostEntity" )
hook.Run( "PlayerSpawn", P )
Tick( 3.5 ) -- level-start checkpoint

P.pos = Vector( 900, 0, 0 ) P:Give( "weapon_pistol" ) P.health = 12
local auto = MakeEnt( "logic_autosave", { name = "as1" } )
hook.Run( "AcceptInput", auto, "Save" )

-- picks up the shotgun after the autosave
local sg = P:Give( "weapon_shotgun" )
sg.GetPrimaryAmmoType = function() return 7 end
sg.GetSecondaryAmmoType = function() return -1 end
P.ammo[ 7 ] = 12
hook.Run( "WeaponEquip", sg, P )
-- something from another addon isn't tracked
local other = P:Give( "weapon_physgun" )
hook.Run( "WeaponEquip", other, P )
Tick( 0.1 )

-- dies; the respawn comes with nothing at the map start
P.alive = false hook.Run( "PlayerDeath", P )
P.alive, P.pos, P.weapons, P.health = true, Vector( 0, 0, 0 ), {}, 100
assert( HL2A.RestoreCheckpoint( P ) == true )
Tick( 0.1 )
assert( P.pos.x == 900, "back at the autosave" )
assert( P.weapons.weapon_crowbar and P.weapons.weapon_pistol and P.weapons.weapon_shotgun, "kit incl. the shotgun picked up since" )
assert( not P.weapons.weapon_physgun, "other addons' weapons aren't added" )
assert( P.ammo.Buckshot == 12, "ammo that came with it" )
assert( P.health == 25, "never back on the brink of death" )
assert( P.god == true ) Tick( 3 ) assert( P.god == false, "spawn protection wears off" )
assert( HL2A.RestoreCheckpoint( P ) == false, "only after a death" )
