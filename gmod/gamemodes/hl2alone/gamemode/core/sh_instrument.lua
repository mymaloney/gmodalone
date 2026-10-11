--[[
	Instrumentation for the gamemode's own callbacks, used by the performance
	readout (sh_perf.lua), bug reports (sh_report.lua) and the map smoke test
	(sv_smoketest.lua).

	hook.Add, timer.Create, timer.Simple, net.Receive and concommand.Add are
	wrapped so that callbacks registered from this gamemode's files (and only
	those: other addons are untouched) are
	  * timed: HL2A.Perf.cost[ key ] accumulates seconds, key like
	    "Think hl2a.weather", "timer hl2a.filter" or
	    "timer.Simple modules/sv_x.lua:42";
	  * run under xpcall: an error is recorded (HL2A.Log.errors, with its
	    traceback) and still printed, and no longer aborts the other hooks
	    of the same event.
	Print/Msg/MsgN output is also kept (last lines) for bug reports.
]]

HL2A.Perf = HL2A.Perf or { cost = {}, calls = {} }
HL2A.Log = HL2A.Log or { lines = {}, errors = {} }

local Perf, Log = HL2A.Perf, HL2A.Log
local MAX_LINES, MAX_ERRORS = 300, 50
local SysTime, xpcall, select, unpack = SysTime, xpcall, select, unpack

-- Recent output ------------------------------------------------------------------------------

local function keep( text )
	for line in tostring( text ):gmatch( "[^\n]+" ) do
		Log.lines[ #Log.lines + 1 ] = line
		if #Log.lines > MAX_LINES then table.remove( Log.lines, 1 ) end
	end
end

if not HL2A.InstrumentedPrint then
	HL2A.InstrumentedPrint = true
	local oPrint, oMsgN, oMsg = print, MsgN, Msg
	function print( ... )
		local parts = {}
		for i = 1, select( "#", ... ) do parts[ i ] = tostring( ( select( i, ... ) ) ) end
		keep( table.concat( parts, "\t" ) )
		return oPrint( ... )
	end
	function MsgN( ... )
		local parts = {}
		for i = 1, select( "#", ... ) do parts[ i ] = tostring( ( select( i, ... ) ) ) end
		keep( table.concat( parts ) )
		return oMsgN( ... )
	end
	function Msg( ... )
		local parts = {}
		for i = 1, select( "#", ... ) do parts[ i ] = tostring( ( select( i, ... ) ) ) end
		keep( table.concat( parts ) )
		return oMsg( ... )
	end
end

-- Errors -------------------------------------------------------------------------------------

--- Hooks the smoke test / report listen to: called with ( message, traceback, where )
HL2A.OnError = HL2A.OnError or {}

function HL2A.RecordError( message, trace, where )
	local e = { message = tostring( message ), trace = trace or "", where = where or "?", time = os.time(),
		realm = SERVER and "server" or "client", map = game.GetMap() }
	Log.errors[ #Log.errors + 1 ] = e
	if #Log.errors > MAX_ERRORS then table.remove( Log.errors, 1 ) end
	for _, fn in pairs( HL2A.OnError ) do pcall( fn, e ) end
end

-- Wrapping -----------------------------------------------------------------------------------

local OURS = "gamemodes/hl2alone/"

local function fromUs( level )
	local info = debug.getinfo( level, "S" )
	return info and info.short_src and info.short_src:find( OURS, 1, true ) ~= nil
end

-- "modules/sv_x.lua:42" for the function at that stack level (anonymous timers have no name)
local function site( level )
	local info = debug.getinfo( level + 1, "Sl" )
	if not info then return "?" end
	local src = info.short_src or "?"
	return ( src:match( "gamemode/(.*)$" ) or src ) .. ":" .. tostring( info.currentline or "?" )
end

local function pack( ... ) return { n = select( "#", ... ), ... } end

local function wrap( key, fn )
	local function onError( err )
		local trace = debug.traceback( tostring( err ), 2 )
		HL2A.RecordError( err, trace, key )
		ErrorNoHalt( "[HL2A] error in " .. key .. ": " .. trace .. "\n" )
	end
	return function( ... )
		local t = SysTime()
		local r = pack( xpcall( fn, onError, ... ) )
		Perf.cost[ key ] = ( Perf.cost[ key ] or 0 ) + ( SysTime() - t )
		Perf.calls[ key ] = ( Perf.calls[ key ] or 0 ) + 1
		if r[ 1 ] then return unpack( r, 2, r.n ) end
	end
end
HL2A.WrapCallback = wrap

if not HL2A.InstrumentedAPI then
	HL2A.InstrumentedAPI = true

	local oHookAdd = hook.Add
	function hook.Add( event, id, fn, ... )
		if isfunction( fn ) and fromUs( 3 ) then fn = wrap( tostring( event ) .. " " .. tostring( id ), fn ) end
		return oHookAdd( event, id, fn, ... )
	end

	local oCreate = timer.Create
	function timer.Create( name, delay, reps, fn, ... )
		if isfunction( fn ) and fromUs( 3 ) then fn = wrap( "timer " .. tostring( name ), fn ) end
		return oCreate( name, delay, reps, fn, ... )
	end

	local oSimple = timer.Simple
	function timer.Simple( delay, fn, ... )
		if isfunction( fn ) and fromUs( 3 ) then fn = wrap( "timer.Simple " .. site( 2 ), fn ) end
		return oSimple( delay, fn, ... )
	end

	local oReceive = net.Receive
	function net.Receive( name, fn, ... )
		if isfunction( fn ) and fromUs( 3 ) then fn = wrap( "net " .. tostring( name ), fn ) end
		return oReceive( name, fn, ... )
	end

	local oCommand = concommand.Add
	function concommand.Add( name, fn, ... )
		if isfunction( fn ) and fromUs( 3 ) then fn = wrap( "command " .. tostring( name ), fn ) end
		return oCommand( name, fn, ... )
	end
end

--- Resets the accumulated costs (perf readout windows, smoke test per map)
function HL2A.Perf.Reset()
	Perf.cost, Perf.calls = {}, {}
end

--- { key, seconds, calls } sorted by cost
function HL2A.Perf.Top( n )
	local out = {}
	for k, v in pairs( Perf.cost ) do out[ #out + 1 ] = { k, v, Perf.calls[ k ] or 0 } end
	table.sort( out, function( a, b ) return a[ 2 ] > b[ 2 ] end )
	if n then for i = #out, n + 1, -1 do out[ i ] = nil end end
	return out
end
