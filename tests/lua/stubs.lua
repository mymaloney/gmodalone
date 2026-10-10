-- Minimal GMod API for running gamemode modules outside the game.
-- Time is driven by the test: Tick( seconds ) advances it and runs due timers.

SERVER, CLIENT = true, false
HL2A = {}

-- Types and helpers --------------------------------------------------------------------------

function isstring( v ) return type( v ) == "string" end
function isnumber( v ) return type( v ) == "number" end
function isbool( v ) return type( v ) == "boolean" end
function istable( v ) return type( v ) == "table" and getmetatable( v ) ~= VEC end
function isfunction( v ) return type( v ) == "function" end
function tobool( v ) return v ~= nil and v ~= false and v ~= "0" and v ~= 0 and v ~= "false" end
function IsValid( v ) return v ~= nil and v ~= false and v ~= NULL and ( type( v ) ~= "table" or v.valid ~= false ) end
NULL = setmetatable( {}, { __tostring = function() return "NULL" end } )

LOG = {}
function MsgN( ... ) local t = {} for i = 1, select( "#", ... ) do t[ i ] = tostring( ( select( i, ... ) ) ) end LOG[ #LOG + 1 ] = table.concat( t ) end
Msg, print = MsgN, MsgN
function ErrorNoHalt( m ) LOG[ #LOG + 1 ] = "ERROR " .. tostring( m ) end
function PrintMessage() end

function string.StartWith( s, p ) return s:sub( 1, #p ) == p end
function string.EndsWith( s, p ) return p == "" or s:sub( -#p ) == p end
function string.Trim( s ) return ( s:gsub( "^%s+", "" ):gsub( "%s+$", "" ) ) end
function string.Explode( sep, s )
	local t, i = {}, 1
	while true do
		local a, b = s:find( sep, i, true )
		if not a then t[ #t + 1 ] = s:sub( i ) return t end
		t[ #t + 1 ] = s:sub( i, a - 1 )
		i = b + 1
	end
end
function table.Copy( t ) local o = {} for k, v in pairs( t ) do o[ k ] = type( v ) == "table" and getmetatable( v ) == nil and table.Copy( v ) or v end return o end
function table.Add( a, b ) for _, v in ipairs( b ) do a[ #a + 1 ] = v end return a end
function table.HasValue( t, x ) for _, v in pairs( t ) do if v == x then return true end end return false end
function table.GetKeys( t ) local o = {} for k in pairs( t ) do o[ #o + 1 ] = k end return o end
function table.Count( t ) local n = 0 for _ in pairs( t ) do n = n + 1 end return n end
function SortedPairs( t ) local keys = table.GetKeys( t ) table.sort( keys ) local i = 0 return function() i = i + 1 if keys[ i ] then return keys[ i ], t[ keys[ i ] ] end end end
function math.Clamp( v, a, b ) return math.max( a, math.min( b, v ) ) end
function math.Approach( a, b, d ) if a < b then return math.min( a + d, b ) end return math.max( a - d, b ) end
function math.Round( v, d ) local m = 10 ^ ( d or 0 ) return math.floor( v * m + 0.5 ) / m end
function Lerp( t, a, b ) return a + ( b - a ) * t end
bit = bit or { band = function( a, b ) local r, p = 0, 1 while a > 0 and b > 0 do if a % 2 == 1 and b % 2 == 1 then r = r + p end a, b, p = math.floor( a / 2 ), math.floor( b / 2 ), p * 2 end return r end }

-- Vectors ------------------------------------------------------------------------------------

VEC = {}
VEC.__index = VEC
function Vector( x, y, z )
	if type( x ) == "string" then local a, b, c = x:match( "(%S+)%s+(%S+)%s+(%S+)" ) return Vector( tonumber( a ), tonumber( b ), tonumber( c ) ) end
	return setmetatable( { x = x or 0, y = y or 0, z = z or 0 }, VEC )
end
VEC.__add = function( a, b ) return Vector( a.x + b.x, a.y + b.y, a.z + b.z ) end
VEC.__sub = function( a, b ) return Vector( a.x - b.x, a.y - b.y, a.z - b.z ) end
VEC.__div = function( a, k ) return Vector( a.x / k, a.y / k, a.z / k ) end
VEC.__eq = function( a, b ) return a.x == b.x and a.y == b.y and a.z == b.z end
VEC.__tostring = function( v ) return string.format( "(%g %g %g)", v.x, v.y, v.z ) end
function VEC:Distance( b ) return math.sqrt( ( self.x - b.x ) ^ 2 + ( self.y - b.y ) ^ 2 + ( self.z - b.z ) ^ 2 ) end
function VEC:WithinAABox( a, b ) return self.x >= a.x and self.y >= a.y and self.z >= a.z and self.x <= b.x and self.y <= b.y and self.z <= b.z end
function isvector( v ) return getmetatable( v ) == VEC end
function Angle( p, y, r ) return { p = p or 0, y = y or 0, r = r or 0 } end
function isangle( v ) return type( v ) == "table" and v.p ~= nil and getmetatable( v ) ~= VEC end
vector_origin = Vector( 0, 0, 0 )

-- Time, hooks, timers ------------------------------------------------------------------------

NOW = 0
function CurTime() return NOW end
function RealTime() return NOW end
function SysTime() return os.clock() end
function FrameTime() return 0.016 end

HOOKS = {}
hook = {
	Add = function( e, id, f ) HOOKS[ e ] = HOOKS[ e ] or {} HOOKS[ e ][ id ] = f end,
	Remove = function( e, id ) if HOOKS[ e ] then HOOKS[ e ][ id ] = nil end end,
	Run = function( e, ... ) for _, f in pairs( HOOKS[ e ] or {} ) do local r = f( ... ) if r ~= nil then return r end end end,
}
hook.Call = function( e, _, ... ) return hook.Run( e, ... ) end

TIMERS, ONCE = {}, {}
timer = {
	Create = function( n, d, reps, f ) TIMERS[ n ] = { d = d, reps = reps, f = f, next = NOW + d } end,
	Remove = function( n ) TIMERS[ n ] = nil end,
	Simple = function( d, f ) ONCE[ #ONCE + 1 ] = { at = NOW + d, f = f } end,
	Exists = function( n ) return TIMERS[ n ] ~= nil end,
}
function Tick( seconds )
	local target = NOW + ( seconds or 0 )
	repeat
		local due = {}
		for i = #ONCE, 1, -1 do if ONCE[ i ].at <= target then due[ #due + 1 ] = ONCE[ i ] table.remove( ONCE, i ) end end
		table.sort( due, function( a, b ) return a.at < b.at end )
		for _, t in ipairs( due ) do NOW = math.max( NOW, t.at ) t.f() end
		for n, t in pairs( TIMERS ) do
			while TIMERS[ n ] == t and t.next <= target do
				NOW = math.max( NOW, t.next ) t.next = t.next + math.max( t.d, 0.001 ) t.f()
				if t.reps > 0 then t.reps = t.reps - 1 if t.reps == 0 then TIMERS[ n ] = nil end end
			end
		end
		local more = false
		for _, t in ipairs( ONCE ) do if t.at <= target then more = true end end
	until not more
	NOW = target
end

-- Files, JSON, net, convars ------------------------------------------------------------------

FILES = {}
file = {
	Read = function( p ) return FILES[ p ] end,
	Write = function( p, s ) FILES[ p ] = s end,
	Append = function( p, s ) FILES[ p ] = ( FILES[ p ] or "" ) .. s end,
	Delete = function( p ) FILES[ p ] = nil end,
	Exists = function( p ) return FILES[ p ] ~= nil or ( EXISTS and EXISTS( p ) ) or false end,
	CreateDir = function() end,
	Find = function() return {}, {} end,
}
local JSON = {}
util = {
	TableToJSON = function( t ) JSON[ #JSON + 1 ] = table.Copy( t ) return "#json" .. #JSON end,
	JSONToTable = function( s ) local i = s and tonumber( s:match( "^#json(%d+)$" ) or "" ) return i and table.Copy( JSON[ i ] ) or nil end,
	AddNetworkString = function() end,
	TraceHull = function() return { Hit = false } end,
	TraceLine = function() return { Fraction = 1, Hit = false } end,
}
net = { Receive = function() end, Start = function() end, Broadcast = function() end, Send = function() end,
	WriteString = function() end, WriteBool = function() end, WriteUInt = function() end }
concommand = { Add = function( n, f ) _G[ "CMD_" .. n:gsub( "%W", "_" ) ] = f end, GetTable = function() return {} end }
cvars = { AddChangeCallback = function( n, f ) CVCB[ n ] = CVCB[ n ] or {} table.insert( CVCB[ n ], f ) end }
CVCB = {}

CV = {}
function SetCV( name, value )
	local old = CV[ name ]
	CV[ name ] = tostring( value )
	if old ~= CV[ name ] then for _, f in ipairs( CVCB[ name ] or {} ) do f( name, old, CV[ name ] ) end end
end
local function cvObject( name )
	return { GetBool = function() return tobool( CV[ name ] ) end, GetFloat = function() return tonumber( CV[ name ] ) or 0 end,
		GetInt = function() return math.floor( tonumber( CV[ name ] ) or 0 ) end, GetString = function() return CV[ name ] or "" end,
		GetDefault = function() return "" end }
end
HL2A.ConVars = setmetatable( {}, { __index = function( t, k ) local o = cvObject( k ) rawset( t, k, o ) return o end } )
HL2A.ClientConVars = {}
function RunConsoleCommand( name, ... ) if CV[ name ] ~= nil or HL2A_CV_KNOWN then SetCV( name, ( ... ) ) end CMDS = CMDS or {} CMDS[ #CMDS + 1 ] = { name, ... } end

GLOBALS = {}
for _, k in ipairs( { "Bool", "Int", "Float", "Vector", "String" } ) do
	_G[ "SetGlobal2" .. k ] = function( n, v ) GLOBALS[ n ] = v end
	_G[ "GetGlobal2" .. k ] = function( n, d ) if GLOBALS[ n ] == nil then return d end return GLOBALS[ n ] end
end

-- Entities and players -----------------------------------------------------------------------

ENTS = {}
local ENT = {}
ENT.__index = ENT
function MakeEnt( class, props )
	local e = setmetatable( props or {}, ENT )
	e.class, e.iv, e.nw = class, e.iv or {}, {}
	e.pos = e.pos or Vector( 0, 0, 0 )
	ENTS[ #ENTS + 1 ] = e
	return e
end
function ENT:GetClass() return self.class end
function ENT:GetName() return self.name or "" end
function ENT:GetPos() return self.pos end
function ENT:SetPos( p ) self.pos = p end
function ENT:GetInternalVariable( k ) return self.iv[ k ] end
function ENT:GetSpawnFlags() return self.spawnflags or 0 end
function ENT:WorldSpaceAABB() return self.mins or self.pos, self.maxs or self.pos end
function ENT:WorldSpaceCenter() return self.pos + Vector( 0, 0, 36 ) end
function ENT:Fire( input, param, delay ) FIRED = FIRED or {} FIRED[ #FIRED + 1 ] = self:GetName() .. "." .. input .. "(" .. tostring( param or "" ) .. ")" end
function ENT:Remove() self.valid = false end
function ENT:GetNW2Bool( k ) return self.nw[ k ] or false end
function ENT:SetNW2Bool( k, v ) self.nw[ k ] = v end
function ENT:GetNW2String( k ) return self.nw[ k ] or "" end
function ENT:SetNW2String( k, v ) self.nw[ k ] = v end
function ENT:GetModel() return self.model end

ents = {
	FindByClass = function( c ) local o = {} for _, e in ipairs( ENTS ) do if e.valid ~= false and e.class == c then o[ #o + 1 ] = e end end return o end,
	FindByName = function( n ) local o = {} for _, e in ipairs( ENTS ) do if e.valid ~= false and e.name == n then o[ #o + 1 ] = e end end return o end,
	GetAll = function() return ENTS end,
}

PLAYERS = {}
function MakePlayer( name, pos )
	local p = MakeEnt( "player", { name = name, pos = pos or Vector( 0, 0, 0 ) } )
	p.alive, p.health, p.armor, p.suit, p.weapons, p.ammo, p.god = true, 100, 0, true, {}, {}, false
	p.IsPlayer = function() return true end
	p.Alive = function( s ) return s.alive end
	p.Nick = function( s ) return s.name end
	p.IsBot = function() return false end
	p.SteamID64 = function( s ) return "7656" .. s.name end
	p.SteamID = function( s ) return "STEAM_" .. s.name end
	p.Team = function() return 1 end
	p.GetObserverMode = function() return 0 end
	p.Health = function( s ) return s.health end
	p.SetHealth = function( s, h ) s.health = h end
	p.GetMaxHealth = function() return 100 end
	p.SetMaxHealth = function() end
	p.Armor = function( s ) return s.armor end
	p.SetArmor = function( s, a ) s.armor = a end
	p.IsSuitEquipped = function( s ) return s.suit end
	p.EquipSuit = function( s ) s.suit = true end
	p.RemoveSuit = function( s ) s.suit = false end
	p.GetWeapons = function( s ) local o = {} for c, w in pairs( s.weapons ) do o[ #o + 1 ] = w end return o end
	p.HasWeapon = function( s, c ) return s.weapons[ c ] ~= nil end
	p.GetWeapon = function( s, c ) return s.weapons[ c ] end
	p.Give = function( s, c )
		local w = { class = c, c1 = -1, c2 = -1 }
		w.GetClass = function() return c end
		w.Clip1 = function( x ) return x.c1 end
		w.Clip2 = function( x ) return x.c2 end
		w.SetClip1 = function( x, v ) x.c1 = v end
		w.SetClip2 = function( x, v ) x.c2 = v end
		s.weapons[ c ] = w
		return w
	end
	p.GetActiveWeapon = function() return nil end
	p.SelectWeapon = function() end
	p.GetAmmo = function( s ) return s.ammo end
	p.SetAmmo = function( s, n, name ) s.ammo[ name ] = n end
	p.GetAmmoCount = function( s, id ) return s.ammo[ id ] or 0 end
	p.EyeAngles = function() return Angle( 0, 90, 0 ) end
	p.SetEyeAngles = function() end
	p.EyePos = function( s ) return s.pos + Vector( 0, 0, 64 ) end
	p.Crouching = function() return false end
	p.GetHull = function() return Vector( -16, -16, 0 ), Vector( 16, 16, 72 ) end
	p.WorldSpaceAABB = function( s ) return s.pos + Vector( -16, -16, 0 ), s.pos + Vector( 16, 16, 72 ) end
	p.GetVehicle = function() return nil end
	p.GodEnable = function( s ) s.god = true end
	p.GodDisable = function( s ) s.god = false end
	p.ScreenFade = function() end
	p.PrintMessage = function() end
	p.IsListenServerHost = function() return true end
	p.IsSuperAdmin = function() return true end
	PLAYERS[ #PLAYERS + 1 ] = p
	return p
end
player = {
	Iterator = function() local i = 0 return function() i = i + 1 if PLAYERS[ i ] then return i, PLAYERS[ i ] end end end,
	GetAll = function() return PLAYERS end,
	GetCount = function() return #PLAYERS end,
}
function Entity( i ) return PLAYERS[ i ] end

game = {
	SinglePlayer = function() return SINGLEPLAYER == true end,
	GetMap = function() return MAP or "d1_test_d" end,
	GetAmmoName = function( id ) return ( { [ 3 ] = "Pistol", [ 7 ] = "Buckshot" } )[ id ] end,
	GetGlobalState = function( n ) return GSTATE and GSTATE[ n ] or 0 end,
	SetGlobalState = function( n, v ) GSTATE = GSTATE or {} GSTATE[ n ] = v end,
	GetGlobalCounter = function() return 0 end,
	SetGlobalCounter = function() end,
	GetWorld = function() return nil end,
}
HL2A.MapPath = function() return game.GetMap() end
HL2A.Map = HL2A.MapPath
HL2A.ResolveSound = function( s ) return s end
OBS_MODE_NONE, TEAM_SPECTATOR, MASK_PLAYERSOLID, MASK_SOLID_BRUSHONLY = 0, 1002, 0, 0
SCREENFADE = { IN = 1, OUT = 2, PURGE = 16, STAYOUT = 8 }
HUD_PRINTCENTER, HUD_PRINTTALK = 4, 3
color_black = {}
function Color( r, g, b, a ) return { r = r, g = g, b = b, a = a } end
