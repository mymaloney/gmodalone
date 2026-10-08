--[[
	Console commands fired by the maps through point_clientcommand /
	point_servercommand "Command" inputs (see tools/audit_assets.py).

	The original mod handled the amod_* ones in its DLLs. Here each command
	in the input is checked against HANDLERS; anything unhandled is run as
	normal. "quit" is blocked outright: 95 maps fire it (an error/anti-tamper
	path), and a map must never be able to close GMod.
]]

util.AddNetworkString( "hl2a.cmd" )
util.AddNetworkString( "hl2a.hudhint" )

--- Shows (or with an empty message, hides) the HL2 key hint. ply nil = everyone.
function HL2A.SendHudHint( ply, message )
	net.Start( "hl2a.hudhint" )
		net.WriteString( message )
	if IsValid( ply ) then net.Send( ply ) else net.Broadcast() end
end

local function toClient( ply, name, arg )
	net.Start( "hl2a.cmd" )
		net.WriteString( name )
		net.WriteString( arg or "" )
	if IsValid( ply ) then net.Send( ply ) else net.Broadcast() end
end

local function ignore() end

function HL2A.MapCommandChangeLevel( cmd, args )
	local map, landmark = args:match( "^(%S+)%s*(%S*)" )
	if not map then return end
	if not file.Exists( "maps/" .. map .. ".bsp", "GAME" ) then
		MsgN( "[HL2A] map-fired " .. cmd .. " to missing map '" .. map .. "'" )
		return
	end
	MsgN( "[HL2A] map-fired " .. cmd .. " " .. args )
	if landmark ~= "" then RunConsoleCommand( cmd, map, landmark ) else RunConsoleCommand( cmd, map ) end
end

-- handler( ply, args ) where ply is the command's target player (may be NULL)
local HANDLERS = {
	quit = function( _, _, ent )
		MsgN( "[HL2A] blocked 'quit' fired by map entity " .. tostring( ent ) )
	end,
	exit = function( ply, args, ent ) MsgN( "[HL2A] blocked 'exit' fired by " .. tostring( ent ) ) end,
	disconnect = function( ply, args, ent ) MsgN( "[HL2A] blocked 'disconnect' fired by " .. tostring( ent ) ) end,

	-- Level changes fired as commands. GMod won't run these from map
	-- entities, so the transition silently never happened.
	changelevel = function( _, args ) HL2A.MapCommandChangeLevel( "changelevel", args ) end,
	changelevel2 = function( _, args ) HL2A.MapCommandChangeLevel( "changelevel", args ) end,
	map = function( _, args ) HL2A.MapCommandChangeLevel( "map", args ) end,

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

-- Map texts telling the player about the TAB filter -> F1 hint
local TEXT_CLASSES = { game_text = true, env_message = true, point_message = true }

hook.Add( "EntityKeyValue", "hl2a.f1hint", function( ent, key, value )
	if key:lower() ~= "message" then return end
	local class = ent:GetClass()
	if TEXT_CLASSES[ class ] then
		return HL2A.FixHintText( value )
	elseif class == "ambient_generic" then
		-- Map music named as .wav may ship as .ogg (build_addon.py --music-ogg)
		local resolved = HL2A.ResolveSound( value )
		if resolved ~= value then return resolved end
	end
end )

-- The mod's cfg/game.cfg blanked these error texts after load; same here
hook.Add( "InitPostEntity", "hl2a.texterror", function()
	for _, name in ipairs( { "text_error", "text_error2" } ) do
		for _, ent in ipairs( ents.FindByName( name ) ) do
			ent:SetKeyValue( "message", " " )
		end
	end
end )
