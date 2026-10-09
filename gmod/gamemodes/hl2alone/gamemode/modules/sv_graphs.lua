--[[
	Rebuilds the AI node graphs (and optionally navmeshes) for every map,
	so they can ship in the addon (tools/build_addon.py --gmod-dir).

	The mod's .ain files are out of date for GMod, so each map shows "Node
	graph out of date. Rebuilding..." the first time it loads. GMod saves the
	rebuilt graph to garrysmod/maps/graphs/; this walks through the maps to
	do that for all of them in one go.

		hl2a_build_graphs start        node graphs
		hl2a_build_graphs start nav    node graphs + navmeshes (slow; for
		                               nextbots, HL2 NPCs only need graphs)
		hl2a_build_graphs status | stop

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

local function say( msg )
	MsgN( "[HL2A] graphs: " .. msg )
	PrintMessage( HUD_PRINTCENTER, msg )
end

local function nextMap( s )
	local map = table.remove( s.queue, 1 )
	if not map then
		store( nil )
		say( string.format( "done: %d maps (%d node graphs written, %d navmeshes)", s.total, s.graphs, s.navs ) )
		return
	end
	store( s )
	say( string.format( "%d/%d: loading %s", s.total - #s.queue, s.total, map ) )
	timer.Simple( 1, function() RunConsoleCommand( "map", map ) end )
end

local function process( s )
	local map = HL2A.MapPath()
	for _, ply in player.Iterator() do ply:GodEnable() end

	timer.Simple( GRAPH_WAIT, function()
		if file.Exists( "maps/graphs/" .. map .. ".ain", "MOD" ) then s.graphs = s.graphs + 1 end

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
		local s = { running = true, nav = args[ 2 ] == "nav", queue = maps, total = #maps, graphs = 0, navs = 0 }
		say( string.format( "building %s for %d maps; this changes maps by itself, leave it running",
			s.nav and "node graphs and navmeshes" or "node graphs", #maps ) )
		nextMap( s )
	elseif cmd == "stop" then
		store( nil )
		timer.Remove( "hl2a.graphs.nav" )
		say( "stopped" )
	else
		local s = load()
		MsgN( s and string.format( "[HL2A] graphs: %d of %d maps left", #s.queue, s.total ) or "[HL2A] graphs: not running" )
	end
end, nil, "Rebuild node graphs (and with 'start nav', navmeshes) for every map: start | start nav | stop | status" )
