--[[
	Map smoke test: loads every map in turn, lets each run for a while, and
	writes a report of what's broken, so problems are found without playing
	the whole campaign.

		hl2a_smoketest start [seconds=20] [filter]   e.g. start 20 d1_canals
		hl2a_smoketest stop | status | resume

	For each map it records:
	  * Lua errors (server and client) from the gamemode, with where they came from
	  * models that don't exist (util.IsValidModel), ambient_generic sounds that don't
	  * entity classes in the map that GMod can't create
	  * map-fired commands nobody handles (engine/GMod may refuse them)
	  * a screen left faded out ("stay out" env_fade never lifted)
	  * checkpoints (autosave entities, level-start checkpoint) and soundscapes tracked
	  * client frame time and the gamemode's most expensive hooks there
	The report is data/hl2alone/smoketest_report.txt, rewritten after every
	map; progress survives the map changes and a crash (resume marks the map
	it was on as having crashed or hung).
]]

local STATE = "hl2alone/smoketest.json"
local REPORT = "hl2alone/smoketest_report.txt"

if CLIENT then
	-- Client errors and frame time go to the server's report
	local frames, frameTime = 0, 0
	hook.Add( "Think", "hl2a.smoketest", function()
		if not GetGlobal2Bool( "hl2a.smoketest", false ) then return end
		frames, frameTime = frames + 1, frameTime + FrameTime()
	end )

	local sent = 0
	HL2A.OnError.smoketest = function( e )
		if not GetGlobal2Bool( "hl2a.smoketest", false ) or sent >= 10 then return end
		sent = sent + 1
		net.Start( "hl2a.smoketest" )
			net.WriteString( "error" )
			net.WriteString( e.where .. ": " .. e.message )
		net.SendToServer()
	end

	net.Receive( "hl2a.smoketest", function()
		net.Start( "hl2a.smoketest" )
			net.WriteString( "frames" )
			net.WriteString( string.format( "%.1f", frames > 0 and frameTime / frames * 1000 or 0 ) )
		net.SendToServer()
	end )
	return
end

util.AddNetworkString( "hl2a.smoketest" )

local function load() return util.JSONToTable( file.Read( STATE, "DATA" ) or "" ) end
local function store( s )
	file.CreateDir( "hl2alone" )
	if s then file.Write( STATE, util.TableToJSON( s ) ) else file.Delete( STATE ) end
end

-- Per-map findings
local found

local function reset()
	found = { errors = {}, commands = {}, faded = false, frameMs = nil }
end
reset()

HL2A.OnError.smoketest = function( e )
	if found and #found.errors < 20 then found.errors[ #found.errors + 1 ] = "server " .. e.where .. ": " .. e.message end
end

