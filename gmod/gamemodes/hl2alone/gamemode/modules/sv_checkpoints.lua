--[[
	Checkpoints: dying puts you back where the map last autosaved, with what
	you had then.

	In the original (stock HL2 behaviour, nothing custom in its DLLs) death
	reloads the last autosave, which the maps make with logic_autosave and
	trigger_autosave. GMod has no such reload: you respawned at the map's
	start with nothing, which could softlock the campaign. Here every
	autosave the map makes (and one shortly after each map starts) records
	each player's place, health, armour, suit, weapons and ammo; after
	dying, a player comes back there with that kit.

	Unlike a real reload the world isn't rewound: enemies, doors and props
	stay as they are. hl2a_checkpoints 0 turns it off.
]]

local CV = HL2A.ConVars

local LEVEL_START_DELAY = 3     -- seconds after the first spawn: the map's starting checkpoint
local MIN_HEALTH = 25           -- never come back on the brink of death
local SPAWN_PROTECTION = 2      -- seconds of invulnerability after coming back
local POLL = 0.25

local checkpoint     -- { time, players = { [ply] = snapshot }, fallback = { pos, ang } }
local levelStartArmed = false
local checkpointsLive = false -- the map is running (not loading or shutting down)

local function enabled() return CV.hl2a_checkpoints:GetBool() end

--- Records every living player's state. why: shown in the console.
function HL2A.SaveCheckpoint( why )
	if not enabled() then return end
	local players, fallback = {}, nil
	for _, ply in player.Iterator() do
		if ply:Alive() and ply:GetObserverMode() == OBS_MODE_NONE then
			local s = HL2A.SnapshotPlayer( ply )
			s.pos = ply:GetPos()
			s.angles = ply:EyeAngles()
			local veh = ply:GetVehicle()
			if IsValid( veh ) then s.vehicle = veh end
			players[ ply ] = s
			fallback = fallback or { pos = s.pos, ang = s.angles }
		end
	end
	if not fallback then return end -- nobody alive: keep the previous checkpoint
	checkpoint = { time = CurTime(), players = players, fallback = fallback }
	MsgN( "[HL2A] checkpoint (" .. why .. ")" )
end

-- What the map does to autosave -------------------------------------------------------------

-- logic_autosave: Save now; SaveDangerous only if still alive after a moment
-- (HL2 discards a "dangerous" save if the player is about to die)
hook.Add( "AcceptInput", "hl2a.checkpoints", function( ent, input, activator, caller, value )
	if ent:GetClass() ~= "logic_autosave" then return end
	input = input:lower()
	if input == "save" then
		HL2A.SaveCheckpoint( "logic_autosave " .. ent:GetName() )
	elseif input == "savedangerous" then
		timer.Simple( tonumber( value ) or 1.5, function()
			for _, ply in player.Iterator() do
				if ply:Alive() and ply:Health() >= MIN_HEALTH then HL2A.SaveCheckpoint( "logic_autosave (dangerous)" ) return end
			end
		end )
	end
end )

-- trigger_autosave: saves once, when a player first touches it
local fired = {}
local function pollTriggers()
	if not enabled() then return end
	for _, trig in ipairs( ents.FindByClass( "trigger_autosave" ) ) do
		if not fired[ trig ] and trig:GetInternalVariable( "m_bDisabled" ) ~= true then
			local mins, maxs = trig:WorldSpaceAABB()
			for _, ply in player.Iterator() do
				if ply:Alive() then
					local pmins, pmaxs = ply:WorldSpaceAABB()
					if pmaxs.x >= mins.x and pmins.x <= maxs.x and pmaxs.y >= mins.y and pmins.y <= maxs.y
						and pmaxs.z >= mins.z and pmins.z <= maxs.z then
						fired[ trig ] = true
						HL2A.SaveCheckpoint( "trigger_autosave" )
						break
					end
				end
			end
		end
	end
end
timer.Create( "hl2a.checkpoints", POLL, 0, pollTriggers )

