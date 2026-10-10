--[[
	Snow-covered map variants (recovered from client.dll).

	When the map's time_info weather block has "ShowSnowOnMaps" "1" (or,
	with amod_weather_override 1, amod_weather_snow_show_on_maps is on), the
	original applied maps/snow_materials/<map>.smf: per-material variable and
	flag changes that re-texture the map with snow.

	.smf format:
		"<material name, * and ? wildcards>"
		{
			"<any>" { "Var" "$basetexture"  "Value" "..."  "Type" "TYPE_SET_TEXTURE"  "Group" "" }
			"<any>" { "Flag" "MATERIAL_VAR_..."  "State" "1"  "Group" "" }
		}
		Type: TYPE_SET_INT, TYPE_SET_FLOAT, TYPE_SET_STRING, TYPE_SET_TEXTURE, TYPE_SET_ARRAY

	GMod keeps material changes for the whole session, so every original
	value is saved and restored when the map unloads.
]]

local CV = HL2A.ConVars
local KV = HL2A.KV

-- MaterialVarFlags_t (SDK 2013 imaterial.h)
local FLAGS = {
	DEBUG = 0, NO_DEBUG_OVERRIDE = 1, NO_DRAW = 2, USE_IN_FILLRATE_MODE = 3, VERTEXCOLOR = 4,
	VERTEXALPHA = 5, SELFILLUM = 6, ADDITIVE = 7, ALPHATEST = 8, MULTIPASS = 9, ZNEARER = 10,
	MODEL = 11, FLAT = 12, NOCULL = 13, NOFOG = 14, IGNOREZ = 15, DECAL = 16, ENVMAPSPHERE = 17,
	NOALPHAMOD = 18, ENVMAPCAMERASPACE = 19, BASEALPHAENVMAPMASK = 20, TRANSLUCENT = 21,
	NORMALMAPALPHAENVMAPMASK = 22, NEEDS_SOFTWARE_SKINNING = 23, OPAQUETEXTURE = 24,
	ENVMAPMODE = 25, SUPPRESS_DECALS = 26, HALFLAMBERT = 27, WIREFRAME = 28,
	ALLOWALPHATOCOVERAGE = 29, IGNORE_ALPHA_MODULATION = 30, VERTEXFOG = 31,
}

local function flagBit( name )
	if tonumber( name ) then return tonumber( name ) end
	name = name:upper():gsub( "^%$", "" ):gsub( "^MATERIAL_VAR_", "" )
	local b = FLAGS[ name ]
	return b and bit.lshift( 1, b ) or nil
end

-- Material names may be written as .vmt paths ("materials/nature/x.vmt")
local function normalizeName( name )
	name = name:lower():gsub( "\\", "/" )
	return ( name:gsub( "^materials/", "" ):gsub( "%.vmt$", "" ) )
end

-- "*" / "?" wildcard -> Lua pattern
local function globToPattern( glob )
	local p = normalizeName( glob ):gsub( "[%^%$%(%)%%%.%[%]%+%-]", "%%%0" )
	return "^" .. p:gsub( "%*", ".*" ):gsub( "%?", "." ) .. "$"
end

