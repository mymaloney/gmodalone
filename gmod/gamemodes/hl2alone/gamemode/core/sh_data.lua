--[[
	Access to the Alone mod's data files (time_info, songs, fogs, cfgs ...).

	tools/build_addon.py copies them from the original Source mod layout into
	<addon>/data_static/hl2alone/<original relative path>. Files whose extension
	isn't workshop-whitelisted (e.g. .cfg) get ".txt" appended.

	data_static is readable through the "DATA" path; the "GAME" fallback covers
	setups where the files sit in the addon root instead.
]]

local SEARCH = {
	{ prefix = "hl2alone/", path = "DATA" },
	{ prefix = "data_static/hl2alone/", path = "GAME" },
}

local function candidates( rel )
	rel = rel:gsub( "\\", "/" ):lower()
	local list = { rel }
	if not rel:EndsWith( ".txt" ) then list[ 2 ] = rel .. ".txt" end
	return list
end

function HL2A.ReadFile( rel )
	for _, name in ipairs( candidates( rel ) ) do
		for _, sp in ipairs( SEARCH ) do
			local full = sp.prefix .. name
			if file.Exists( full, sp.path ) then
				return file.Read( full, sp.path )
			end
		end
	end
	return nil
end

--- Lists files matching a wildcard inside a data directory.
-- Returns relative paths (same form ReadFile accepts).
function HL2A.FindFiles( relWildcard )
	relWildcard = relWildcard:gsub( "\\", "/" ):lower()
	local dir = relWildcard:match( "^(.*/)" ) or ""
	local seen, out = {}, {}

	for _, sp in ipairs( SEARCH ) do
		local files = file.Find( sp.prefix .. relWildcard, sp.path )
		for _, f in ipairs( files or {} ) do
			local rel = dir .. f:lower()
			if not seen[ rel ] then
				seen[ rel ] = true
				out[ #out + 1 ] = rel
			end
		end
	end

	table.sort( out )
	return out
end

--- Colour-correction lookups. The Workshop only allows .raw files under
-- materials/colorcorrection/, so build_addon.py moves the mod's
-- scripts/colorcorrection/* there; this maps the old paths (time_info,
-- convars, the maps' own color_correction entities) to wherever the file is.
function HL2A.ColorCorrectionPath( name )
	if not name or name == "" then return name end
	name = name:gsub( "\\", "/" )
	local rest = name:lower():match( "^scripts/colorcorrection/(.+)$" )
	if rest and not file.Exists( name, "GAME" ) and file.Exists( "materials/colorcorrection/" .. rest, "GAME" ) then
		return "materials/colorcorrection/" .. rest
	end
	return name
end

--- Where a converted video is (build_addon.py --videos ships them as
-- data_static/hl2alone/videos/<name>.dat, since the Workshop allows no video
-- files): returns path, search path; nil if it isn't installed
function HL2A.VideoFile( name )
	local rel = "videos/" .. name:lower() .. ".dat"
	for _, sp in ipairs( SEARCH ) do
		if file.Exists( sp.prefix .. rel, sp.path ) then return sp.prefix .. rel, sp.path end
	end
end

function HL2A.ParseVector( str )
	if not str then return nil end
	local x, y, z = str:match( "^%s*(%S+)%s+(%S+)%s+(%S+)" )
	if not z then return nil end
	return Vector( tonumber( x ) or 0, tonumber( y ) or 0, tonumber( z ) or 0 )
end

function HL2A.ParseColor( str )
	local v = HL2A.ParseVector( str )
	if not v then return nil end
	return Color( v.x, v.y, v.z )
end

--- Map name used to look up the mod's per-map data (time_info, thunder,
-- rain cfgs, snow .smf, patches). Maps in subfolders ("bonus/x",
-- "backgrounds/background01_d") are keyed by their plain name there.
function HL2A.Map()
	return ( game.GetMap():lower():gsub( "\\", "/" ):match( "([^/]+)$" ) )
end

--- Full map path under maps/ (e.g. "bonus/d1_trainstation_01_snowey")
function HL2A.MapPath()
	return ( game.GetMap():lower():gsub( "\\", "/" ) )
end

local MUSIC_EXTS = { ".wav", ".ogg", ".mp3" }

--- Music may ship as .ogg (build_addon.py --music-ogg) while the mod's data
-- and maps still name .wav (and the original even named a missing .mp3).
-- Returns the path of whichever variant exists; other sounds pass through.
-- Source's leading sound flags (")", "^", "#" ...) are kept.
function HL2A.ResolveSound( path )
	if not isstring( path ) then return path end
	local flags, rest = path:match( "^([%)%^%*#@<>!%?&~%+%$]*)(.*)$" )
	local p = rest:gsub( "\\", "/" ):lower() -- build_addon.py lowercases every file
	if not p:StartWith( "music/" ) or file.Exists( "sound/" .. p, "GAME" ) then return path end

	local base = p:gsub( "%.%w+$", "" )
	for _, ext in ipairs( MUSIC_EXTS ) do
		if file.Exists( "sound/" .. base .. ext, "GAME" ) then return flags .. base .. ext end
	end
	return path
end

--- Text shown to the player with the mod's "snowey" spelled "snowy".
-- Only for display: map and folder names keep the original spelling.
function HL2A.Spell( text )
	if not isstring( text ) then return text end
	return ( text:gsub( "([Ss])nowey", "%1nowy" ):gsub( "SNOWEY", "SNOWY" ) )
end
