--[[
	env_hudhint - missing from GMod ("Attempted to create unknown entity type
	env_hudhint!"). Shows the HL2-style key hint, e.g. "#Valve_Hint_Sprint".

	Keyvalues: message, spawnflags (1 = all players)
	Inputs:    ShowHudHint, HideHudHint
]]

ENT.Type = "point"

function ENT:KeyValue( key, value )
	if key:lower() == "message" then self.Message = value end
end

function ENT:AcceptInput( name, activator )
	name = name:lower()
	if name ~= "showhudhint" and name ~= "hidehudhint" then return false end

	local target = ( bit.band( self:GetSpawnFlags(), 1 ) == 0 and IsValid( activator ) and activator:IsPlayer() ) and activator or nil
	HL2A.SendHudHint( target, name == "showhudhint" and ( self.Message or "" ) or "" )
	return true
end
