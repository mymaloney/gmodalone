--[[
	Console variables.

	The amod_* names and defaults come from the original mod
	(cfg/AloneMod_Config.txt and cfg/autoexec.cfg) so existing configs and
	map-fired commands keep working. hl2a_* variables are new to the port.

	Settings the server uses are archived + replicated (the single-player
	host owns them). Settings only the client reads (view effects,
	flashlight look, music, mirror ...) are plain client convars: GMod can
	leave a Lua-created replicated convar stale on the client after a map
	load until it changes, which broke mirror mode until it was toggled.
]]

local FLAGS = { FCVAR_ARCHIVE, FCVAR_REPLICATED }

-- Prefixes of client-only settings (never read by server code)
local CLIENT_ONLY = {
	"amod_fog_disabled", "amod_saturation", "hl2a_saturation_amount", "amod_vignette", "amod_new_vignette_",
	"amod_viewbob_", "amod_standbob_", "amod_flashlight", "hl2a_flashlight_", "amod_music_disable",
	"amod_songs_transition_through_levels", "hl2a_music_volume", "amod_mirrored", "hl2a_hidehud",
	"hl2a_rollangle", "hl2a_achievement_notifications_disable", "hl2a_bloom", "hl2a_lightning_bolts", "hl2a_weather_ambience_", "hl2a_soundscape_debug", "hl2a_perf", "amod_new_ending", "r_clouds_", "r_stars_", "r_horizonfog_",
	"amod_filter_brightness_", "hl2a_screenfilter",
	"amod_view_", "amod_camera_", "amod_blur_amount", "amod_lensdirt_", "amod_lighting_debug", "amod_effects_",
	"hl2a_effects_", "hl2a_noir", "hl2a_hide_viewmodel", "hl2a_viewmodel_fov", "hl2a_claustrophobia_fov", "hl2a_pitch_",
}

HL2A.ConVars = HL2A.ConVars or {}
HL2A.ClientConVars = HL2A.ClientConVars or {}

local function isClientOnly( name )
	for _, p in ipairs( CLIENT_ONLY ) do
		if name:StartWith( p ) then return true end
	end
	return false
end

local function cv( name, default, help )
	if isClientOnly( name ) then
		HL2A.ClientConVars[ name ] = true
		if CLIENT then HL2A.ConVars[ name ] = CreateClientConVar( name, tostring( default ), true, false, help or "" ) end
		return
	end
	HL2A.ConVars[ name ] = CreateConVar( name, tostring( default ), FLAGS, help or "" )
end

-- Time of day / atmosphere
-- Daytime (amod_day) isn't ported: with the maps' baked night lighting it
-- can't look right, so it's being handled as a separate project.
cv( "amod_night_sky", "", "Override the map's skybox" )
cv( "hl2a_sky_upscaled", 1, "Use the mod's upscaled copies of night skies (materials/skybox/upscaled/) where there is one" )
cv( "amod_sun_disable", 0 )
cv( "amod_fog_disabled", 0 )
cv( "hl2a_timeinfo_theme", "", "Sub-folder of resource/time_info to load (e.g. \"snowey coast\", \"hl2 beta\"); empty = default" )

