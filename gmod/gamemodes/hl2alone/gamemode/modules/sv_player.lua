--[[
	Player setup: HL2 campaign loadout, movement speeds, god mode,
	jump/land view punches and the suit-gated flashlight toggle
	(rendering is in cl_flashlight.lua).
]]

local CV = HL2A.ConVars

-- Maps the campaign starts without the HEV suit (it's picked up in Kleiner's lab).
-- Only applied on a fresh spawn, not on a level transition.
HL2A.NoSuitMaps = {
	d1_trainstation_01_d = true,
	d1_trainstation_02_d = true,
	d1_trainstation_03_d = true,
	d1_trainstation_04_d = true,
	d1_trainstation_05_d = true,
}

local function applySpeeds( ply )
	ply:SetWalkSpeed( CV.hl2a_normspeed:GetFloat() )
	ply:SetSlowWalkSpeed( CV.hl2a_walkspeed:GetFloat() )
	ply:SetRunSpeed( CV.hl2a_sprintspeed:GetFloat() )
end

function GM:PlayerLoadout( ply )
	if CV.hl2a_sandbox_loadout:GetBool() then
		return self.BaseClass.PlayerLoadout( self, ply )
	end
	-- Campaign maps hand out weapons themselves
	return true
end

function GM:PlayerSpawn( ply, transition )
	self.BaseClass.PlayerSpawn( self, ply, transition )

	applySpeeds( ply )
	if CV.amod_enable_god:GetBool() then ply:GodEnable() end

	-- After dying: back at the last checkpoint with that kit (sv_checkpoints.lua)
	if HL2A.RestoreCheckpoint( ply ) then return end

	-- Multiplayer level change: health, suit, weapons and place carried over (sv_transitions.lua)
	if HL2A.RestoreTransitionCarry( ply ) then return end

	if not transition and HL2A.NoSuitMaps[ HL2A.Map() ] then
		ply:RemoveSuit()
	end
end

for _, name in ipairs( { "hl2a_normspeed", "hl2a_walkspeed", "hl2a_sprintspeed" } ) do
	cvars.AddChangeCallback( name, function()
		for _, ply in player.Iterator() do applySpeeds( ply ) end
	end, "hl2a.speed" )
end

cvars.AddChangeCallback( "amod_enable_god", function( _, _, new )
	for _, ply in player.Iterator() do
		if tobool( new ) then ply:GodEnable() else ply:GodDisable() end
	end
end, "hl2a.god" )

-- Flashlight: block the engine flashlight and keep our own state, rendered
-- client-side as a ProjectedTexture so it can flicker and lag.
function GM:PlayerSwitchFlashlight( ply, enabled )
	-- The engine flashlight never turns on, so a key press always arrives as
	-- enabled = true; enabled = false only comes from forced turn-offs.
	local cur = ply:GetNW2Bool( "hl2a.flashlight" )
	local on = enabled and not cur
	if on == cur or ( on and not ply:IsSuitEquipped() ) then return false end

	ply:SetNW2Bool( "hl2a.flashlight", on )
	ply:EmitSound( on and "HL2Player.FlashLightOn" or "HL2Player.FlashLightOff" )
	return false
end

hook.Add( "PlayerDeath", "hl2a.flashlight", function( ply )
	ply:SetNW2Bool( "hl2a.flashlight", false )
end )

hook.Add( "OnPlayerHitGround", "hl2a.landpunch", function( ply, inWater, onFloater, speed )
	if not CV.amod_land_punch_enable:GetBool() or inWater then return end
	if speed < CV.amod_land_zvel_min:GetFloat() then return end
	ply:ViewPunch( Angle( math.min( speed / 80, 8 ), 0, math.Rand( -1, 1 ) ) )
end )

hook.Add( "KeyPress", "hl2a.jumppunch", function( ply, key )
	if key ~= IN_JUMP or not CV.amod_jump_punch_enable:GetBool() then return end
	if not ply:OnGround() or ply:GetVelocity():Length2D() < CV.amod_jump_vel_min:GetFloat() then return end
	ply:ViewPunch( Angle( -2, 0, 0 ) )
end )

-- The engine ignores trigger_changelevel in multiplayer; sv_transitions.lua
-- takes over unless hl2a_mp_transitions is off
hook.Add( "PlayerInitialSpawn", "hl2a.spwarning", function( ply )
	if game.SinglePlayer() or CV.hl2a_mp_transitions:GetBool() then return end
	MsgN( "[HL2A] WARNING: hl2a_mp_transitions is off - level transitions won't work in multiplayer" )
	timer.Simple( 3, function()
		if IsValid( ply ) then
			ply:PrintMessage( HUD_PRINTTALK, "[HL2: Alone] Level transitions are off in multiplayer (hl2a_mp_transitions 0)." )
		end
	end )
end )
