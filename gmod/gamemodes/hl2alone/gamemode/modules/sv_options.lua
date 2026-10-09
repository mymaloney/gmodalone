--[[
	Applies options panel changes (sent by cl_options.lua) and the
	"Disable Soundscapes" option.
]]

util.AddNetworkString( "hl2a.options" )

net.Receive( "hl2a.options", function( _, ply )
	if not ply:IsListenServerHost() then return end

	for _ = 1, net.ReadUInt( 8 ) do
		local name, value = net.ReadString(), net.ReadString()
		-- The options panel's settings, or (Effects panel convar page) any of the gamemode's own
		if HL2A.OptionConVars[ name ] or HL2A.ConVars[ name ] then RunConsoleCommand( name, value ) end
	end
end )

-- Soundscapes ---------------------------------------------------------------------

local SOUNDSCAPE_CLASSES = { "env_soundscape", "env_soundscape_proxy", "env_soundscape_triggerable" }

local function applySoundscapes()
	local off = HL2A.ConVars.amod_soundscapes_disable:GetBool()
	for _, class in ipairs( SOUNDSCAPE_CLASSES ) do
		for _, ent in ipairs( ents.FindByClass( class ) ) do
			-- Re-enabling turns every soundscape back on, including any the map had disabled
			ent:Fire( off and "Disable" or "Enable" )
		end
	end
	if off then
		for _, ply in player.Iterator() do ply:ConCommand( "stopsoundscape" ) end
	end
end

hook.Add( "InitPostEntity", "hl2a.soundscapes", function()
	if HL2A.ConVars.amod_soundscapes_disable:GetBool() then applySoundscapes() end
end )

cvars.AddChangeCallback( "amod_soundscapes_disable", function() timer.Simple( 0, applySoundscapes ) end, "hl2a.soundscapes" )
