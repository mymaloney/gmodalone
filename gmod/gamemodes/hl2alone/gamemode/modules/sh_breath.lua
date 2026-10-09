--[[
	Visible breath (amod_do_breathing, the Weather panel's "Show Players
	Breath"). As in the original: every 3-5 seconds the server tells each
	client to breathe (amod_do_breath), which puffs the fog_breath particle
	(particles/impact_fx.pcf) in front of the face and plays a faint
	player/breathe2.wav, a little louder while standing still.
]]

if SERVER then
	util.AddNetworkString( "hl2a.breath" )

	local function breathe()
		timer.Create( "hl2a.breath", math.random( 3, 5 ), 1, breathe )
		if not HL2A.ConVars.amod_do_breathing:GetBool() then return end
		if HL2A.MapPath():StartWith( "backgrounds/" ) then return end

		for _, ply in player.Iterator() do
			if ply:Alive() then
				net.Start( "hl2a.breath" )
				net.Send( ply )
			end
		end
	end

	hook.Add( "InitPostEntity", "hl2a.breath", function() breathe() end )
	return
end

local function breathe()
	local ply = LocalPlayer()
	if not IsValid( ply ) or not ply:Alive() or HL2A.Map() == "credits" or gui.IsGameUIVisible() then return end

	if ply:WaterLevel() < 3 then
		local ang = ply:EyeAngles()
		local pos = ply:EyePos() + ang:Forward() * 5 - ang:Up() * 5
		CreateParticleSystemNoEntity( "fog_breath", pos, ang )
	end

	-- Original: pitch 85-95, volume 0.02 while moving faster than 25 u/s, else 0.03
	local vol = ply:GetVelocity():Length() > 25 and 0.02 or 0.03
	ply:EmitSound( "player/breathe2.wav", 0, math.random( 85, 95 ), vol, CHAN_STATIC )
end

net.Receive( "hl2a.breath", breathe )
concommand.Add( "amod_do_breath", breathe, nil, "Breathe once (fog puff and sound)" )

hook.Add( "InitPostEntity", "hl2a.breath", function() PrecacheParticleSystem( "fog_breath" ) end )
