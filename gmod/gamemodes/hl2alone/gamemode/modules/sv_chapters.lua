--[[
	Chapter loading from the mod's cfg/<game>/chapterN.cfg files
	(the original New Game panel ran these). Game folders come from
	resource/gamelist.txt ("Prefix" "HL2" -> cfg/hl2/).

	Usage: hl2a_chapter hl2 5
]]

local KV = HL2A.KV

function HL2A.GetGames()
	local games = {}
	for _, root in ipairs( KV.ParseFile( "resource/gamelist.txt" ) or {} ) do
		for _, g in ipairs( istable( root.value ) and root.value or {} ) do
			if istable( g.value ) then
				games[ #games + 1 ] = { name = g.key, prefix = ( KV.Get( g.value, "Prefix" ) or g.key ):lower() }
			end
		end
	end
	return games
end

function HL2A.GetChapterMap( prefix, n )
	local cfg = HL2A.ReadFile( "cfg/" .. prefix:lower() .. "/chapter" .. n .. ".cfg" )
	return cfg and cfg:match( "map%s+([%w_%-]+)" )
end

concommand.Add( "hl2a_chapter", function( ply, _, args )
	if IsValid( ply ) and not ply:IsListenServerHost() then return end

	local prefix, n = args[ 1 ], tonumber( args[ 2 ] )
	if not prefix or not n then
		local names = {}
		for _, g in ipairs( HL2A.GetGames() ) do names[ #names + 1 ] = "\"" .. g.prefix .. "\"" end
		MsgN( "usage: hl2a_chapter <game> <chapter>   games: " .. table.concat( names, ", " ) )
		return
	end

	local map = HL2A.GetChapterMap( prefix, n )
	if not map then MsgN( "[HL2A] no chapter " .. n .. " for " .. prefix ) return end
	if not file.Exists( "maps/" .. map .. ".bsp", "GAME" ) then
		MsgN( "[HL2A] map " .. map .. " is not installed" )
		return
	end

	hook.Run( "HL2A.NewGame", prefix, n, map )
	RunConsoleCommand( "changelevel", map )
end, nil, "Start a chapter: hl2a_chapter <game> <chapter>" )
