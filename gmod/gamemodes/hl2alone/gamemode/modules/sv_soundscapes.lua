--[[
	Tracks which soundscape each player is hearing, so the client can layer
	the matching rain / snow / thunder ambience over it (cl_weathersound.lua).

	The engine plays the soundscapes itself but doesn't tell Lua which one is
	active, so the selection rules of env_soundscape are mirrored here:
	the closest enabled soundscape whose radius contains the player and that
	has a clear brush-only line of sight wins; with none in range the last one
	keeps playing. env_soundscape_triggerable only counts while the player is
	inside a trigger_soundscape naming it; env_soundscape_proxy plays its
	MainSoundscapeName entity's soundscape from its own position.

	Networked as the player's NW2String "hl2a.soundscape".
]]

local CLASSES = { env_soundscape = true, env_soundscape_proxy = true, env_soundscape_triggerable = true }
local INTERVAL = 0.5

-- entity -> captured keyvalues. A plain table: with weak keys the garbage
-- collector could drop entries while a big map loads, leaving no soundscapes
-- (and the rain choosing outdoor rain everywhere)
local kv = {}
local scapes, triggers = {}, {}
local disabled = setmetatable( {}, { __mode = "k" } )
local current = setmetatable( {}, { __mode = "k" } ) -- player -> soundscape entity

hook.Add( "EntityKeyValue", "hl2a.soundscapes", function( ent, key, value )
	local class = ent:GetClass()
	if not CLASSES[ class ] and class ~= "trigger_soundscape" then return end
	kv[ ent ] = kv[ ent ] or {}
	kv[ ent ][ key:lower() ] = value
end )

hook.Add( "AcceptInput", "hl2a.soundscapes", function( ent, input )
	if not CLASSES[ ent:GetClass() ] then return end
	input = input:lower()
	if input == "enable" then disabled[ ent ] = nil
	elseif input == "disable" then disabled[ ent ] = true
	elseif input == "toggleenabled" then disabled[ ent ] = not disabled[ ent ] or nil end
end )

-- A keyvalue, read from the entity itself when possible (always available),
-- else from what EntityKeyValue captured
local function value( ent, key, internal )
	local v = internal and ent:GetInternalVariable( internal )
	if isstring( v ) and v ~= "" then return v end
	if isnumber( v ) then return tostring( v ) end
	if isbool( v ) then return v and "1" or "0" end
	return kv[ ent ] and kv[ ent ][ key ]
end

local function collect()
	scapes, triggers = {}, {}
	local list = {}
	for class in pairs( CLASSES ) do table.Add( list, ents.FindByClass( class ) ) end
	table.Add( list, ents.FindByClass( "trigger_soundscape" ) )
	for ent in pairs( kv ) do if IsValid( ent ) and not table.HasValue( list, ent ) then list[ #list + 1 ] = ent end end

	for _, ent in ipairs( list ) do
		if IsValid( ent ) then
			local class = ent:GetClass()
			local values = {
				soundscape = value( ent, "soundscape", class == "trigger_soundscape" and "m_SoundscapeName" or "m_soundscapeName" ),
				radius = value( ent, "radius", "m_flRadius" ),
				startdisabled = value( ent, "startdisabled", "m_bDisabled" ),
				mainsoundscapename = value( ent, "mainsoundscapename", "m_MainSoundscapeName" ),
			}
			if CLASSES[ class ] then
				local name = values.soundscape
				if class == "env_soundscape_proxy" then
					local main = ents.FindByName( values.mainsoundscapename or "" )[ 1 ]
					name = main and value( main, "soundscape", "m_soundscapeName" )
				end
				if name and name ~= "" then
					scapes[ #scapes + 1 ] = {
						ent = ent, name = name, triggerable = class == "env_soundscape_triggerable",
						radius = tonumber( values.radius ) or 128,
					}
					if values.startdisabled == "1" then disabled[ ent ] = true end
				end
			elseif class == "trigger_soundscape" and values.soundscape then
				triggers[ #triggers + 1 ] = { ent = ent, target = values.soundscape }
			end
		end
	end
end

local function inTriggerFor( ply, scape )
	local pos = ply:GetPos()
	local name = scape.ent:GetName()
	for _, t in ipairs( triggers ) do
		if IsValid( t.ent ) and t.target == name then
			local mins, maxs = t.ent:WorldSpaceAABB()
			if pos:WithinAABox( mins, maxs ) then return true end
		end
	end
	return false
end

local function audible( ply, scape, eye )
	if not IsValid( scape.ent ) or disabled[ scape.ent ] then return nil end
	if scape.triggerable and not inTriggerFor( ply, scape ) then return nil end

	local origin = scape.ent:GetPos()
	local dist = origin:Distance( eye )
	if scape.radius ~= -1 and dist > scape.radius then return nil end

	local tr = util.TraceLine( { start = origin, endpos = eye, mask = MASK_SOLID_BRUSHONLY } )
	if tr.Fraction < 1 or tr.StartSolid then return nil end
	return dist
end

local recollected = false

local function update()
	-- Nothing found at map start (entities not ready yet): look once more
	if #scapes == 0 and not recollected then
		recollected = true
		collect()
	end
	for _, ply in player.Iterator() do
		local eye = ply:EyePos()
		local best, bestDist

		for _, scape in ipairs( scapes ) do
			local dist = audible( ply, scape, eye )
			if dist and ( not bestDist or dist < bestDist ) then best, bestDist = scape, dist end
		end

		local cur = current[ ply ]
		if cur and disabled[ cur.ent ] then cur = nil end
		if best then cur = best end
		current[ ply ] = cur

		local name = cur and cur.name or ""
		if HL2A.ConVars.amod_soundscapes_disable:GetBool() then name = "" end
		if ply:GetNW2String( "hl2a.soundscape" ) ~= name then ply:SetNW2String( "hl2a.soundscape", name ) end
	end
end

hook.Add( "InitPostEntity", "hl2a.soundscapes.track", function()
	collect()
	MsgN( "[HL2A] soundscapes: tracking " .. #scapes .. " on this map" )
	timer.Create( "hl2a.soundscapes", INTERVAL, 0, update )
end )

concommand.Add( "hl2a_soundscapes_list", function( ply )
	if IsValid( ply ) and not ply:IsListenServerHost() then return end
	local eye = IsValid( ply ) and ply:EyePos() or vector_origin
	MsgN( "[HL2A] " .. #scapes .. " soundscapes tracked on this map (current: '"
		.. ( IsValid( ply ) and ply:GetNW2String( "hl2a.soundscape" ) or "" ) .. "'):" )
	for _, sc in ipairs( scapes ) do
		if IsValid( sc.ent ) then
			MsgN( string.format( "  %-40s radius %5d  %s%s  %5d units away%s", sc.name, sc.radius,
				disabled[ sc.ent ] and "disabled" or "enabled", sc.triggerable and " (trigger)" or "",
				sc.ent:GetPos():Distance( eye ), IsValid( ply ) and audible( ply, sc, eye ) and "  AUDIBLE" or "" ) )
		end
	end
end, nil, "List the map's soundscapes, which are enabled, and which you can hear" )
