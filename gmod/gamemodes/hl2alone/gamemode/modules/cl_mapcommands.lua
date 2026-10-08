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

-- env_hudhint ---------------------------------------------------------------------

local HINT_TIME = 8
local hint

surface.CreateFont( "HL2A.Hint", { font = "Verdana", size = 20, weight = 600 } )

-- "%+speed%" -> the key bound to +speed
local function expandBinds( text )
	return ( text:gsub( "%%(%+?[%w_]+)%%", function( cmd )
		local key = input.LookupBinding( cmd )
		return key and ( "[" .. key:upper() .. "]" ) or ( "<" .. cmd .. " unbound>" )
	end ) )
end

net.Receive( "hl2a.hudhint", function()
	local msg = net.ReadString()
	if msg == "" then hint = nil return end
	local text = expandBinds( language.GetPhrase( ( msg:gsub( "^#", "" ) ) ) )
	hint = { text = HL2A.FixHintText( text ) or HL2A.FixHintText( msg ) or text, start = RealTime() }
end )

hook.Add( "HUDPaint", "hl2a.hudhint", function()
	if not hint then return end
	local age = RealTime() - hint.start
	if age > HINT_TIME then hint = nil return end

	local a = math.Clamp( math.min( age, HINT_TIME - age ) * 3, 0, 1 )
	surface.SetFont( "HL2A.Hint" )
	local tw, th = surface.GetTextSize( hint.text )
	local x, y = ScrW() / 2 - tw / 2 - 16, ScrH() * 0.62
	draw.RoundedBox( 6, x, y, tw + 32, th + 16, Color( 0, 0, 0, 160 * a ) )
	draw.SimpleText( hint.text, "HL2A.Hint", x + 16, y + 8, Color( 255, 220, 0, 255 * a ) )
end )
