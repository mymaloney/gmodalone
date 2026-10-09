--[[
	View effects: walk bob, idle "stand bob" sway, saturation and vignette.

	The original implementations live in client.dll; the formulas here are
	approximations driven by the same convars, so expect to tune them.
]]

local CV = HL2A.ConVars

local phase = 0
local lastMove = 0
local bobWeight = 0

function GM:CalcView( ply, origin, angles, fov, znear, zfar )
	local view = self.BaseClass.CalcView( self, ply, origin, angles, fov, znear, zfar )

	if not ply:Alive() or ply:InVehicle() or ply:ShouldDrawLocalPlayer() or IsValid( ply:GetObserverTarget() ) then
		return view
	end

	local speed = ply:OnGround() and ply:GetVelocity():Length2D() or 0
	local now = CurTime()
	local dt = FrameTime()

	if speed > 10 then lastMove = now end

	-- Walk bob, scaled by speed relative to normal walking speed
	bobWeight = math.Approach( bobWeight, math.min( speed / CV.hl2a_normspeed:GetFloat(), 1.5 ), dt * 4 )
	phase = phase + dt * ( speed / CV.hl2a_normspeed:GetFloat() )

	if CV.amod_viewbob_enabled:GetBool() and bobWeight > 0 then
		local k = bobWeight * CV.hl2a_normspeed:GetFloat() / 10
		local sx = math.sin( phase * CV.amod_viewbob_speed_x:GetFloat() )
		local sy = math.sin( phase * CV.amod_viewbob_speed_y:GetFloat() * 2 )
		local sz = math.abs( math.sin( phase * CV.amod_viewbob_speed_z:GetFloat() ) )

		view.angles.r = view.angles.r + sx * CV.amod_viewbob_scale_x:GetFloat() * k
		view.angles.p = view.angles.p + sy * CV.amod_viewbob_scale_y:GetFloat() * k
		view.origin = view.origin - Vector( 0, 0, sz * CV.amod_viewbob_scale_z:GetFloat() * k )
	end

	-- Strafe roll, like HL2's sv_rollangle (sv_rollspeed 200)
	local rollAngle = CV.hl2a_rollangle:GetFloat()
	if rollAngle > 0 then
		local side = ply:GetVelocity():Dot( angles:Right() )
		view.angles.r = view.angles.r + math.Clamp( side / 200, -1, 1 ) * rollAngle
	end

	-- Breathing sway while standing still
	if CV.amod_standbob_enabled:GetBool() and now - lastMove > CV.amod_standbob_wait:GetFloat() then
		local w = math.Clamp( ( now - lastMove - CV.amod_standbob_wait:GetFloat() ) / 2, 0, 1 ) * ( 1 - math.min( bobWeight, 1 ) )
		view.angles.p = view.angles.p + math.sin( now * 0.9 ) * 0.35 * w
		view.angles.y = view.angles.y + math.sin( now * 0.45 ) * 0.25 * w
	end

	-- Effects panel: claustrophobia fov, camera editor (cl_effects.lua)
	if HL2A.Effects and HL2A.Effects.CalcView then HL2A.Effects.CalcView( ply, view ) end

	return view
end

-- Screen-space ----------------------------------------------------------------

local gradL, gradR = Material( "vgui/gradient-l" ), Material( "vgui/gradient-r" )
local gradU, gradD = Material( "vgui/gradient-u" ), Material( "vgui/gradient-d" )

hook.Add( "RenderScreenspaceEffects", "hl2a.view", function()
	local sat = CV.amod_saturation:GetBool() and CV.hl2a_saturation_amount:GetFloat() or 1
	if sat ~= 1 then
		DrawColorModify( {
			[ "$pp_colour_addr" ] = 0, [ "$pp_colour_addg" ] = 0, [ "$pp_colour_addb" ] = 0,
			[ "$pp_colour_brightness" ] = 0, [ "$pp_colour_contrast" ] = 1,
			[ "$pp_colour_colour" ] = sat,
			[ "$pp_colour_mulr" ] = 0, [ "$pp_colour_mulg" ] = 0, [ "$pp_colour_mulb" ] = 0,
		} )
	end
end )

hook.Add( "HUDPaintBackground", "hl2a.vignette", function()
	if not CV.amod_vignette:GetBool() then return end

	local w, h = ScrW(), ScrH()
	local bw = w / math.max( CV.amod_new_vignette_width_divisor:GetFloat(), 1 )
	local bh = h / math.max( CV.amod_new_vignette_height_divisor:GetFloat(), 1 )
	local a = CV.amod_new_vignette_start_alpha:GetFloat()

	surface.SetDrawColor( CV.amod_new_vignette_color_r:GetInt(), CV.amod_new_vignette_color_g:GetInt(),
		CV.amod_new_vignette_color_b:GetInt(), a )

	-- TODO: amod_new_vignette_end_alpha (gradients currently fade to 0)
	surface.SetMaterial( gradL ) surface.DrawTexturedRect( 0, 0, bw, h )
	surface.SetMaterial( gradR ) surface.DrawTexturedRect( w - bw, 0, bw, h )
	surface.SetMaterial( gradU ) surface.DrawTexturedRect( 0, 0, w, bh )
	surface.SetMaterial( gradD ) surface.DrawTexturedRect( 0, h - bh, w, bh )
end )

-- Set by sv_timers.lua while the countdown-expired fade plays
-- Hidden by the "Dont Draw The Hud" option, or by sv_timers.lua during the countdown-expired fade
hook.Add( "HUDShouldDraw", "hl2a.hidehud", function( name )
	if name == "CHudGMod" or name == "CHudChat" then return end
	if CV.hl2a_hidehud:GetBool() then return false end
	if IsValid( LocalPlayer() ) and LocalPlayer():GetNW2Bool( "hl2a.hidehud" ) then return false end
end )