-- Colour correction ("epic filter")
cv( "amod_epic_filter", 1 )
-- Effects panel, view page (cl_effects.lua). Names/defaults from client.dll;
-- hl2a_* ones replace engine convars the original set (r_drawviewmodel,
-- viewmodel_fov, fov_desired, cl_pitchdown/up) or had no convar (noir).
cv( "hl2a_hide_viewmodel", 0 )
cv( "hl2a_noir", 0, "Black and white view" )
cv( "amod_view_lense_dirt", 0 )
cv( "amod_view_bodycam", 0, "Old TV / bodycam overlay" )
cv( "amod_view_binoculars", 0, "Blue tinted TV overlay" )
cv( "amod_view_blur", 0 )
cv( "amod_blur_amount", 1 )
-- Lens dirt shader settings (defaults from the mod's game_shader_dx9.dll)
cv( "amod_lensdirt_intensity", 1 )
cv( "amod_lensdirt_alpha", 0.775 )
cv( "amod_view_square", 0, "Cinematic black boxes" )
cv( "amod_view_square_width", 0.375 )
cv( "amod_view_square_height", 0.2 )
cv( "amod_view_claustrophobia", 0 )
cv( "amod_view_claustrophobia_amt", 5, "View aspect ratio while claustrophobic" )
cv( "hl2a_claustrophobia_fov", 100 )
cv( "hl2a_viewmodel_fov_override", 0 )
cv( "hl2a_viewmodel_fov", 54 )
for i = 1, 8 do cv( "amod_view_filter_video" .. i, 0 ) end
cv( "amod_camera_cinematic", 0, "Camera editor: smoothing, offsets and pitch limits" )
cv( "amod_camera_cinematic_fix", 0, "Viewmodel follows the smoothed camera" )
cv( "amod_camera_cinematic_lag_angles", 0 )
cv( "amod_camera_cinematic_lag_angles_amt", 0.1 )
cv( "amod_camera_cinematic_lag_origin", 0 )
cv( "amod_camera_cinematic_lag_origin_amt", 0.1 )
cv( "amod_view_override_xyz_amt", "0 0 0", "Camera offset: forward right up" )
cv( "amod_view_override_pyr_amt", "0 0 0", "Camera angle offset: pitch yaw roll" )
cv( "hl2a_pitch_down", 89 )
cv( "hl2a_pitch_up", 89 )
cv( "amod_lighting_debug", 0 )
cv( "hl2a_effects_autoload", 0, "Load the autoload presets on every map instead of keeping the current effects" )
cv( "amod_effects_panel_autoload_files", "", "Presets/folders to autoload, separated by ;" )

-- Post-processing master switch (F2): off hides the colour grade, the Faded
-- curve, saturation, vignette, bloom and the panel's screen effects
cv( "hl2a_postprocess", 1, "Post-processing on/off (F2)" )

-- Screen filter (cl_screenfilter.lua; original TAB key, here F2)
cv( "hl2a_screenfilter", 0, "Screen filter on (Amod_ToggleFilter / F2)" )
cv( "amod_filter_brightness_on", 12, "Screen filter on: brightness, 0-12" )
cv( "amod_filter_brightness_on_exp", 12, "Screen filter on: brightness exponent, 0-12" )
cv( "amod_filter_brightness_off", 4, "Screen filter off: brightness, 0-10" )
cv( "amod_epic_filter_night_filename", "scripts/colorcorrection/cc_epic_filter.raw" )
cv( "amod_epic_filter_night_intensity", 1 )
cv( "amod_saturation", 1, "Enable the saturation effect" )
-- The original strength is in materials/effects/view/saturation.vmt (custom shader); tune to match
cv( "hl2a_saturation_amount", 1.4, "Colour saturation when amod_saturation is on (1 = unchanged; the mod's shader default was 1.4)" )

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
cv( "hl2a_flashlight_shadows", 2, "Flashlight shadow quality: 0 off, 1 low, 2 medium, 3 high, 4 ultra (resolution changes need a restart)" )

-- Weather. amod_weather_override 0 = use the map's time_info "weather" block.
cv( "amod_weather_override", 0 )
cv( "amod_weather_type", 1, "0 = none, 1 = rain, 2 = snow, 3 = ash" )
cv( "amod_weather_do_in_intervals", 0 )
cv( "amod_weather_wait_min", 300 )
cv( "amod_weather_wait_max", 600 )
cv( "amod_weather_rain_density", 0.001 )
cv( "amod_weather_rain_splashes", 1 )
cv( "hl2a_perf", 0, "On-screen readout of what the gamemode costs per frame" )
cv( "hl2a_soundscape_debug", 0, "Print each soundscape change and the rain ambience it picks" )
cv( "hl2a_weather_ambience_volume", 1, "Rain and snow ambience volume (1 = the original mod's levels)" )
cv( "amod_weather_thunder", 0, "Thunder sounds while it rains (the soundscape's ThunderSoundscape, default common.thunder)" )
cv( "hl2a_lightning_bolts", 1, "Show lightning bolts in the sky with closer thunder" )
cv( "amod_do_breathing", 0, "Show the player's breath every few seconds" )
cv( "amod_rain_splash_particle_name", "water_splash_01_droplets" )
cv( "hl2a_weather_enable", 0, "Master switch used when amod_weather_override is 1" )
cv( "amod_weather_snow_show_on_maps", 0, "Snow-covered map materials (maps/snow_materials/<map>.smf) when amod_weather_override is 1" )

-- Music
cv( "amod_music_disable", 0 )
cv( "amod_songs_transition_through_levels", 1 )
cv( "hl2a_music_volume", 1 )

-- Options panel extras
cv( "amod_new_ending", 0, "Episode 2 outro video: 0 = Ending 1, 1 = Ending 2" )
-- Clouds / stars / horizon fog (cl_sky.lua): the player's side of the
-- per-map time_info settings. Original names; the mod's config had the
-- enables on.
cv( "r_clouds_enable", 1 )
cv( "r_clouds_color_override", 0 )
cv( "r_clouds_red_override", 255 )
cv( "r_clouds_green_override", 255 )
cv( "r_clouds_blue_override", 255 )
cv( "r_stars_enable", 1 )
cv( "r_stars_force", 0, "Stars on every map" )
cv( "r_horizonfog_enable", 1 )
cv( "hl2a_bloom", 1, "Per-map bloom from time_info (BloomEnabled maps only)" )
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
cv( "hl2a_sandbox_tools", 0, "Sandbox hints, spawn menu (Q), context menu (C) and noclip" )
cv( "hl2a_checkpoints", 1, "After dying, come back where the map last autosaved, with what you had then" )
cv( "hl2a_stormfox", 1, "With StormFox 2 installed: 1 = StormFox handles weather, sky and time (fed each map's settings); 0 = the port's own, StormFox off" )
cv( "hl2a_stormfox_sky", 0, "With StormFox 2: 1 = its sky, sun and moon; 0 = the maps' own night sky (clouds, stars, horizon)" )
cv( "hl2a_stormfox_fog", 0, "With StormFox 2: 1 = StormFox's fog instead of the maps' own" )
cv( "hl2a_stormfox_time", "23:30", "With StormFox 2: the time of night it's set to" )
cv( "hl2a_stormfox_time_flow", 0, "With StormFox 2: 1 = let time run instead of staying at night" )
cv( "hl2a_stormfox_maplight", 0, "With StormFox 2: 1 = let it relight the maps (they have baked night lighting)" )
cv( "hl2a_sandbox_loadout", 0, "Give the sandbox physgun/toolgun loadout on spawn (development)" )

-- Multiplayer level transitions (sv_transitions.lua)
cv( "hl2a_mp_transitions", 1, "Multiplayer: change level when the whole party gathers at a level exit" )
cv( "hl2a_mp_gather_radius", 768, "Multiplayer: how close to a level exit (units, from its edge) every player must be" )
cv( "hl2a_mp_exit_reach", 128, "Multiplayer: how close to a level exit (units, from its edge) counts as reaching it" )
cv( "hl2a_mp_transition_delay", 3, "Multiplayer: countdown once everyone has gathered" )
cv( "hl2a_mp_gather_timeout", 0, "Multiplayer: seconds before a scripted level change goes ahead without stragglers (0 = wait)" )
