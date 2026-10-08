--[[
	logic_achievement - GMod doesn't have this HL2 entity, so the mod's maps
	("Attempted to create unknown entity type logic_achievement!") need a
	Lua version. Fires HL2A.Achievements.Award with the event's component.

	Keyvalues: AchievementEvent ("ACHIEVEMENT_EVENT_<component>"), StartDisabled
	Inputs:    FireEvent, Enable, Disable, Toggle
	Outputs:   OnFired
]]

ENT.Type = "point"

local EVENT_PREFIX = "ACHIEVEMENT_EVENT_"

function ENT:KeyValue( key, value )
	key = key:lower()
	if key == "achievementevent" then
		self.Event = value
	elseif key == "startdisabled" then
		self.Disabled = tobool( value )
	elseif key == "onfired" then
		self:StoreOutput( key, value )
	end
end

function ENT:AcceptInput( name, activator, caller )
	name = name:lower()
	if name == "enable" then
		self.Disabled = false
	elseif name == "disable" then
		self.Disabled = true
	elseif name == "toggle" then
		self.Disabled = not self.Disabled
	elseif name == "fireevent" then
		if self.Disabled then return true end
		local event = self.Event or ""
		if event:StartWith( EVENT_PREFIX ) then
			HL2A.Achievements.Award( event:sub( #EVENT_PREFIX + 1 ) )
		else
			MsgN( "[HL2A] logic_achievement with unknown event '" .. event .. "'" )
		end
		self:TriggerOutput( "OnFired", activator )
	else
		return false
	end
	return true
end