--- Material names used by the map's brushes (BSP lump 43, TEXDATA_STRING_DATA)
local function mapMaterials( map )
	local f = file.Open( "maps/" .. map .. ".bsp", "rb", "GAME" )
	if not f then return {} end

	f:Seek( 8 + 43 * 16 )
	local ofs, len = f:ReadLong(), f:ReadLong()
	f:Seek( ofs )
	local data = f:Read( len ) or ""
	f:Close()

	if data:sub( 1, 4 ) == "LZMA" then
		MsgN( "[HL2A] snow: " .. map .. " has a compressed material table, skipping" )
		return {}
	end

	local out = {}
	for name in data:gmatch( "[^%z]+" ) do out[ #out + 1 ] = name:lower():gsub( "\\", "/" ) end
	return out
end

-- Cubemap / displacement patches are "maps/<map>/<material>_x_y_z" or "..._wvt_patch"
local function unpatched( name, map )
	local base = name:match( "^maps/" .. map:gsub( "%p", "%%%0" ) .. "/(.+)$" )
	if not base then return name end
	return ( base:gsub( "_wvt_patch$", "" ):gsub( "_%-?%d+_%-?%d+_%-?%d+$", "" ) )
end

local saved = {} -- { mat, kind, var, original }

local function save( mat, kind, var, getter )
	saved[ #saved + 1 ] = { mat = mat, kind = kind, var = var, value = getter() }
end

local function applyVar( mat, e )
	local var, value, kind = e.var, e.value or "", ( e.type or "" ):upper()

	if kind == "TYPE_SET_TEXTURE" then
		save( mat, "texture", var, function() return mat:GetTexture( var ) end )
		mat:SetTexture( var, value )
	elseif kind == "TYPE_SET_FLOAT" then
		save( mat, "float", var, function() return mat:GetFloat( var ) end )
		mat:SetFloat( var, tonumber( value ) or 0 )
	elseif kind == "TYPE_SET_INT" then
		save( mat, "int", var, function() return mat:GetInt( var ) end )
		mat:SetInt( var, tonumber( value ) or 0 )
	elseif kind == "TYPE_SET_ARRAY" then
		save( mat, "vector", var, function() return mat:GetVector( var ) end )
		mat:SetVector( var, Vector( value:gsub( "[%[%]{}]", "" ) ) )
	else -- TYPE_SET_STRING and anything unrecognised
		save( mat, "string", var, function() return mat:GetString( var ) end )
		mat:SetString( var, value )
		mat:Recompute()
	end
end

local function applyFlag( mat, e )
	local b = flagBit( e.flag )
	if not b then MsgN( "[HL2A] snow: unknown material flag '" .. e.flag .. "'" ) return end
	save( mat, "int", "$flags", function() return mat:GetInt( "$flags" ) end )
	local flags = mat:GetInt( "$flags" ) or 0
	mat:SetInt( "$flags", tobool( e.state ) and bit.bor( flags, b ) or bit.band( flags, bit.bnot( b ) ) )
end

local function restore()
	for i = #saved, 1, -1 do
		local s = saved[ i ]
		if s.value ~= nil then
			if s.kind == "texture" then s.mat:SetTexture( s.var, s.value )
			elseif s.kind == "float" then s.mat:SetFloat( s.var, s.value )
			elseif s.kind == "int" then s.mat:SetInt( s.var, s.value )
			elseif s.kind == "vector" then s.mat:SetVector( s.var, s.value )
			else s.mat:SetString( s.var, s.value ) s.mat:Recompute() end
		end
	end
	saved = {}
end

-- Entries of a material block, or nil if the block holds no Var/Flag entries
local function entriesOf( block )
	local entries
	for _, e in ipairs( block ) do
		if istable( e.value ) then
			-- Entry blocks are themselves named "Var"/"Flag", so only a plain
			-- string value counts; a nested block means we're a level too high
			local t = KV.ToTable( e.value )
			if isstring( t.flag ) then
				entries = entries or {}
				entries[ #entries + 1 ] = { flag = t.flag, state = t.state }
			elseif isstring( t.var ) then
				entries = entries or {}
				entries[ #entries + 1 ] = { var = t.var, value = t.value, type = t.type }
			end
		end
	end
	return entries
end

--- Rules ({ name, pattern, entries }) from .smf text. The DLL loads the file
-- with KeyValues::LoadFromFile, so material blocks normally sit inside one
-- root block; blocks without Var/Flag entries are searched one level deeper.
function HL2A.ParseSnowRules( text )
	local rules = {}
	local function walk( block, depth )
		for _, m in ipairs( block ) do
			if istable( m.value ) then
				local entries = entriesOf( m.value )
				if entries then
					rules[ #rules + 1 ] = { name = m.key, pattern = globToPattern( m.key ), entries = entries }
				elseif depth < 3 then
					walk( m.value, depth + 1 )
				end
			end
		end
	end
	walk( KV.Parse( text ), 0 )
	return rules
end

local function wanted()
	if CV.amod_weather_override:GetBool() then return CV.amod_weather_snow_show_on_maps:GetBool() end
	return HL2A.TimeInfo.GetSubTable( "weather" ).showsnowonmaps == "1"
end

-- The Workshop doesn't allow .smf files, so build_addon.py ships them as
-- data_static/hl2alone/maps/snow_materials/<map>.smf.txt
function HL2A.ReadSnowFile( map )
	return HL2A.ReadFile( "maps/snow_materials/" .. map .. ".smf" ) or file.Read( "maps/snow_materials/" .. map .. ".smf", "GAME" )
end

function HL2A.ApplySnowMaterials()
	restore()
	if not wanted() then return end

	local map = HL2A.Map()
	local text = HL2A.ReadSnowFile( map )
	if not text then
		MsgN( "[HL2A] snow: no maps/snow_materials/" .. map .. ".smf" )
		return
	end

	local rules = HL2A.ParseSnowRules( text )

	local changed = 0
	for _, name in ipairs( mapMaterials( HL2A.MapPath() ) ) do
		local base = unpatched( name, HL2A.MapPath() )
		for _, r in ipairs( rules ) do
			if base:find( r.pattern ) or name:find( r.pattern ) then
				local mat = Material( name )
				if not mat:IsError() then
					for _, e in ipairs( r.entries ) do
						if e.flag then applyFlag( mat, e ) else applyVar( mat, e ) end
					end
					changed = changed + 1
				end
			end
		end
	end

	MsgN( string.format( "[HL2A] snow: %d rules, %d materials changed", #rules, changed ) )
end

hook.Add( "InitPostEntity", "hl2a.snowmaterials", function() HL2A.ApplySnowMaterials() end )

-- Shows what the .smf contains and how it matches this map's materials
concommand.Add( "hl2a_snow_debug", function()
	local map = HL2A.Map()
	local text = HL2A.ReadSnowFile( map )
	MsgN( "[HL2A] snow debug for " .. map .. ": snow wanted = " .. tostring( wanted() ) )
	if not text then MsgN( "  no .smf found" ) return end
	MsgN( "  .smf starts with: " .. text:sub( 1, 300 ):gsub( "%s+", " " ) )

	local mats = mapMaterials( HL2A.MapPath() )
	MsgN( "  map uses " .. #mats .. " materials, e.g. " .. table.concat( mats, ", ", 1, math.min( 5, #mats ) ) )

	local rules = HL2A.ParseSnowRules( text )
	MsgN( "  " .. #rules .. " rules:" )
	for i, r in ipairs( rules ) do
		if i > 15 then MsgN( "  ..." ) break end
		local hits = 0
		for _, name in ipairs( mats ) do
			if unpatched( name, HL2A.MapPath() ):find( r.pattern ) or name:find( r.pattern ) then hits = hits + 1 end
		end
		MsgN( string.format( "    %-40s %d entries, matches %d", r.name, #r.entries, hits ) )
	end
end )
hook.Add( "ShutDown", "hl2a.snowmaterials", function() restore() end )

concommand.Add( "amod_weather_snow_reload", HL2A.ApplySnowMaterials, nil, "Reloads the .smf for the current map" )
