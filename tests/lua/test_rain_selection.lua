-- Which rain bed plays and how loud, as client.dll chose it (decoded table + inside/citadel rules),
-- checked against the mod's real scripts/soundscapes.txt
SERVER, CLIENT = false, true
HL2A.ConVars.hl2a_weather_ambience_volume = { GetFloat = function() return 1 end }
function Material() return {} end
function GetConVar() return { GetFloat = function() return 0.001 end } end
function LocalPlayer() return MakePlayer( "me" ) end
HL2A.ReadFile = function( rel ) if rel == "scripts/soundscapes.txt" then return REPO_READ( rel ) end end
HL2A.FindFiles = function() return { "scripts/soundscapes.txt" } end
GM_LOAD( "core/sh_keyvalues.lua" )
GM_LOAD( "modules/cl_weathersound.lua" )
local W, KV = HL2A.Weather, HL2A.KV

-- The parsed definition for a name, to compare against what was chosen
local defs = {}
for _, root in ipairs( KV.Parse( REPO_READ( "scripts/soundscapes.txt" ) ) ) do defs[ root.key:lower() ] = defs[ root.key:lower() ] or root.value end
local function chosen( kind, name )
	local rules, vol = W.LayerFor( kind, name )
	local text = rules and KV.Write( rules )
	for k, d in pairs( defs ) do if text == KV.Write( d ) then return k, vol end end
	return nil, vol
end

local f = ( 0.001 - 0.0002 ) / 0.0058 * 1.2 + 0.4 -- r_raindensity 0.001
local function near( a, b ) return math.abs( a - b ) < 1e-6 end

local name, vol = chosen( "rain", "d1_town.street" )
assert( name == "common.rain" and near( vol, 0.825 * f ), "outdoors: common.rain at 0.825" )
name, vol = chosen( "rain", "d1_trainstation.inside" )
assert( name == "common.rain.inside" and near( vol, 0.285 * f ), "'inside': indoor rain at 0.285" )
name, vol = chosen( "rain", "d3_citadel.inside_hall" )
assert( near( vol, 0.09 * f ), "inside the citadel: 0.09" )
name, vol = chosen( "rain", "d1_eli.inside_eli" )
assert( near( vol, 0.1 * f ), "table entry inside_eli: 0.1" )
name, vol = chosen( "snow", "d1_town.street" )
assert( name == "common.snowfall" and near( vol, 0.825 ), "snow ignores density" )
