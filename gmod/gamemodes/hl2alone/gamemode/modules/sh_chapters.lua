--[[
	Chapter data for the chapter select panel and hl2a_chapter.

	Games come from resource/gamelist.txt plus any resource/games/*.txt
	(same format, see resource/games/README):
		"Display Name" { "Prefix" "HL2" }
	Chapters are cfg/<prefix>/chapter1.cfg, chapter2.cfg ... ("map <name>").
	Titles are the localization tokens <PREFIX>_Chapter<N>_Title.
]]

local KV = HL2A.KV

function HL2A.GetGames()
	local files = { "resource/gamelist.txt" }
	for _, f in ipairs( HL2A.FindFiles( "resource/games/*.txt" ) ) do files[ #files + 1 ] = f end

	local games, seen = {}, {}
	for _, f in ipairs( files ) do
		for _, root in ipairs( KV.ParseFile( f ) or {} ) do
			for _, g in ipairs( istable( root.value ) and root.value or {} ) do
				local prefix = istable( g.value ) and ( KV.Get( g.value, "Prefix" ) or g.key )
				if prefix and not seen[ prefix:lower() ] then
					seen[ prefix:lower() ] = true
					games[ #games + 1 ] = {
						name = g.key,
						prefix = prefix,            -- original case, for title tokens
						dir = prefix:lower(),       -- cfg/ and materials/ folder
						default = KV.Get( g.value, "Default" ) == "1",
					}
				end
			end
		end
	end
	return games
end

-- Placeholder map for chapters whose cfg runs "map_random"
HL2A.RANDOM_MAP = "*random*"

function HL2A.GetChapterMap( prefix, n )
	local cfg = HL2A.ReadFile( "cfg/" .. prefix:lower() .. "/chapter" .. n .. ".cfg" )
	if not cfg then return nil end
	if cfg:match( "^%s*map_random" ) then return HL2A.RANDOM_MAP end
	return cfg:match( "map%s+([%w_%-/]+)" ) -- may be in a subfolder: "bonus/x"
end

--- Whether a chapter's map can be loaded.
function HL2A.IsMapInstalled( map )
	return map == HL2A.RANDOM_MAP or file.Exists( "maps/" .. map .. ".bsp", "GAME" )
end

--- Ordered list of { n, map, title } for a game prefix.
function HL2A.GetChapters( prefix )
	local list = {}
	for n = 1, 200 do
		local map = HL2A.GetChapterMap( prefix, n )
		if not map then break end
		list[ n ] = { n = n, map = map, title = "#" .. prefix .. "_Chapter" .. n .. "_Title" }
	end
	return list
end

--- time_info themes: sub-folders of resource/time_info ("" = default).
function HL2A.GetThemes()
	local themes, seen = { "" }, {}
	for _, sp in ipairs( { { "hl2alone/resource/time_info/*", "DATA" }, { "data_static/hl2alone/resource/time_info/*", "GAME" } } ) do
		local _, dirs = file.Find( sp[ 1 ], sp[ 2 ] )
		for _, d in ipairs( dirs or {} ) do
			d = d:lower()
			if not seen[ d ] and not d:StartWith( "_" ) then
				seen[ d ] = true
				themes[ #themes + 1 ] = d
			end
		end
	end
	return themes
end

-- The maps tell the player to press TAB to toggle the screen filter. That
-- filter isn't ported and TAB opens GMod's scoreboard, so point them at F1.
HL2A.F1_HINT = "Press F1 to open chapter select and options"

--- Replacement for a map message, or nil to keep it.
function HL2A.FixHintText( text )
	if not isstring( text ) then return nil end
	local t = text:lower()
	if t:find( "filter", 1, true ) and ( t:find( "%f[%w]tab%f[%W]" ) or t:find( "amod_togglefilter", 1, true ) ) then
		return HL2A.F1_HINT
	end
	return nil
end
