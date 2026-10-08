--[[
	Console commands fired by the maps through point_clientcommand /
	point_servercommand "Command" inputs (see tools/audit_assets.py).

	The original mod handled the amod_* ones in its DLLs. Here each command
	in the input is checked against HANDLERS; anything unhandled is run as
	normal. "quit" is blocked outright: 95 maps fire it (an error/anti-tamper
	path), and a map must never be able to close GMod.
]]

util.AddNetworkString( "hl2a.cmd" )

local function toClient( ply, name, arg )
	net.Start( "hl2a.cmd" )
		net.WriteString( name )
		net.WriteString( arg or "" )
	if IsValid( ply ) then net.Send( ply ) else net.Broadcast() end
end

local function ignore() end

-- handler( ply, args ) where ply is the command's target player (may be NULL)
local HANDLERS = {
	quit = function( _, _, ent )
		MsgN( "[HL2A] blocked 'quit' fired by map entity " .. tostring( ent ) )
	end,
	exit = function( ply, args, ent ) MsgN( "[HL2A] blocked 'exit' fired by " .. tostring( ent ) ) end,
	disconnect = function( ply, args, ent ) MsgN( "[HL2A] blocked 'disconnect' fired by " .. tostring( ent ) ) end,

	amod_rain_stopsounds = function( ply ) toClient( ply, "rain_stopsounds" ) end,
	amod_startcreditssong = function( ply ) toClient( ply, "credits_song" ) end,
	startupmenu = function( ply, args ) toClient( ply, "startupmenu", args ) end,

	-- Menu-background / commentary helpers with no GMod equivalent
	amod_random_background = ignore,
	commentary_testfirstrun = ignore,
}

local function splitCommands( str )
	local out = {}
	for part in ( str or "" ):gmatch( "[^;]+" ) do
		part = part:Trim()
		if part ~= "" then out[ #out + 1 ] = part end
	end
	return out
end

hook.Add( "AcceptInput", "hl2a.mapcommands", function( ent, input, activator, caller, value )
	if input:lower() ~= "command" then return end

	local class = ent:GetClass()
	local isClient = class == "point_clientcommand"
	if not isClient and class ~= "point_servercommand" then return end

	local cmds = splitCommands( value )
	local passthrough, handled = {}, false

	for _, cmd in ipairs( cmds ) do
		local name, args = cmd:match( "^(%S+)%s*(.*)$" )
		local handler = HANDLERS[ name:lower() ]
		if handler then
			handled = true
			local ply = isClient and activator or Entity( 1 )
			handler( IsValid( ply ) and ply:IsPlayer() and ply or NULL, args, ent )
		else
			passthrough[ #passthrough + 1 ] = cmd
		end
	end

	if not handled then return end

	-- Run what's left ourselves, then swallow the original input
	if #passthrough > 0 then
		local rest = table.concat( passthrough, "; " )
		if isClient then
			if IsValid( activator ) and activator:IsPlayer() then activator:ConCommand( rest ) end
		else
			game.ConsoleCommand( rest .. "\n" )
		end
	end
	return true
end )

-- The mod's cfg/game.cfg blanked these error texts after load; same here
hook.Add( "InitPostEntity", "hl2a.texterror", function()
	for _, name in ipairs( { "text_error", "text_error2" } ) do
		for _, ent in ipairs( ents.FindByName( name ) ) do
			ent:SetKeyValue( "message", " " )
		end
	end
end )
