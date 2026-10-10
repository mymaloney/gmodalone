--[[
	Rebuilds the AI node graphs (and optionally navmeshes) for every map,
	so they can ship in the addon (tools/build_addon.py --gmod-dir).

	The mod's .ain files are out of date for GMod, so each map shows "Node
	graph out of date. Rebuilding..." the first time it loads. GMod saves the
	rebuilt graph to garrysmod/maps/graphs/; this walks through the maps to
	do that for all of them in one go.

		hl2a_build_graphs start [nav] [cubemaps]
		    node graphs, plus navmeshes (slow; for nextbots, HL2 NPCs only
		    need graphs) and/or cubemaps for maps that are missing them
		hl2a_build_graphs status | stop
		hl2a_check_cubemaps            list maps with missing cubemaps

	Cubemaps: a map whose BSP has env_cubemap positions but no cubemap
	textures packed in it shows default reflections. "buildcubemaps" renders
	and packs them, and GMod saves the result as garrysmod/maps/<map>.bsp
	(--gmod-dir --cubemaps ships those). Post-processing, weather and the
	HUD are switched off while it captures.

	Maps: every maps/*_d.bsp plus maps/bonus/ and maps/bonus_maps/. The queue
	is saved in data/hl2alone/graphbuild.json, so it carries on across the
	map changes and can be resumed.
]]

local STATE = "hl2alone/graphbuild.json"
local GRAPH_WAIT = 6      -- seconds after load for the graph to be built and saved
local NAV_TIMEOUT = 600   -- give up on a navmesh after this long

local function load() return util.JSONToTable( file.Read( STATE, "DATA" ) or "" ) end
local function store( s )
	file.CreateDir( "hl2alone" )
	if s then file.Write( STATE, util.TableToJSON( s ) ) else file.Delete( STATE ) end
end

local function modMaps()
	local out = {}
	for _, f in ipairs( file.Find( "maps/*.bsp", "GAME" ) ) do
		local name = f:gsub( "%.bsp$", "" ):lower()
		if name:match( "_d$" ) then out[ #out + 1 ] = name end
	end
	for _, dir in ipairs( { "bonus", "bonus_maps" } ) do
		for _, f in ipairs( file.Find( "maps/" .. dir .. "/*.bsp", "GAME" ) ) do
			out[ #out + 1 ] = dir .. "/" .. f:gsub( "%.bsp$", "" ):lower()
		end
	end
	table.sort( out )
	return out
end

HL2A.ModMaps = modMaps -- also walked by sv_smoketest.lua

--- Cubemap positions in the BSP, and whether cubemap textures are packed in it
function HL2A.CubemapState( map )
	local f = file.Open( "maps/" .. map .. ".bsp", "rb", "GAME" )
	if not f then return nil end
	local function lump( i )
		f:Seek( 8 + i * 16 )
		return f:ReadLong(), f:ReadLong()
	end
	local _, cubeLen = lump( 42 )     -- LUMP_CUBEMAPS, 16 bytes each
	local pakOfs, pakLen = lump( 40 ) -- LUMP_PAKFILE (zip)
	local packed = false
	if pakLen > 0 then
		f:Seek( pakOfs )
		local pak = ( f:Read( pakLen ) or "" ):lower()
		local base = map:match( "([^/]+)$" ):lower()
		packed = pak:find( "materials/maps/", 1, true ) ~= nil and pak:find( base .. "/c", 1, true ) ~= nil
	end
	f:Close()
	return math.floor( cubeLen / 16 ), packed
end

local function needsCubemaps( map )
	local count, packed = HL2A.CubemapState( map )
	return count and count > 0 and not packed
end

local function say( msg )
	MsgN( "[HL2A] graphs: " .. msg )
	PrintMessage( HUD_PRINTCENTER, msg )
end

local function nextMap( s )
	local map = table.remove( s.queue, 1 )
	if not map then
		store( nil )
		say( string.format( "done: %d maps (%d node graphs written, %d maps' cubemaps, %d navmeshes)",
			s.total, s.graphs, s.cubemapsBuilt or 0, s.navs ) )
		return
	end
	store( s )
	say( string.format( "%d/%d: loading %s", s.total - #s.queue, s.total, map ) )
	timer.Simple( 1, function() RunConsoleCommand( "map", map ) end )
end

local function navStep( s, map )
	if not s.nav or file.Exists( "maps/" .. map .. ".nav", "MOD" ) then return nextMap( s ) end

	-- Navmesh: seed from the spawn points and the player, don't restart the map after
	RunConsoleCommand( "nav_restart_after_analysis", "0" )
	for _, ent in ipairs( ents.FindByClass( "info_player_start" ) ) do navmesh.AddWalkableSeed( ent:GetPos(), vector_up ) end
	for _, ply in player.Iterator() do navmesh.AddWalkableSeed( ply:GetPos(), vector_up ) end
	navmesh.BeginGeneration()
	local started = CurTime()
	timer.Create( "hl2a.graphs.nav", 2, 0, function()
		if navmesh.IsGenerating() and CurTime() - started < NAV_TIMEOUT then return end
		timer.Remove( "hl2a.graphs.nav" )
		if not navmesh.IsGenerating() then
			navmesh.Save()
			if file.Exists( "maps/" .. map .. ".nav", "MOD" ) then s.navs = s.navs + 1 end
		else
			MsgN( "[HL2A] graphs: navmesh for " .. map .. " timed out" )
		end
		nextMap( s )
	end )
end

local CUBEMAP_TIMEOUT = 180

local function cubemapStep( s, map )
	s.cubemapsTried = s.cubemapsTried or {}
	if not s.cubemaps or s.cubemapsTried[ map ] or file.Exists( "maps/" .. map .. ".bsp", "MOD" ) or not needsCubemaps( map ) then
		return navStep( s, map )
	end
	s.cubemapsTried[ map ] = true
	store( s ) -- buildcubemaps may reload the map; this map won't be tried again

	say( "building cubemaps for " .. map )
	SetGlobal2Bool( "hl2a.capture", true ) -- clients: no post-processing, weather or HUD
	RunConsoleCommand( "sv_cheats", "1" )
	for _, ply in player.Iterator() do
		if ply:FlashlightIsOn() then ply:Flashlight( false ) end
		ply:SetNW2Bool( "hl2a.flashlight", false )
	end
	timer.Simple( 1, function()
		for _, ply in player.Iterator() do ply:ConCommand( "mat_specular 0; buildcubemaps; mat_specular 1" ) end
	end )

	local started = CurTime()
	timer.Create( "hl2a.graphs.cubemaps", 2, 0, function()
		local done = file.Exists( "maps/" .. map .. ".bsp", "MOD" )
		if not done and CurTime() - started < CUBEMAP_TIMEOUT then return end
		timer.Remove( "hl2a.graphs.cubemaps" )
		SetGlobal2Bool( "hl2a.capture", false )
		RunConsoleCommand( "sv_cheats", "0" )
		if done then s.cubemapsBuilt = ( s.cubemapsBuilt or 0 ) + 1
		else MsgN( "[HL2A] graphs: no rebuilt " .. map .. ".bsp appeared in garrysmod/maps/" ) end
		navStep( s, map )
	end )
end

local function process( s )
	local map = HL2A.MapPath()
	-- In case buildcubemaps reloaded the map mid-capture
	SetGlobal2Bool( "hl2a.capture", false )
	RunConsoleCommand( "sv_cheats", "0" )
	for _, ply in player.Iterator() do ply:GodEnable() end

	timer.Simple( GRAPH_WAIT, function()
		if file.Exists( "maps/graphs/" .. map .. ".ain", "MOD" ) then s.graphs = s.graphs + 1 end
		cubemapStep( s, map )
	end )
end

hook.Add( "InitPostEntity", "hl2a.graphs", function()
	local s = load()
	if not s or not s.running then return end
	-- Wait for the player before continuing (navmesh seeds, god mode)
	timer.Simple( 2, function() process( s ) end )
end )

concommand.Add( "hl2a_build_graphs", function( ply, _, args )
	if IsValid( ply ) and not ply:IsListenServerHost() then return end
	local cmd = ( args[ 1 ] or "status" ):lower()

	if cmd == "start" then
		local maps = modMaps()
		local flags = {}
		for i = 2, #args do flags[ args[ i ]:lower() ] = true end
		local s = { running = true, nav = flags.nav, cubemaps = flags.cubemaps, queue = maps, total = #maps, graphs = 0, navs = 0, cubemapsBuilt = 0 }
		local what = { "node graphs" }
		if s.cubemaps then what[ #what + 1 ] = "missing cubemaps" end
		if s.nav then what[ #what + 1 ] = "navmeshes" end
		say( string.format( "building %s for %d maps; this changes maps by itself, leave it running",
			table.concat( what, ", " ), #maps ) )
		nextMap( s )
	elseif cmd == "stop" then
		store( nil )
		timer.Remove( "hl2a.graphs.nav" )
		say( "stopped" )
	else
		local s = load()
		MsgN( s and string.format( "[HL2A] graphs: %d of %d maps left", #s.queue, s.total ) or "[HL2A] graphs: not running" )
	end
end, nil, "Rebuild node graphs for every map, plus 'nav' navmeshes and/or 'cubemaps': start [nav] [cubemaps] | stop | status" )

concommand.Add( "hl2a_check_cubemaps", function( ply )
	if IsValid( ply ) and not ply:IsListenServerHost() then return end
	local missing, ok, none = {}, 0, 0
	for _, map in ipairs( modMaps() ) do
		local count, packed = HL2A.CubemapState( map )
		if count and count > 0 and not packed then missing[ #missing + 1 ] = string.format( "%s (%d)", map, count )
		elseif count and count > 0 then ok = ok + 1 else none = none + 1 end
	end
	MsgN( string.format( "[HL2A] cubemaps: %d maps fine, %d without env_cubemaps, %d missing:", ok, none, #missing ) )
	for _, m in ipairs( missing ) do MsgN( "  " .. m ) end
end, nil, "List maps whose cubemaps were never built" )
