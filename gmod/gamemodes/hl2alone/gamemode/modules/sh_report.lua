--[[
	hl2a_report: writes one file with what's needed to look into a problem,
	data/hl2alone/reports/report_<date>.txt:
	  * game version and branch, map, single player or not
	  * soundscape, weather, StormFox and post-processing state
	  * the gamemode's settings that differ from their defaults
	  * mounted addons, flagging ones known to clash
	  * recent errors from the gamemode (with tracebacks) and recent console
	    lines it printed, client and server (the server part is fetched from
	    a listen server's host / single player)
	The console itself can't be read from Lua: engine messages aren't in it.
]]

local function differing()
	local out = {}
	for name, cv in SortedPairs( HL2A.ConVars ) do
		if cv and cv.GetString and cv:GetString() ~= cv:GetDefault() then
			out[ #out + 1 ] = string.format( "  %s = %s (default %s)", name, cv:GetString(), cv:GetDefault() )
		end
	end
	return out
end

local function logSection( title )
	local out = { "", "== " .. title .. ": recent errors" }
	for _, e in ipairs( HL2A.Log.errors ) do
		out[ #out + 1 ] = string.format( "-- %s, %s, in %s", os.date( "%H:%M:%S", e.time ), e.map or "?", e.where )
		out[ #out + 1 ] = e.trace ~= "" and e.trace or e.message
	end
	if #HL2A.Log.errors == 0 then out[ #out + 1 ] = "  none" end
	out[ #out + 1 ] = ""
	out[ #out + 1 ] = "== " .. title .. ": recent output"
	for _, l in ipairs( HL2A.Log.lines ) do out[ #out + 1 ] = "  " .. l end
	return out
end

if SERVER then
	util.AddNetworkString( "hl2a.report" )

	local function serverSection()
		local out = { "", "==== SERVER ====" }
		local cp, autosaves = false, 0
		if HL2A.CheckpointInfo then cp, autosaves = HL2A.CheckpointInfo() end
		out[ #out + 1 ] = string.format( "checkpoint: %s (%d autosave entities)   soundscapes tracked: %d   StormFox installed: %s",
			tostring( cp ), autosaves, HL2A.SoundscapeCount and HL2A.SoundscapeCount() or -1,
			tostring( HL2A.StormFoxInstalled and HL2A.StormFoxInstalled() ) )
		out[ #out + 1 ] = ""
		out[ #out + 1 ] = "== server settings changed from defaults"
		table.Add( out, differing() )
		table.Add( out, logSection( "server" ) )
		return table.concat( out, "\n" )
	end

	net.Receive( "hl2a.report", function( _, ply )
		if not ( game.SinglePlayer() or ply:IsListenServerHost() or ply:IsSuperAdmin() ) then return end
		local data = util.Compress( serverSection() ) or ""
		if #data > 60000 then data = util.Compress( serverSection():sub( -100000 ) ) or "" end
		net.Start( "hl2a.report" )
			net.WriteUInt( #data, 32 )
			net.WriteData( data, #data )
		net.Send( ply )
	end )
	return
end

-- Addons known to clash with parts of the port, by title
local CONFLICTS = {
	{ "peplus", "reloads every particle file; the port re-adds its own after it" },
	{ "particle effects+", "reloads every particle file; the port re-adds its own after it" },
	{ "flashlight", "replaces the flashlight; the port has its own (flicker, lag, shadows)" },
	{ "vmanip", "may replace the flashlight / viewmodel" },
	{ "stormfox", "supported: see hl2a_stormfox" },
	{ "weather", "may double up the port's weather" },
	{ "mmod", "needs its particle pack, or many 'unknown particle system' lines" },
	{ "reshade", "doubles post-processing; consider the Plain look preset" },
	{ "post process", "doubles post-processing; consider the Plain look preset" },
	{ "hd props", "large textures: memory" },
	{ "alyx", "Alyx asset ports are often uncompressed 4K textures: memory" },
	{ "remade", "large textures: memory" },
}

local function clientSection()
	local ply = LocalPlayer()
	local out = {
		"HL2: Alone bug report - " .. os.date( "%Y-%m-%d %H:%M:%S" ),
		string.format( "GMod %s (%s), branch %s, %s, %dx%d", tostring( VERSIONSTR or VERSION ), tostring( VERSION ),
			tostring( BRANCH ), system.IsWindows() and "Windows" or system.IsLinux() and "Linux" or "macOS", ScrW(), ScrH() ),
		string.format( "map %s, %s, %d player(s)", game.GetMap(), game.SinglePlayer() and "single player" or "multiplayer", player.GetCount() ),
		"",
		"== state",
		string.format( "  soundscape '%s'   weather type %d active %s maptype %d density %.4f   StormFox %s (sky %s, fog %s)",
			IsValid( ply ) and ply:GetNW2String( "hl2a.soundscape" ) or "?", GetGlobal2Int( "hl2a.weather.type" ),
			tostring( GetGlobal2Bool( "hl2a.weather.active" ) ), GetGlobal2Int( "hl2a.weather.maptype" ), GetGlobal2Float( "hl2a.weather.density" ),
			tostring( GetGlobal2Bool( "hl2a.stormfox" ) ), tostring( GetGlobal2Bool( "hl2a.stormfox.sky" ) ), tostring( GetGlobal2Bool( "hl2a.stormfox.fog" ) ) ),
		string.format( "  post-processing %s, colour grade %s, sandbox tools %s",
			tostring( GetGlobal2Bool( "hl2a.postprocess", true ) ), tostring( GetGlobal2Bool( "hl2a.epicfilter", true ) ), tostring( GetGlobal2Bool( "hl2a.sandbox" ) ) ),
		"",
		"== client settings changed from defaults",
	}
	table.Add( out, differing() )

	out[ #out + 1 ] = ""
	out[ #out + 1 ] = "== mounted addons"
	local flagged = {}
	for _, a in ipairs( engine.GetAddons() ) do
		if a.mounted then
			local note
			local t = ( a.title or "" ):lower()
			for _, c in ipairs( CONFLICTS ) do
				if t:find( c[ 1 ], 1, true ) then note = c[ 2 ] break end
			end
			out[ #out + 1 ] = string.format( "  %s (%s)%s", a.title or "?", tostring( a.wsid ), note and ( "   <- " .. note ) or "" )
			if note then flagged[ #flagged + 1 ] = a.title end
		end
	end
	if #flagged > 0 then table.insert( out, 5, "flagged addons: " .. table.concat( flagged, ", " ) ) end

	table.Add( out, logSection( "client" ) )
	return table.concat( out, "\n" )
end

local function write( text )
	file.CreateDir( "hl2alone/reports" )
	local name = "hl2alone/reports/report_" .. os.date( "%Y-%m-%d_%H-%M-%S" ) .. ".txt"
	file.Write( name, text .. "\n" )
	MsgN( "[HL2A] report written: garrysmod/data/" .. name )
	notification.AddLegacy( "Report saved: garrysmod/data/" .. name, NOTIFY_GENERIC, 6 )
end

local pending

net.Receive( "hl2a.report", function()
	if not pending then return end
	local len = net.ReadUInt( 32 )
	local server = util.Decompress( net.ReadData( len ) ) or "(server part unreadable)"
	local text = pending
	pending = nil
	write( text .. "\n" .. server )
end )

concommand.Add( "hl2a_report", function()
	pending = clientSection()
	net.Start( "hl2a.report" ) net.SendToServer()
	-- Not the host on someone else's server: write without the server part
	local this = pending
	timer.Simple( 3, function()
		if pending == this then
			pending = nil
			write( this .. "\n\n(server part not available: only the host can include it)" )
		end
	end )
end, nil, "Write a bug report (settings, addons, recent errors and output) to garrysmod/data/hl2alone/reports/" )