-- The trigger removes itself as it fires, maybe between two polls: catch that too
hook.Add( "EntityRemoved", "hl2a.checkpoints", function( ent )
	if not enabled() or not checkpointsLive or fired[ ent ] or ent:GetClass() ~= "trigger_autosave" then return end
	local mins, maxs = ent:WorldSpaceAABB()
	mins, maxs = mins - Vector( 32, 32, 32 ), maxs + Vector( 32, 32, 32 )
	for _, ply in player.Iterator() do
		if ply:Alive() and ply:GetPos():WithinAABox( mins, maxs ) then
			fired[ ent ] = true
			timer.Simple( 0, function() HL2A.SaveCheckpoint( "trigger_autosave" ) end )
			return
		end
	end
end )

-- The map's own starting point (after a level change has restored the player)
hook.Add( "PlayerSpawn", "hl2a.checkpoints.levelstart", function()
	if levelStartArmed then return end
	levelStartArmed = true
	timer.Simple( LEVEL_START_DELAY, function() HL2A.SaveCheckpoint( "level start" ) end )
end )

hook.Add( "InitPostEntity", "hl2a.checkpoints", function()
	checkpoint, fired, levelStartArmed = nil, {}, false
	checkpointsLive = true
end )
hook.Add( "ShutDown", "hl2a.checkpoints", function() checkpointsLive = false end )

-- Coming back --------------------------------------------------------------------------------

hook.Add( "PlayerDeath", "hl2a.checkpoints", function( ply )
	ply.hl2aBackToCheckpoint = true
end )

--- Called from GM:PlayerSpawn. Returns true if the player was put back at the checkpoint.
function HL2A.RestoreCheckpoint( ply )
	if not ply.hl2aBackToCheckpoint then return false end
	ply.hl2aBackToCheckpoint = nil
	if not enabled() or not checkpoint then return false end

	local s = checkpoint.players[ ply ]
	if s then
		HL2A.RestorePlayerState( ply, s )
		ply:SetHealth( math.max( s.health or 100, MIN_HEALTH ) )
	end
	local pos = s and s.pos or checkpoint.fallback.pos
	local ang = s and s.angles or checkpoint.fallback.ang

	-- Next tick, once the engine has put the player at a spawn point
	timer.Simple( 0, function()
		if not IsValid( ply ) or not ply:Alive() then return end
		local veh = s and s.vehicle
		if IsValid( veh ) and not IsValid( veh:GetDriver() ) then
			ply:EnterVehicle( veh ) -- back in the airboat / buggy
		else
			HL2A.PlacePlayer( ply, pos, ang )
		end
		if not CV.amod_enable_god:GetBool() then
			ply:GodEnable()
			timer.Simple( SPAWN_PROTECTION, function()
				if IsValid( ply ) and not CV.amod_enable_god:GetBool() then ply:GodDisable() end
			end )
		end
		ply:ScreenFade( SCREENFADE.IN, color_black, 1, 0 )
	end )
	return true
end

-- Commands -----------------------------------------------------------------------------------

local function host( ply ) return not IsValid( ply ) or ply:IsListenServerHost() or ply:IsSuperAdmin() end

concommand.Add( "hl2a_checkpoint", function( ply )
	if host( ply ) then HL2A.SaveCheckpoint( "by hand" ) end
end, nil, "Set a checkpoint here" )

concommand.Add( "hl2a_checkpoint_status", function( ply )
	if not host( ply ) then return end
	if not checkpoint then MsgN( "[HL2A] no checkpoint on this map yet" ) return end
	MsgN( string.format( "[HL2A] checkpoint %.0f s ago:", CurTime() - checkpoint.time ) )
	for p, s in pairs( checkpoint.players ) do
		MsgN( string.format( "  %s: %d hp, %d armour, %d weapons at %s%s", IsValid( p ) and p:Nick() or "?", s.health or 0,
			s.armor or 0, #( s.weapons or {} ), tostring( s.pos ), IsValid( s.vehicle ) and " (in a vehicle)" or "" ) )
	end
	local n = 0
	for _ in pairs( fired ) do n = n + 1 end
	MsgN( string.format( "  %d trigger_autosave(s) of %d reached", n, #ents.FindByClass( "trigger_autosave" ) ) )
end, nil, "Show the current checkpoint" )
