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

local kv = setmetatable( {}, { __mode = "k" } ) -- entity -> captured keyvalues
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

local function collect()
	scapes, triggers = {}, {}
	for ent, values in pairs( kv ) do
		if IsValid( ent ) then
			local class = ent:GetClass()
			if CLASSES[ class ] then
				local name = values.soundscape
				if class == "env_soundscape_proxy" then
					local main = ents.FindByName( values.mainsoundscapename or "" )[ 1 ]
					name = main and kv[ main ] and kv[ main ].soundscape
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

local function update()
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
	timer.Create( "hl2a.soundscapes", INTERVAL, 0, update )
end )
