--[[
	Flashlight rendered as a ProjectedTexture so it can flicker
	(amod_flashlightflicker_*) and lag behind the view (amod_flashlightlag).
	The on/off state is set by GM:PlayerSwitchFlashlight in sv_player.lua.
]]

local CV = HL2A.ConVars

local light
local lagAng
local nextFlicker, flickerEnd, nextFlickerStep = 0, 0, 0
local flickerMul = 1

local function rand( minCv, maxCv )
	return math.Rand( CV[ minCv ]:GetFloat(), CV[ maxCv ]:GetFloat() )
end

local function removeLight()
	if IsValid( light ) then light:Remove() end
	light = nil
end

local function updateFlicker( now )
	if not CV.amod_flashlightflicker:GetBool() then flickerMul = 1 return end

	if nextFlicker == 0 then
		nextFlicker = now + rand( "amod_flashlightflicker_wait_time_min", "amod_flashlightflicker_wait_time_max" )
	end

	if now >= nextFlicker then
		flickerEnd = now + rand( "amod_flashlightflicker_duration_min", "amod_flashlightflicker_duration_max" )
		nextFlicker = flickerEnd + rand( "amod_flashlightflicker_wait_time_min", "amod_flashlightflicker_wait_time_max" )
	end

	if now < flickerEnd then
		if now >= nextFlickerStep then
			flickerMul = rand( "amod_flashlightflicker_brightness_min", "amod_flashlightflicker_brightness_max" )
			nextFlickerStep = now + rand( "amod_flashlightflicker_time_interval_min", "amod_flashlightflicker_time_interval_max" )
		end
	else
		flickerMul = 1
	end
end

hook.Add( "Think", "hl2a.flashlight", function()
	local ply = LocalPlayer()
	if not IsValid( ply ) or not ply:Alive() or not ply:GetNW2Bool( "hl2a.flashlight" ) then
		removeLight()
		lagAng = nil
		return
	end

	if not IsValid( light ) then
		light = ProjectedTexture()
		light:SetTexture( "effects/flashlight001" )
		light:SetEnableShadows( true )
		light:SetNearZ( 4 )
	end

	local eyeAng = ply:EyeAngles()
	if CV.amod_flashlightlag:GetBool() then
		lagAng = LerpAngle( math.min( 1, FrameTime() * CV.amod_flashlightlag_amt:GetFloat() ), lagAng or eyeAng, eyeAng )
	else
		lagAng = eyeAng
	end

	updateFlicker( CurTime() )

	-- Offset slightly right/down so the beam doesn't originate inside the camera
	local pos = ply:EyePos() + eyeAng:Right() * 6 - eyeAng:Up() * 4

	light:SetPos( pos )
	light:SetAngles( lagAng )
	light:SetFarZ( CV.hl2a_flashlight_far:GetFloat() )
	light:SetFOV( CV.hl2a_flashlight_fov:GetFloat() )
	light:SetBrightness( CV.hl2a_flashlight_brightness:GetFloat() * flickerMul )
	light:Update()
end )
