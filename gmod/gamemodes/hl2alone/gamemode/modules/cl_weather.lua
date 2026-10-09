--[[
	Client-side precipitation. Replaces the engine's func_precipitation-based
	rain from the original mod (which can't be spawned at runtime in GMod).

	Drops spawn in a radius around the player, only where a trace upward
	reaches the sky, so interiors stay dry. The ambience is in
	cl_weathersound.lua.
]]

local CV = HL2A.ConVars

local TYPES = {
	[ 1 ] = { mat = "particle/rain", speed = 1200, size = 1.2, len = 60, color = Color( 200, 210, 220 ), alpha = 120, rate = 1 },
	[ 2 ] = { mat = "particle/snow", speed = 120, size = 2, len = 0, color = Color( 255, 255, 255 ), alpha = 220, rate = 0.35, sway = 40 },
	[ 3 ] = { mat = "particle/snow", speed = 60, size = 1.5, len = 0, color = Color( 60, 55, 50 ), alpha = 200, rate = 0.25, sway = 25 },
}

local MAX_PER_FRAME = 40
local emitter
local accum = 0

local function skyAbove( pos )
	local tr = util.TraceLine( { start = pos, endpos = pos + Vector( 0, 0, 16384 ), mask = MASK_SOLID_BRUSHONLY } )
	if tr.StartSolid or not tr.HitSky then return nil end
	return tr.HitPos
end

local function onCollide( p, hitPos )
	p:SetDieTime( 0 )
	if math.random() > 0.25 or not CreateParticleSystemNoEntity then return end
	CreateParticleSystemNoEntity( CV.amod_rain_splash_particle_name:GetString(), hitPos, angle_zero )
end

local function spawnDrop( def, center, radius, splashes )
	local ang = math.Rand( 0, math.pi * 2 )
	local dist = radius * math.sqrt( math.random() )
	local base = center + Vector( math.cos( ang ) * dist, math.sin( ang ) * dist, 0 )

	local sky = skyAbove( base )
	if not sky then return end

	local pos = Vector( base.x, base.y, math.min( sky.z - 8, center.z + 600 ) )
	local p = emitter:Add( def.mat, pos )
	if not p then return end

	local vel = Vector( 0, 0, -def.speed )
	if def.sway then vel:Add( VectorRand() * def.sway ) end

	p:SetVelocity( vel )
	p:SetDieTime( 1200 / def.speed + 1 )
	p:SetStartAlpha( def.alpha )
	p:SetEndAlpha( def.alpha )
	p:SetStartSize( def.size )
	p:SetEndSize( def.size )
	p:SetColor( def.color.r, def.color.g, def.color.b )
	if def.len > 0 then
		p:SetStartLength( def.len )
		p:SetEndLength( def.len )
	end
	p:SetCollide( true )
	p:SetBounce( 0 )
	if def.len > 0 and splashes then p:SetCollideCallback( onCollide ) end
end

hook.Add( "Think", "hl2a.weather", function()
	if HL2A.StormFoxActive() then return end -- StormFox 2 draws the weather
	local kind = GetGlobal2Int( "hl2a.weather.type" )
	local def = TYPES[ kind ]
	local ply = LocalPlayer()

	if not def or not GetGlobal2Bool( "hl2a.weather.active" ) or not IsValid( ply ) then return end
	if GetGlobal2Bool( "hl2a.capture", false ) then return end -- cubemap capture (sv_graphs.lua)

	emitter = emitter or ParticleEmitter( vector_origin, false )

	-- r_raindensity 0.001 ~= 400 drops/sec
	local perSec = math.Clamp( GetGlobal2Float( "hl2a.weather.density" ) * 400000, 30, 1500 ) * def.rate
	accum = accum + perSec * FrameTime()

	local radius = GetGlobal2Float( "hl2a.weather.radius", 2000 )
	local center = ply:EyePos() + ply:GetVelocity() * 0.5
	local splashes = GetGlobal2Bool( "hl2a.weather.splashes" )

	local n = math.min( math.floor( accum ), MAX_PER_FRAME )
	accum = accum - math.floor( accum )
	for _ = 1, n do spawnDrop( def, center, radius, splashes ) end
end )
