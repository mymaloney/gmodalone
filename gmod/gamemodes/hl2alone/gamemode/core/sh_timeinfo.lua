--[[
	Per-map atmosphere data from resource/time_info/*.txt.

	Layout of one map entry:
		"<map>"
		{
			"Night" / "Day"
			{
				"DefaultNightSky" / "DefaultDaySky"
				"FilterName", "FilterIntensity"
				"fog"     { fog_* }
				"sun"     { env_sun keyvalues }
				"weather" { WeatherEnabled, WeatherType, RainIntensity ... }
				"FogCubeTriggers" { "<name>" { mins, maxs, Variables { ... } } }
				"clouds", "horizon", "CloudsColor"  -- engine features with no GMod equivalent yet
			}
		}

	Also loads resource/thunder_locations.txt. Only "Night" blocks are used;
	daytime (and resource/amod_city_fogs.txt, its fog overrides) isn't ported.
]]

local KV = HL2A.KV

HL2A.TimeInfo = HL2A.TimeInfo or {}
local TI = HL2A.TimeInfo

--- Where the Map Properties editor keeps this theme's saved maps
function TI.OverrideDir()
	local theme = HL2A.ConVars.hl2a_timeinfo_theme:GetString()
	return "hl2alone/map_properties/" .. ( theme ~= "" and theme:gsub( "[^%w_%- ]", "_" ) or "default" ) .. "/"
end

--- Replaces a map's Night block (editor preview / saved properties)
function TI.SetNightBlock( map, night )
	map = map:lower()
	local block = TI.Maps[ map ]
	if not block then
		block = {}
		TI.Maps[ map ] = block
	end
	KV.Set( block, "Night", night )
end

function TI.Load()
	TI.Maps = {}
	TI.Thunder = {}
	TI.TriggerCache = setmetatable( {}, { __mode = "k" } )

	local theme = HL2A.ConVars.hl2a_timeinfo_theme:GetString()
	local dir = "resource/time_info/" .. ( theme ~= "" and ( theme .. "/" ) or "" )

	for _, rel in ipairs( HL2A.FindFiles( dir .. "*.txt" ) ) do
		for _, game in ipairs( KV.ParseFile( rel ) or {} ) do
			if istable( game.value ) then
				for _, m in ipairs( game.value ) do
					if istable( m.value ) then TI.Maps[ m.key:lower() ] = m.value end
				end
			end
		end
	end

	-- Map Properties editor saves (cl_mapproperties.lua) replace a map's
	-- Night block: data/hl2alone/map_properties/<theme or default>/<map>.txt
	for _, f in ipairs( file.Find( TI.OverrideDir() .. "*.txt", "DATA" ) ) do
		local root = KV.Parse( file.Read( TI.OverrideDir() .. f, "DATA" ) or "" )
		local m = root and root[ 1 ]
		local night = m and istable( m.value ) and KV.Get( m.value, "Night" )
		if istable( night ) then TI.SetNightBlock( m.key, night ) end
	end

	for _, root in ipairs( KV.ParseFile( "resource/thunder_locations.txt" ) or {} ) do
		for _, m in ipairs( istable( root.value ) and root.value or {} ) do
			if istable( m.value ) then
				local list = {}
				for _, o in ipairs( KV.GetAll( m.value, "origin" ) ) do
					list[ #list + 1 ] = HL2A.ParseVector( o )
				end
				TI.Thunder[ m.key:lower() ] = list
			end
		end
	end

	MsgN( string.format( "[HL2A] time_info: %d maps (theme '%s')", table.Count( TI.Maps ), theme ) )
end

--- The current map's "Night" block, or nil. ("Day" blocks are ignored:
-- daytime isn't ported.)
function TI.GetCurrentBlock()
	local mapBlock = TI.Maps and TI.Maps[ HL2A.Map() ]
	if not mapBlock then return nil end
	return KV.Get( mapBlock, "Night" )
end

local EMPTY = {}

--- Flattened sub-block ("fog", "sun", "weather" ...) of the current block.
-- Cached; treat the result as read-only.
function TI.GetSubTable( name )
	local block = TI.GetCurrentBlock()
	if not block then return EMPTY end

	TI.SubCache = TI.SubCache or setmetatable( {}, { __mode = "k" } )
	local perBlock = TI.SubCache[ block ] or {}
	TI.SubCache[ block ] = perBlock

	local key = name:lower()
	if not perBlock[ key ] then perBlock[ key ] = KV.ToTable( KV.Get( block, name ) ) end
	return perBlock[ key ]
end

local function triggersFor( block )
	local cached = TI.TriggerCache[ block ]
	if cached then return cached end

	cached = {}
	for _, trig in ipairs( KV.Get( block, "FogCubeTriggers" ) or {} ) do
		if istable( trig.value ) then
			local mins = HL2A.ParseVector( KV.Get( trig.value, "mins" ) )
			local maxs = HL2A.ParseVector( KV.Get( trig.value, "maxs" ) )
			if mins and maxs then
				OrderVectors( mins, maxs )
				cached[ #cached + 1 ] = {
					name = trig.key, mins = mins, maxs = maxs,
					vars = KV.ToTable( KV.Get( trig.value, "Variables" ) ),
				}
			end
		end
	end

	TI.TriggerCache[ block ] = cached
	return cached
end

--- Merged "Variables" of every FogCubeTrigger containing pos, or nil.
function TI.GetTriggerVars( pos )
	local block = TI.GetCurrentBlock()
	if not block then return nil end

	local vars
	for _, trig in ipairs( triggersFor( block ) ) do
		if pos:WithinAABox( trig.mins, trig.maxs ) then
			vars = vars or {}
			table.Merge( vars, trig.vars )
		end
	end
	return vars
end

function TI.GetThunderLocations()
	return TI.Thunder and TI.Thunder[ HL2A.Map() ] or {}
end

cvars.AddChangeCallback( "hl2a_timeinfo_theme", function() TI.Load() end, "hl2a.timeinfo" )
