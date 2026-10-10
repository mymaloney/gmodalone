-- Server settings changed this session come back after a map change resets them
HL2A_CV_KNOWN = true
HL2A.ConVars = { hl2a_sandbox_tools = nil }
local function cv( n ) return { GetString = function() return CV[ n ] or "" end, GetBool = function() return tobool( CV[ n ] ) end } end
CV.hl2a_sandbox_tools = "0"
HL2A.ConVars = { hl2a_sandbox_tools = cv( "hl2a_sandbox_tools" ) }
GM_LOAD( "modules/sv_settings.lua" )
local P = MakePlayer( "p" )
hook.Run( "PlayerInitialSpawn", P )
Tick( 7 ) -- settle window over
SetCV( "hl2a_sandbox_tools", "1" ) -- the player turns it on

-- map change: Lua restarts, the value comes back as the default
local files = FILES
HOOKS, TIMERS, ONCE, CVCB = {}, {}, {}, {}
CV.hl2a_sandbox_tools = "0"
FILES = files
local published = 0
GM_LOAD( "modules/sv_settings.lua" )
hook.Add( "HL2A_PublishSettings", "test", function() published = published + 1 end )
Tick( 0.1 )
assert( CV.hl2a_sandbox_tools == "1", "restored before the map runs" )
hook.Run( "PlayerInitialSpawn", P )
CV.hl2a_sandbox_tools = "0" -- the client's Lua start resets it again
Tick( 2 )
assert( CV.hl2a_sandbox_tools == "1", "reset during the settle window undone" )
assert( published > 0, "settings re-broadcast" )
