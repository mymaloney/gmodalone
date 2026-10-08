--[[
	Client side of map-fired commands (sv_mapcommands.lua).
]]

local CLIENT_CMDS = {
	rain_stopsounds = function()
		if HL2A.Weather then HL2A.Weather.MuteLoop() end
	end,

	credits_song = function()
		HL2A.Music.PlayPath( "music/credits.wav" )
	end,

	-- End of the game: the mod returned to its main menu
	startupmenu = function()
		gui.ActivateGameUI()
	end,
}

net.Receive( "hl2a.cmd", function()
	local name, arg = net.ReadString(), net.ReadString()
	local fn = CLIENT_CMDS[ name ]
	if fn then fn( arg ) end
end )
