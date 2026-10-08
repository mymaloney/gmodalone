--[[
	Episode One countdowns ("core collapse" and "citadel explosion"), driven
	by the amod_core_timer entity's inputs. Recovered from server.dll:

	  * Start: countdown of N seconds, centre-print "M:SS Minutes Till ..."
	  * Announces at 30/25/20/15/10/5/2/1 minutes and 30/10 seconds
	  * At zero: freeze player, hide HUD, fade to black (1.5s), explosion
	    sound after 2s, reload the last save after 9s
	  * Stop: "Citadel Core Neutralized" / "Citadel Explosion Starting Now.."

	The original kept this on the player, so it survived level transitions;
	here the remaining time is carried across changelevel via a data file.
]]

local CV = HL2A.ConVars

local KINDS = {
	core = {
		cvar = "amod_do_core_timer",
		start = "%d:%02d Minutes Till Core Collapse",
		tick = "%d:%02d Minutes Till Core Collapse",
		stop = "Citadel Core Neutralized",
	},
	citadel = {
		cvar = "amod_do_citadel_timer",
		start = "%d:%02d Minutes Till Citadel Explosion",
		tick = "%d:%02d Minutes Till Citadel Collapse", -- sic, as in the original
		stop = "Citadel Explosion Starting Now..",
	},
}

local ANNOUNCE = { [ 1800 ] = true, [ 1500 ] = true, [ 1200 ] = true, [ 900 ] = true, [ 600 ] = true,
	[ 300 ] = true, [ 120 ] = true, [ 60 ] = true, [ 30 ] = true, [ 10 ] = true }

local STATE_FILE = "hl2alone/timers.json"

HL2A.Timers = HL2A.Timers or {} -- kind -> { ends = CurTime, lastAnnounce = secs }

local function centerPrint( fmt, secs )
	local msg = secs and string.format( fmt, math.floor( secs / 60 ), secs % 60 ) or fmt
	for _, ply in player.Iterator() do ply:PrintMessage( HUD_PRINTCENTER, msg ) end
end

local function enabled( kind )
	return GetConVar( KINDS[ kind ].cvar ):GetBool()
end

function HL2A.StartTimer( kind, seconds )
	if not KINDS[ kind ] or not enabled( kind ) then return end
	seconds = math.floor( tonumber( seconds ) or 0 )
	HL2A.Timers[ kind ] = { ends = CurTime() + seconds, duration = seconds }
	centerPrint( KINDS[ kind ].start, seconds )
end

function HL2A.StopTimer( kind )
	if not KINDS[ kind ] or not enabled( kind ) then return end
	HL2A.Timers[ kind ] = nil
	centerPrint( KINDS[ kind ].stop )
end

function HL2A.ShowTimer( kind )
	local t = HL2A.Timers[ kind ]
	if not t or not enabled( kind ) then return end
	centerPrint( KINDS[ kind ].start, math.max( 0, math.floor( t.ends - CurTime() ) ) )
end

-- Countdowns that ran out. GMod saves don't hold Lua state, so after the
-- reload the countdown restarts from its full length.
local restart = {}

local function expire( kind )
	restart[ kind ] = HL2A.Timers[ kind ].duration
	HL2A.Timers[ kind ] = nil
	centerPrint( KINDS[ kind ].tick, 0 )

	for _, ply in player.Iterator() do
		ply:Freeze( true )
		ply:SetNW2Bool( "hl2a.hidehud", true )
		ply:ScreenFade( bit.bor( SCREENFADE.OUT, SCREENFADE.STAYOUT ), color_black, 1.5, 1.5 )
	end

	timer.Simple( 2, function()
		-- Original: "playgamesound explode_6"
		for _, ply in player.Iterator() do ply:EmitSound( "ambient/explosions/explode_6.wav", 0 ) end
	end )

	timer.Simple( 9, function()
		for _, ply in player.Iterator() do
			ply:Freeze( false )
			ply:SetNW2Bool( "hl2a.hidehud", false )
			-- "reload" loads the most recent save; if there is none, fall back to death
			ply:ConCommand( "reload" )
		end
		timer.Simple( 2, function()
			for _, ply in player.Iterator() do
				if ply:Alive() then ply:ScreenFade( SCREENFADE.PURGE, color_black, 0, 0 ) ply:Kill() end
			end
		end )
	end )
end

hook.Add( "Think", "hl2a.timers", function()
	for kind, t in pairs( HL2A.Timers ) do
		if enabled( kind ) then
			local left = math.floor( t.ends - CurTime() )
			if left <= 0 then
				expire( kind )
			elseif ANNOUNCE[ left ] and t.lastAnnounce ~= left then
				t.lastAnnounce = left
				centerPrint( KINDS[ kind ].tick, left )
			end
		end
	end
end )

-- Carry running timers across level changes ---------------------------------

hook.Add( "ShutDown", "hl2a.timers", function()
	local out = { saved = os.time() }
	for kind, t in pairs( HL2A.Timers ) do out[ kind ] = { left = t.ends - CurTime(), duration = t.duration } end
	for kind, duration in pairs( restart ) do out[ kind ] = { left = duration, duration = duration } end
	file.CreateDir( "hl2alone" )
	file.Write( STATE_FILE, util.TableToJSON( out ) )
end )

hook.Add( "InitPostEntity", "hl2a.timers", function()
	local data = util.JSONToTable( file.Read( STATE_FILE, "DATA" ) or "" )
	file.Delete( STATE_FILE )
	-- Only a changelevel (seconds apart) carries timers; a fresh session doesn't
	if not data or os.time() - ( data.saved or 0 ) > 60 then return end
	for kind in pairs( KINDS ) do
		local d = data[ kind ]
		if istable( d ) then HL2A.Timers[ kind ] = { ends = CurTime() + d.left, duration = d.duration } end
	end
end )

-- Starting a chapter is a new game: drop any countdown
hook.Add( "HL2A.NewGame", "hl2a.timers", function()
	HL2A.Timers = {}
	restart = {}
	file.Delete( STATE_FILE )
end )
