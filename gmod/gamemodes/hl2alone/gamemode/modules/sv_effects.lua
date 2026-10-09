--[[
	Server side of the Effects panel: tells the client when the player is
	carrying something (gravity gun or +use), for the "When holding object"
	condition. The client can't see that by itself.
]]

local function holding( ply, on )
	if IsValid( ply ) and ply:IsPlayer() then ply:SetNW2Bool( "hl2a.holding", on ) end
end

hook.Add( "GravGunOnPickedUp", "hl2a.effects", function( ply ) holding( ply, true ) end )
hook.Add( "GravGunOnDropped", "hl2a.effects", function( ply ) holding( ply, false ) end )
hook.Add( "OnPlayerPhysicsPickup", "hl2a.effects", function( ply ) holding( ply, true ) end )
hook.Add( "OnPlayerPhysicsDrop", "hl2a.effects", function( ply ) holding( ply, false ) end )
hook.Add( "PlayerDeath", "hl2a.effects", function( ply ) holding( ply, false ) end )
