--[[
	Console variables.

	The amod_* names and defaults come from the original mod
	(cfg/AloneMod_Config.txt and cfg/autoexec.cfg) so existing configs and
	map-fired commands keep working. hl2a_* variables are new to the port.

	Everything is archived + replicated: this is a single-player gamemode, so
	the listen-server host owns every setting.
]]

local FLAGS = { FCVAR_ARCHIVE, FCVAR_REPLICATED }

HL2A.ConVars = HL2A.ConVars or {}

local function cv( name, default, help )
	HL2A.ConVars[ name ] = CreateConVar( name, tostring( default ), FLAGS, help or "" )
end

-- Time of day / atmosphere
cv( "amod_day", 0, "1 = daytime variant of the map, 0 = night" )
cv( "amod_day_sky", "", "Override skybox used during the day" )
cv( "amod_night_sky", "", "Override skybox used at night" )
cv( "amod_sun_disable", 0 )
cv( "amod_fog_disabled", 0 )
cv( "hl2a_timeinfo_theme", "", "Sub-folder of resource/time_info to load (e.g. \"snowey coast\", \"hl2 beta\"); empty = default" )

-- Colour correction ("epic filter")
cv( "amod_epic_filter", 1 )
cv( "amod_epic_filter_day_filename", "scripts/colorcorrection/cc_daytime.raw" )
cv( "amod_epic_filter_night_filename", "scripts/colorcorrection/cc_epic_filter.raw" )
cv( "amod_epic_filter_day_intensity", 1 )
cv( "amod_epic_filter_night_intensity", 1 )
cv( "amod_saturation", 1, "Enable the saturation effect" )
-- The original strength is in materials/effects/view/saturation.vmt (custom shader); tune to match
cv( "hl2a_saturation_amount", 1.2, "Colour saturation when amod_saturation is on (1 = unchanged)" )

-- Vignette
cv( "amod_vignette", 0 )
cv( "amod_new_vignette_color_r", 0 )
cv( "amod_new_vignette_color_g", 0 )
cv( "amod_new_vignette_color_b", 0 )
cv( "amod_new_vignette_start_alpha", 200 )
cv( "amod_new_vignette_end_alpha", 0 )
cv( "amod_new_vignette_width_divisor", 4 )
cv( "amod_new_vignette_height_divisor", 4 )

-- View bob / punches (the original math is in client.dll; these are tuned approximations)
cv( "amod_viewbob_enabled", 1 )
cv( "amod_viewbob_scale_x", 0.03 )
cv( "amod_viewbob_scale_y", 0.02 )
cv( "amod_viewbob_scale_z", 0.03 )
cv( "amod_viewbob_speed_x", 8 )
cv( "amod_viewbob_speed_y", 3 )
cv( "amod_viewbob_speed_z", 3 )
cv( "amod_standbob_enabled", 1 )
cv( "amod_standbob_wait", 0 )
cv( "amod_jump_punch_enable", 0 )
cv( "amod_jump_vel_min", 0 )
cv( "amod_land_punch_enable", 0 )
cv( "amod_land_zvel_min", 300 )

-- Flashlight
cv( "amod_flashlightlag", 0 )
cv( "amod_flashlightlag_amt", 10 )
cv( "amod_flashlightflicker", 1 )
cv( "amod_flashlightflicker_brightness_min", 0.1 )
cv( "amod_flashlightflicker_brightness_max", 0.7 )
cv( "amod_flashlightflicker_duration_min", 0.3 )
cv( "amod_flashlightflicker_duration_max", 1.2 )
cv( "amod_flashlightflicker_time_interval_min", 0.03 )
cv( "amod_flashlightflicker_time_interval_max", 0.12 )
cv( "amod_flashlightflicker_wait_time_min", 30 )
cv( "amod_flashlightflicker_wait_time_max", 120 )
cv( "hl2a_flashlight_far", 1250, "Original: r_flashlightfar" )
cv( "hl2a_flashlight_fov", 60, "Original: r_flashlightfov" )
cv( "hl2a_flashlight_brightness", 1 )

-- Weather. amod_weather_override 0 = use the map's time_info "weather" block.
cv( "amod_weather_override", 0 )
cv( "amod_weather_type", 1, "0 = none, 1 = rain, 2 = snow, 3 = ash" )
cv( "amod_weather_do_in_intervals", 0 )
cv( "amod_weather_wait_min", 300 )
cv( "amod_weather_wait_max", 600 )
cv( "amod_weather_rain_density", 0.001 )
cv( "amod_weather_rain_splashes", 1 )
cv( "amod_weather_thunder", 0 )
cv( "amod_rain_splash_particle_name", "water_splash_01_droplets" )
cv( "hl2a_weather_enable", 0, "Master switch used when amod_weather_override is 1" )

-- Music
cv( "amod_music_disable", 0 )
cv( "amod_songs_transition_through_levels", 1 )
cv( "hl2a_music_volume", 1 )

-- Options panel extras
cv( "amod_mirrored", 0, "Flip the view left to right" )
cv( "amod_soundscapes_disable", 0 )
cv( "hl2a_hidehud", 0, "Don't draw the HUD (original: hidehud)" )
cv( "hl2a_nofootsteps", 0, "Mute footstep sounds (original: sv_footsteps 0)" )
cv( "hl2a_rollangle", 0, "Camera roll when strafing, 0-10 (original: sv_rollangle)" )
cv( "hl2a_achievement_notifications_disable", 0 )

-- Episode One countdowns (amod_core_timer entity)
cv( "amod_do_core_timer", 1 )
cv( "amod_do_citadel_timer", 1 )

-- Player
cv( "amod_enable_god", 0 )
-- Original mod set hl2_normspeed/hl2_walkspeed/hl2_sprintspeed in autoexec.cfg;
-- renamed because GMod may already define those with HL2's defaults.
cv( "hl2a_normspeed", 165, "Normal move speed (original: hl2_normspeed)" )
cv( "hl2a_walkspeed", 150, "+walk speed (original: hl2_walkspeed)" )
cv( "hl2a_sprintspeed", 260, "+speed sprint speed (original: hl2_sprintspeed)" )
cv( "hl2a_sandbox_loadout", 0, "Give the sandbox physgun/toolgun loadout on spawn (development)" )

function HL2A.IsDay()
	return HL2A.ConVars.amod_day:GetBool()
end
