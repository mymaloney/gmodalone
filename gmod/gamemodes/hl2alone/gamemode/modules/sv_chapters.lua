--[[
	Starting chapters: the hl2a_chapter command and requests from the
	chapter select panel (cl_chapters.lua). Data lives in sh_chapters.lua.

	Usage: hl2a_chapter hl2 5
]]

util.AddNetworkString( "hl2a.loadchapter" )

-- The mod's map_random: any of its playable maps (the *_d ones, minus menu backgrounds)
local function randomMap()
	local maps = {}
	for _, f in ipairs( file.Find( "maps/*_d.bsp", "GAME" ) ) do
		local m = f:sub( 1, -5 ):lower()
		if not m:StartWith( "background" ) and not m:StartWith( "credits" ) then maps[ #maps + 1 ] = m end
	end
	if #maps == 0 then return nil end
	return maps[ math.random( #maps ) ]
end

function HL2A.StartChapter( prefix, n )
	local map = HL2A.GetChapterMap( prefix, n )
	if not map then MsgN( "[HL2A] no chapter " .. n .. " for " .. prefix ) return false end
	if map == HL2A.RANDOM_MAP then
		map = randomMap()
		if not map then MsgN( "[HL2A] no maps found" ) return false end
	end
	if not HL2A.IsMapInstalled( map ) then
		MsgN( "[HL2A] map " .. map .. " is not installed" )
		return false
	end

	hook.Run( "HL2A.NewGame", prefix, n, map )
	RunConsoleCommand( "changelevel", map )
	return true
end

concommand.Add( "hl2a_chapter", function( ply, _, args )
	if IsValid( ply ) and not ply:IsListenServerHost() then return end

	local prefix, n = args[ 1 ], tonumber( args[ 2 ] )
	if not prefix or not n then
		local names = {}
		for _, g in ipairs( HL2A.GetGames() ) do names[ #names + 1 ] = "\"" .. g.dir .. "\"" end
		MsgN( "usage: hl2a_chapter <game> <chapter>   games: " .. table.concat( names, ", " ) )
		return
	end

	HL2A.StartChapter( prefix, n )
end, nil, "Start a chapter: hl2a_chapter <game> <chapter>" )

net.Receive( "hl2a.loadchapter", function( _, ply )
	if not ply:IsListenServerHost() then return end

	local prefix, n, theme = net.ReadString(), net.ReadUInt( 8 ), net.ReadString()
	if theme ~= HL2A.ConVars.hl2a_timeinfo_theme:GetString() then
		RunConsoleCommand( "hl2a_timeinfo_theme", theme )
	end
	HL2A.StartChapter( prefix, n )
end )

-- F1 opens chapter select
function GM:ShowHelp( ply )
	ply:ConCommand( "togglenewgamepanel" )
end
