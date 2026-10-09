--[[
	Options panel support shared by both realms: the settings the panel may
	change (cl_options.lua sends them, sv_options.lua applies them) and the
	footstep mute.
]]

-- ConVars the options panel is allowed to set
HL2A.OptionConVars = {
	hl2a_nofootsteps = true, hl2a_hidehud = true, amod_mirrored = true, amod_vignette = true,
	amod_saturation = true, amod_viewbob_enabled = true, amod_standbob_enabled = true,
	amod_jump_punch_enable = true, amod_land_punch_enable = true, hl2a_rollangle = true,
	amod_epic_filter = true, hl2a_flashlight_far = true, hl2a_flashlight_fov = true,
	amod_flashlightflicker = true, amod_flashlightlag = true, amod_enable_god = true,
	amod_soundscapes_disable = true, amod_music_disable = true,
	amod_songs_transition_through_levels = true, amod_do_citadel_timer = true,
	amod_do_core_timer = true, hl2a_achievement_notifications_disable = true,
	amod_weather_thunder = true, amod_do_breathing = true,
	amod_filter_brightness_on = true, amod_filter_brightness_on_exp = true, amod_filter_brightness_off = true,
}

hook.Add( "PlayerFootstep", "hl2a.nofootsteps", function()
	if HL2A.ConVars.hl2a_nofootsteps:GetBool() then return true end
end )
