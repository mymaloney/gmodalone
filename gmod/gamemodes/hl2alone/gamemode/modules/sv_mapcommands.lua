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

-- fadein / fadeout {time r g b}, as the engine commands; ply NULL = everyone
local function screenFade( ply, args, flags )
	local t, r, g, b = args:match( "^(%S*)%s*(%S*)%s*(%S*)%s*(%S*)" )
	local col = Color( tonumber( r ) or 0, tonumber( g ) or 0, tonumber( b ) or 0, 255 )
	local time = tonumber( t ) or 2
	if IsValid( ply ) then ply:ScreenFade( flags, col, time, 0 )
	else for _, p in player.Iterator() do p:ScreenFade( flags, col, time, 0 ) end end
end

function HL2A.MapCommandChangeLevel( cmd, args )
	local map, landmark = args:match( "^(%S+)%s*(%S*)" )
	if not map then return end
	if not file.Exists( "maps/" .. map .. ".bsp", "GAME" ) then
		MsgN( "[HL2A] map-fired " .. cmd .. " to missing map '" .. map .. "'" )
		return
	end
	MsgN( "[HL2A] map-fired " .. cmd .. " " .. args )
	-- Multiplayer: carry everyone's health and weapons over, as a level exit does
	if not game.SinglePlayer() and cmd == "changelevel" then HL2A.SaveTransitionCarry( map:lower(), landmark ) end
	if landmark ~= "" then RunConsoleCommand( cmd, map, landmark ) else RunConsoleCommand( cmd, map ) end
end

-- handler( ply, args ) where ply is the command's target player (may be NULL)
-- "give <class>" fired by maps: EP2's first map hands out the gravity gun
-- (trigger_Get_physgun) and the suit this way, the EP1 intro and Breen's
-- chapter the suit, portal_07 the gravity gun. GMod treats give as a cheat
-- and won't run it from a map, so they silently failed (EP2 softlocked
-- without the gravity gun). Weapons and the suit go to every player, so
-- nobody in co-op is left without them; other items to whoever set it off.
local function giveItem( ply, args )
	local class = ( args:match( "^(%S+)" ) or "" ):lower()
	if not class:match( "^weapon_" ) and not class:match( "^item_" ) then return end
	local everyone = class:match( "^weapon_" ) or class == "item_suit" or not IsValid( ply )
	local function give( p )
		if not IsValid( p ) or not p:Alive() then return end
		if class == "item_suit" then
			p:EquipSuit()
		elseif not p:HasWeapon( class ) then
			p:Give( class )
		end
	end
	if everyone then
		for _, p in player.Iterator() do give( p ) end
	else
		give( ply )
	end
	MsgN( "[HL2A] map gave " .. class .. ( everyone and " to everyone" or ( " to " .. ply:Nick() ) ) )
end