net.Receive( "hl2a.smoketest", function( _, ply )
	local kind, value = net.ReadString(), net.ReadString()
	if not found then return end
	if kind == "error" and #found.errors < 20 then
		found.errors[ #found.errors + 1 ] = "client " .. value
	elseif kind == "frames" then
		found.frameMs = tonumber( value )
	end
end )

-- Commands the engine runs anyway / known to be harmless
local NATIVE = { "r_", "mat_", "fog_", "snd_", "cl_", "sv_", "play", "playgamesound", "echo", "wait",
	"stopsound", "stopsoundscape", "dsp_", "volume", "hud_", "crosshair", "fov", "impulse", "ent_" }
hook.Add( "HL2A_MapCommandPassthrough", "hl2a.smoketest", function( name, cmd )
	if not found then return end
	name = name:lower()
	for _, p in ipairs( NATIVE ) do if name:StartWith( p ) then return end end
	if concommand.GetTable()[ name ] then return end
	found.commands[ cmd ] = true
end )

-- A fade that holds the screen dark until something lifts it
hook.Add( "AcceptInput", "hl2a.smoketest", function( ent, input )
	if not found or ent:GetClass() ~= "env_fade" or input:lower() ~= "fade" then return end
	local flags = ent:GetSpawnFlags()
	local stayOut = bit.band( flags, 8 ) ~= 0
	local fadeIn = bit.band( flags, 1 ) ~= 0
	if stayOut and not fadeIn then found.faded = ent:GetName() ~= "" and ent:GetName() or "env_fade"
	elseif fadeIn then found.faded = false end
end )
hook.Add( "HL2A_ScreenFadeIn", "hl2a.smoketest", function() if found then found.faded = false end end )

-- The map's entity classes, from its entity lump
local function mapClasses( map )
	local f = file.Open( "maps/" .. map .. ".bsp", "rb", "GAME" )
	if not f then return {} end
	f:Seek( 8 )
	local ofs, len = f:ReadLong(), f:ReadLong()
	f:Seek( ofs )
	local lump = f:Read( len ) or ""
	f:Close()
	if lump:sub( 1, 4 ) == "LZMA" then
		-- Valve's header -> the plain LZMA one util.Decompress reads (props + 64-bit size)
		local b = { lump:byte( 5, 8 ) }
		local actual = b[ 1 ] + b[ 2 ] * 256 + b[ 3 ] * 65536 + b[ 4 ] * 16777216
		local size = string.char( b[ 1 ], b[ 2 ], b[ 3 ], b[ 4 ], 0, 0, 0, 0 )
		lump = util.Decompress( lump:sub( 13, 17 ) .. size .. lump:sub( 18 ) ) or ""
		if #lump == 0 or #lump < actual - 1 then return {} end
	end
	local out = {}
	for cls in lump:gmatch( '"classname"%s+"([^"]+)"' ) do out[ cls:lower() ] = ( out[ cls:lower() ] or 0 ) + 1 end
	return out
end

-- Compiled into the map or removed on spawn: never present at runtime
local NOT_ENTITIES = {
	worldspawn = true, func_detail = true, func_viscluster = true, func_ladder = true, info_ladder = true,
	light = true, light_spot = true, light_environment = true, light_dynamic = false, info_lighting = true,
	info_overlay = true, info_overlay_transition = true, infodecal = true, env_cubemap = true, prop_static = true,
	info_node = true, info_node_air = true, info_node_hint = true, info_node_climb = true, info_hint = true,
	info_no_dynamic_shadow = true, func_occluder = false, info_player_start = false, logic_auto = true,
	trigger_autosave = true, info_null = true, func_areaportalwindow = false,
}

local function uncreatable( map )
	local out = {}
	for cls in pairs( mapClasses( map ) ) do
		if not NOT_ENTITIES[ cls ] and #ents.FindByClass( cls ) == 0 then
			local e = ents.Create( cls )
			if IsValid( e ) then e:Remove() else out[ #out + 1 ] = cls end
		end
	end
	table.sort( out )
	return out
end

local function missingModels()
	local out, seen = {}, {}
	for _, e in ipairs( ents.GetAll() ) do
		local m = e:GetModel()
		if isstring( m ) and m:lower():EndsWith( ".mdl" ) and not seen[ m ] then
			seen[ m ] = true
			if not util.IsValidModel( m ) then out[ #out + 1 ] = m end
		end
	end
	table.sort( out )
	return out
end

local function missingSounds()
	local out, seen = {}, {}
	for _, e in ipairs( ents.FindByClass( "ambient_generic" ) ) do
		local s = e:GetInternalVariable( "m_iszSound" )
		if isstring( s ) and s ~= "" and not seen[ s ] then
			seen[ s ] = true
			local ok
			if s:lower():match( "%.wav$" ) or s:lower():match( "%.mp3$" ) or s:lower():match( "%.ogg$" ) then
				local clean = s:gsub( "^[%*#@<>%^%)%(}%$!%?]+", "" )
				clean = clean:gsub( "\\", "/" )
				local path = HL2A.ResolveSound( clean )
				ok = file.Exists( "sound/" .. path, "GAME" )
			else
				ok = sound.GetProperties( s ) ~= nil
			end
			if not ok then out[ #out + 1 ] = s end
		end
	end
	table.sort( out )
	return out
end

-- Report -------------------------------------------------------------------------------------

local function writeReport( s )
	local lines = { "HL2: Alone smoke test - " .. os.date( "%Y-%m-%d %H:%M", s.started or os.time() ),
		string.format( "%d of %d maps done, %d s each", s.total - #s.queue, s.total, s.seconds ), "" }
	local problems = 0
	for _, map in ipairs( s.order or {} ) do
		local r = s.results[ map ]
		if r then
			local issues = {}
			if r.crashed then issues[ #issues + 1 ] = "CRASHED or hung while loading / running" end
			for _, e in ipairs( r.errors or {} ) do issues[ #issues + 1 ] = "error: " .. e end
			if r.models and #r.models > 0 then issues[ #issues + 1 ] = "missing models: " .. table.concat( r.models, ", " ) end
			if r.sounds and #r.sounds > 0 then issues[ #issues + 1 ] = "missing sounds: " .. table.concat( r.sounds, ", " ) end
			if r.classes and #r.classes > 0 then issues[ #issues + 1 ] = "can't create: " .. table.concat( r.classes, ", " ) end
			if r.commands and #r.commands > 0 then issues[ #issues + 1 ] = "unhandled map commands: " .. table.concat( r.commands, " | " ) end
			if r.faded then issues[ #issues + 1 ] = "screen left faded out by " .. r.faded end
			problems = problems + ( #issues > 0 and 1 or 0 )
			lines[ #lines + 1 ] = string.format( "== %s  %s", map, #issues == 0 and "ok" or ( #issues .. " issue(s)" ) )
			for _, i in ipairs( issues ) do lines[ #lines + 1 ] = "  " .. i end
			if not r.crashed then
				lines[ #lines + 1 ] = string.format( "  checkpoint: %s (%d autosaves)   soundscapes: %d   frame: %s ms   costliest: %s",
					r.checkpoint and "yes" or "NO", r.autosaves or 0, r.soundscapes or 0, r.frameMs and tostring( r.frameMs ) or "?", r.costly or "-" )
			end
		end
	end
	table.insert( lines, 3, string.format( "%d map(s) with issues", problems ) )
	file.CreateDir( "hl2alone" )
	file.Write( REPORT, table.concat( lines, "\n" ) .. "\n" )
end

local function nextMap( s )
	local map = table.remove( s.queue, 1 )
	if not map then
		s.running = false
		store( nil )
		writeReport( s )
		PrintMessage( HUD_PRINTCENTER, "Smoke test done: data/hl2alone/smoketest_report.txt" )
		MsgN( "[HL2A] smoke test done: garrysmod/data/" .. REPORT )
		return
	end
	s.current = map
	store( s )
	MsgN( string.format( "[HL2A] smoke test %d/%d: %s", s.total - #s.queue, s.total, map ) )
	timer.Simple( 1, function() RunConsoleCommand( "map", map ) end )
end

local function finish( s, map )
	local r = { errors = found.errors }
	r.models, r.sounds, r.classes = missingModels(), missingSounds(), uncreatable( map )
	r.commands = table.GetKeys( found.commands )
	r.faded = found.faded or nil
	r.checkpoint, r.autosaves = HL2A.CheckpointInfo()
	r.soundscapes = HL2A.SoundscapeCount and HL2A.SoundscapeCount() or 0
	local top = HL2A.Perf.Top( 1 )[ 1 ]
	if top then r.costly = string.format( "%s %.2f ms/s", top[ 1 ], top[ 2 ] * 1000 / s.seconds ) end

	-- Ask the client for its frame time, then move on
	net.Start( "hl2a.smoketest" ) net.Broadcast()
	timer.Simple( 2, function()
		r.frameMs = found.frameMs
		s.results[ map ] = r
		s.current = nil
		writeReport( s )
		nextMap( s )
	end )
end

hook.Add( "InitPostEntity", "hl2a.smoketest", function()
	local s = load()
	if not s or not s.running then return end
	SetGlobal2Bool( "hl2a.smoketest", true )
	reset()
	HL2A.Perf.Reset()
	local map = HL2A.MapPath()
	hook.Add( "PlayerSpawn", "hl2a.smoketest", function( ply )
		hook.Remove( "PlayerSpawn", "hl2a.smoketest" )
		timer.Simple( 0, function() if IsValid( ply ) then ply:GodEnable() end end )
		timer.Simple( s.seconds, function() finish( s, map ) end )
	end )
end )

local function host( ply ) return not IsValid( ply ) or ply:IsListenServerHost() or ply:IsSuperAdmin() end

concommand.Add( "hl2a_smoketest", function( ply, _, args )
	if not host( ply ) then return end
	local cmd = ( args[ 1 ] or "status" ):lower()
	local s = load()

	if cmd == "start" then
		if file.Exists( "hl2alone/graphbuild.json", "DATA" ) then MsgN( "[HL2A] the node graph build is running; stop it first" ) return end
		local seconds = math.Clamp( tonumber( args[ 2 ] ) or 20, 5, 300 )
		local filter = ( args[ 3 ] or "" ):lower()
		local maps = {}
		for _, m in ipairs( HL2A.ModMaps() ) do
			if filter == "" or m:find( filter, 1, true ) then maps[ #maps + 1 ] = m end
		end
		s = { running = true, seconds = seconds, queue = maps, order = table.Copy( maps ), total = #maps, results = {}, started = os.time() }
		MsgN( string.format( "[HL2A] smoke test: %d maps, %d s each (about %d min); it changes maps by itself", #maps, seconds, math.ceil( #maps * ( seconds + 25 ) / 60 ) ) )
		nextMap( s )
	elseif cmd == "resume" then
		if not s then MsgN( "[HL2A] no smoke test to resume" ) return end
		if s.current then
			s.results[ s.current ] = { crashed = true }
			MsgN( "[HL2A] marking " .. s.current .. " as crashed/hung" )
		end
		s.running = true
		nextMap( s )
	elseif cmd == "stop" then
		if s then writeReport( s ) end
		store( nil )
		SetGlobal2Bool( "hl2a.smoketest", false )
		MsgN( "[HL2A] smoke test stopped; report so far: garrysmod/data/" .. REPORT )
	else
		MsgN( s and string.format( "[HL2A] smoke test: %d of %d maps left (on %s)", #s.queue, s.total, tostring( s.current ) )
			or "[HL2A] smoke test not running" )
	end
end, nil, "Load every map and report what's broken: start [seconds] [filter] | stop | status | resume" )
