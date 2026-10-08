"Options"
{
	"ViewSettings"
	{
		"title"			"View"
		"alternating"   "1"
		"items"
		{
			"DisableHud"
			{
				"text"			"Show Hud"
				"type"			"wheelywheel"
				"convar"		"hidehud"
				"options"
				{
					"8"		"Hide"
					"0"		"Show"
				}
			}
			"MirrorView"
			{
				"text"			"Mirror View"
				"type"			"wheelywheel"
				"convar"		"amod_mirrored"
				"options"
				{
					"1"		"enable"
					"0"		"disable"
				}
			}
			"Vignette"
			{
				"text"			"Enable Vignette"
				"type"			"wheelywheel"
				"convar"		"amod_vignette"
				"options"
				{
					"1"		"enable"
					"0"		"disable"
				}
			}
			"AddViewbobbing"
			{
				"text"			"Enable Viewbobbing"
				"type"			"wheelywheel"
				"convar"		"amod_viewbob_enabled"
				"options"
				{
					"1"		"enable"
					"0"		"disable"
				}
			}
			"EnableStandbob"
			{
				"text"			"Camera Bob When Standing"
				"type"			"wheelywheel"
				"convar"		"amod_standbob_enabled"
				"options"
				{
					"1"		"enable"
					"0"		"disable"
				}
			}
			"JumpViewbob"
			{
				"text"			"Punch View When Jumping"
				"type"			"wheelywheel"
				"convar"		"amod_jump_punch_enable"
				"options"
				{
					"1"		"enable"
					"0"		"disable"
				}
			}
			"LandViewbob"
			{
				"text"			"Punch View When Landing"
				"type"			"wheelywheel"
				"convar"		"amod_land_punch_enable"
				"options"
				{
					"1"		"enable"
					"0"		"disable"
				}
			}
		}
	}
	"FilterSettings"
	{
		"title"			"Filter"
		"alternating"   "1"
		"items"
		{
			"EpicFilter"
			{
				"text"			"Enable Epic Filter"
				"type"			"wheelywheel"
				"convar"		"amod_epic_filter"
				"options"
				{
					"1"		"enable"
					"0"		"disable"
				}
			}
			"FilterOnBrightness"
			{
				"text"			"Filter On Brightness (Fullscreen only)"
				"type"			"slideyslide"
				"convar"		"amod_filter_brightness_on"
				"depends_on"	"amod_filter_brightness_on"
				"min" 			"0"
				"max" 			"12"
				"step" 			"1"
			}
			"FilterOnExponent"
			{
				"text"			"Filter On Exponent (Fullscreen only)"
				"type"			"slideyslide"
				"convar"		"amod_filter_brightness_on_exp"
				"depends_on"	"amod_filter_brightness_on_exp"
				"min" 			"0"
				"max" 			"12"
				"step" 			"1"
			}
			"FilterOnExponent"
			{
				"text"			"Filter Off Brightness (Fullscreen only)"
				"type"			"slideyslide"
				"convar"		"amod_filter_brightness_off"
				"depends_on"	"amod_filter_brightness_off"
				"min" 			"0"
				"max" 			"10"
				"step" 			"1"
			}
		}
	}
	"FlashlightSettings"
	{
		"title"			"Flashlight"
		"alternating"   "1"
		"items"
		{
			"FlashlightStrength"
			{
				"text"			"Flashlight Strength"
				"type"			"wheelywheel"
				"convar"		"r_flashlightfar"
				"options"
				{
					"700"		"Low"
					"1250"		"Medium"
					"1875"		"High"
					"2500"		"Very High"
					"4000"		"Extremely High"
				}
			}
			"FlashlightFov"
			{
				"text"			"Flashlight Fov"
				"type"			"wheelywheel"
				"convar"		"r_flashlightfov"
				"options"
				{
					"35"	"Low"
					"45"	"Medium"
					"60"	"High"
					"75"	"Very High"
				}
			}
			"FlashlightLag"
			{
				"text"			"Enable Flashlight Lag When Swinging"
				"type"			"wheelywheel"
				"convar"		"amod_flashlightlag"
				"options"
				{
					"1"		"enable"
					"0"		"disable"
				}
			}
			"FlashlightFlicker"
			{
				"text"			"Enable Flashlight Flicker"
				"type"			"wheelywheel"
				"convar"		"amod_flashlightflicker"
				"options"
				{
					"1"		"enable"
					"0"		"disable"
				}
			}
		}
	}
	"Sound Settings"
	{
		"title"			"Sound"
		"alternating"   "1"
		"items"
		{
			"DisableFootsteps"
			{
				"text"			"Enable Footstep Sounds"
				"type"			"wheelywheel"
				"convar"		"sv_footsteps"
				"options"
				{
					"0"		"disable"
					"1"		"enable"
				}
			}
			"DisableSoundscapes"
			{
				"text"			"Disable Soundscapes"
				"type"			"wheelywheel"
				"convar"		"amod_soundscapes_disable"
				"options"
				{
					"1"		"true"
					"0"		"false"
				}
			}
			"DisableMusic"
			{
				"text"			"Disable In Map Music"
				"type"			"wheelywheel"
				"convar"		"amod_music_disable"
				"options"
				{
					"1"		"true"
					"0"		"false"
				}
			}
			"TransitionMusicThroughLevels"
			{
				"text" 			"Transition Music Through Levels"
				"type"			"wheelywheel"
				"convar"		"amod_songs_transition_through_levels"
				"options"
				{
					"1" 	"enable"
					"0"		"disable"
				}
			}
		}
	}
	"OtherSettings"
	{
		"title"			"Other"
		"alternating"   "1"
		"items"
		{
			"GodMode"
			{
				"text"			"Enable God Mode"
				"type"			"wheelywheel"
				"convar"		"amod_enable_god"
				"options"
				{
					"1"		"enable"
					"0"		"disable"
				}
			}
			"DayAfterNovaProspekt"
			{
				"text"			"Become Day After Nova Prospekt"
				"type"			"wheelywheel"
				"convar"		"amod_day"
				"options"
				{
					"1"		"enable"
					"0"		"disable"
				}
			}
			"DayForRavenholm"
			{
				"text"			"Become Day For Ravenholm"
				"type"			"wheelywheel"
				"convar"		"amod_day_ravenholm"
				"options"
				{
					"1"		"enable"
					"0"		"disable"
				}
			}
			"Ending"
			{
				"text"			"Mod Ending"
				"type"			"wheelywheel"
				"convar"		"amod_new_ending"
				"options"
				{
					"0"		"Mod Ending 1"
					"1"		"Mod Ending 2"
				}
			}
		}
	}
}