local HANDLERS = {
	give = function( ply, args ) giveItem( ply, args ) end,

	-- The maps' anti-piracy check fired this; build_addon.py strips that from
	-- the maps (tools/strip_antipiracy.py), and this stays as a safety net
	quit = function( _, _, ent )
		MsgN( "[HL2A] ignored 'quit' fired by map entity " .. tostring( ent ) )
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

	-- Videos (converted to WebM by build_addon.py --videos; cl_video.lua)
	playvideo = function( _, args ) if args ~= "" then HL2A.SendVideo( args:match( "^(%S+)" ) ) end end,
	amod_playvideo = function( _, args ) if args ~= "" then HL2A.SendVideo( args:match( "^(%S+)" ) ) end end,
	amod_outrotest = function() HL2A.SendVideo( "amod_outrovideo" ) end,

	-- Screen fades. GMod won't run these from the server, so a map that
	-- fades to black with "Stay Out" and lifts it with "fadein" (e.g. the
	-- ep1_citadel_00_d intro) stayed black for good.
	fadein = function( ply, args )
		screenFade( ply, args, SCREENFADE.IN + SCREENFADE.PURGE )
		hook.Run( "HL2A_ScreenFadeIn" )
	end,
	fadeout = function( ply, args ) screenFade( ply, args, SCREENFADE.OUT + SCREENFADE.STAYOUT ) end,

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
			hook.Run( "HL2A_MapCommandPassthrough", name, cmd, ent )
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

-- The anti-piracy texts are stripped from the maps at build time
-- (tools/strip_antipiracy.py). If one still turns up, the map GMod loaded is
-- an unpatched copy (e.g. garrysmod/maps/ from the cubemap rebuild): say so.
local PIRACY_TEXT = { "moddb%.com/mods/half%-life%-2%-alone", "whatever your playing it on" }
local piracyWarned = false

-- Every place the current map exists, and whether the copy GMod loads
-- ("GAME") still carries the check. Run automatically when it turns up.
local function mapContainsPiracy( path, searchPath )
	local f = file.Open( path, "rb", searchPath )
	if not f then return nil end
	f:Seek( 8 )
	local ofs, len = f:ReadLong(), f:ReadLong()
	f:Seek( ofs )
	local lump = f:Read( len ) or ""
	f:Close()
	if lump:sub( 1, 4 ) == "LZMA" then return "compressed: can't tell" end
	lump = lump:lower()
	return lump:find( "moddb.com/mods/half-life-2-alone", 1, true ) ~= nil or lump:find( "whatever your playing it on", 1, true ) ~= nil
end

function HL2A.WhichMap()
	local map = game.GetMap()
	local path = "maps/" .. map .. ".bsp"
	MsgN( "[HL2A] where " .. path .. " exists (GMod loads the first that wins: garrysmod/, then addons, then games):" )
	local function report( label, searchPath, file_ )
		file_ = file_ or path
		if not file.Exists( file_, searchPath ) then return end
		local has = mapContainsPiracy( file_, searchPath )
		MsgN( string.format( "  %-40s %8.1f MB  anti-piracy: %s", label, file.Size( file_, searchPath ) / 1048576,
			has == true and "YES" or has == false and "no" or tostring( has ) ) )
	end
	report( "loaded copy (GAME)", "GAME" )
	report( "garrysmod/ (MOD)", "MOD" )
	for _, dir in ipairs( select( 2, file.Find( "addons/*", "MOD" ) ) or {} ) do
		report( "legacy addon addons/" .. dir, "MOD", "addons/" .. dir .. "/" .. path )
	end
	for _, a in ipairs( engine.GetAddons() ) do
		if a.mounted then report( "Workshop: " .. a.title .. " (" .. tostring( a.wsid ) .. ")", a.title ) end
	end
	for _, g in ipairs( engine.GetGames() ) do
		if g.mounted then report( "game: " .. g.title, g.folder ) end
	end
	if file.Exists( "maps/" .. map .. "_l_0.lmp", "GAME" ) then MsgN( "  NOTE: maps/" .. map .. "_l_0.lmp overrides this map's entities" ) end
end

concommand.Add( "hl2a_whichmap", function( ply )
	if IsValid( ply ) and not ply:IsListenServerHost() then return end
	HL2A.WhichMap()
end, nil, "List every copy of the current map GMod can see, and which still has the anti-piracy check" )

local function isPiracyText( value )
	value = value:lower()
	for _, p in ipairs( PIRACY_TEXT ) do
		if value:find( p ) then return true end
	end
	return false
end

hook.Add( "EntityKeyValue", "hl2a.f1hint", function( ent, key, value )
	if key:lower() ~= "message" then return end
	local class = ent:GetClass()
	if TEXT_CLASSES[ class ] then
		if isPiracyText( value ) then
			if not piracyWarned then
				piracyWarned = true
				MsgN( "[HL2A] WARNING: this copy of " .. game.GetMap() .. " still has the mod's anti-piracy check. Run"
					.. " tools/strip_antipiracy.py on your garrysmod folder (see PORTING.md)." )
				timer.Simple( 0, HL2A.WhichMap )
			end
			return " "
		end
		return HL2A.FixHintText( value )
	elseif class == "ambient_generic" then
		-- Map music named as .wav may ship as .ogg (build_addon.py --music-ogg)
		local resolved = HL2A.ResolveSound( value )
		if resolved ~= value then return resolved end
	end
end )
