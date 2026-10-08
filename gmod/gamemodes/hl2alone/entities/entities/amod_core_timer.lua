--[[
	amod_core_timer - the Alone mod's Episode One countdown entity
	(CAmodCoreTimer in the original server.dll). Placed in 13 ep1 maps and
	spawned by the ep1_citadel_03_d map patch. The countdown itself lives
	in modules/sv_timers.lua.

	Inputs:
		StartCoreTimer <seconds>     StartCitadelTimer <seconds>
		StopCoreTimer                StopCitadelTimer
		ShowCoreTime                 ShowCitadel
		Disable                      (blocks the Show inputs)
]]

ENT.Type = "point"

function ENT:Initialize()
	self.Enabled = true
end

local INPUTS = {
	startcoretimer = function( self, data ) HL2A.StartTimer( "core", data ) end,
	startcitadeltimer = function( self, data ) HL2A.StartTimer( "citadel", data ) end,
	stopcoretimer = function() HL2A.StopTimer( "core" ) end,
	stopcitadeltimer = function() HL2A.StopTimer( "citadel" ) end,
	showcoretime = function( self ) if self.Enabled then HL2A.ShowTimer( "core" ) end end,
	showcitadel = function( self ) if self.Enabled then HL2A.ShowTimer( "citadel" ) end end,
	disable = function( self ) self.Enabled = false end,
}

-- Names used by the original map patch / likely typos in Hammer
INPUTS.showcoretimer = INPUTS.showcoretime
INPUTS.showcitadeltime = INPUTS.showcitadel

function ENT:AcceptInput( name, activator, caller, data )
	local fn = INPUTS[ name:lower() ]
	if not fn then return false end
	fn( self, data )
	return true
end
