--[[
	Keeps the gamemode's server settings (sandbox tools, post-processing,
	god mode, timers ...) across map changes.

	On a single-player / listen server the client shares those convars, and
	when its Lua starts on a new map it can put a Lua-created convar back to
	its default or a stale value, so settings like hl2a_sandbox_tools looked
	on but did nothing until toggled off and on. Here every change is
	remembered for the session, and after each map load anything that came
	back different is set again; then HL2A_PublishSettings lets modules
	re-send what clients read (GlobalVars) and re-apply their effects.

	Only within one run of the game: a value saved by an earlier session
	never overrides server.cfg or the config.
]]

local FILE = "hl2alone/server_settings.json"
local SETTLE = 6 -- seconds after the first player spawns during which reverts are undone

-- Roughly when this game process started; the same across map changes
local function bootId() return math.floor( os.time() - SysTime() ) end

local saved = {}
local restoring = true -- right after a map load: changes now are the engine's, not the player's

local function load()
	local data = util.JSONToTable( file.Read( FILE, "DATA" ) or "" )
	if istable( data ) and math.abs( ( data.boot or 0 ) - bootId() ) <= 2 and istable( data.values ) then
		saved = data.values
	end
end

local function store()
	file.CreateDir( "hl2alone" )
	file.Write( FILE, util.TableToJSON( { boot = bootId(), values = saved } ) )
end

local function names()
	local out = {}
	for name in pairs( HL2A.ConVars ) do
		if not HL2A.ClientConVars[ name ] then out[ #out + 1 ] = name end
	end
	return out
end

-- Remember every change the player makes
for _, name in ipairs( names() ) do
	cvars.AddChangeCallback( name, function( _, _, new )
		if restoring then return end
		saved[ name ] = new
		store()
	end, "hl2a.settings" )
end

--- Sets back anything that differs from the remembered value; returns how many
local function restore()
	local n = 0
	for name, value in pairs( saved ) do
		local cv = HL2A.ConVars[ name ]
		if cv and cv:GetString() ~= value then
			RunConsoleCommand( name, value )
			n = n + 1
		end
	end
	return n
end

local function publish() hook.Run( "HL2A_PublishSettings" ) end

load()
restore() -- before the map's entities read them

local settleTimer = false
hook.Add( "PlayerInitialSpawn", "hl2a.settings", function()
	if settleTimer then return end
	settleTimer = true
	-- The client's Lua starts around now; undo what it resets for a few seconds
	local left = SETTLE
	timer.Create( "hl2a.settings.settle", 1, SETTLE, function()
		local n = restore()
		if n > 0 then MsgN( "[HL2A] settings: restored " .. n .. " value(s) reset by the map change" ) end
		left = left - 1
		timer.Simple( 0.1, publish )
		if left <= 0 then restoring = false end
	end )
end )

-- Changes made before any player spawned (server.cfg, the console) count too
hook.Add( "InitPostEntity", "hl2a.settings", function()
	timer.Simple( 0, publish )
	-- A server nobody has joined yet: start remembering changes anyway
	timer.Simple( 30, function() if not settleTimer then restoring = false end end )
end )

concommand.Add( "hl2a_settings_dump", function( ply )
	if IsValid( ply ) and not ply:IsListenServerHost() then return end
	MsgN( "[HL2A] remembered server settings this session (" .. ( restoring and "settling" or "live" ) .. "):" )
	for name, value in SortedPairs( saved ) do
		MsgN( string.format( "  %-40s %s (now %s)", name, value, HL2A.ConVars[ name ] and HL2A.ConVars[ name ]:GetString() or "?" ) )
	end
end, nil, "Show the server settings carried across map changes" )
