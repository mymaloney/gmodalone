"resource/vgui base/SoundscapeEditorSettings.res"
{
	"SoundscapeData"
	{
		"Data"
		{
			//dsp
			"dsp"
			{
				"DisplayName" "DSP Effect Type:"
				"Type" "TYPE_COMBOBOX"
				
				"ComboBox_NumKvToSkip" "0"
				"ComboBox_UseFirstChild" "0"
				"ComboBox_DefaultSelected" "0"
				"ComboBox_KeyValues"
				{
					"Normal (off)"			"0"
					"Generic"				"1"
					"Metal Small"			"2"
					"Metal Medium"			"3"
					"Metal Large"			"4"
					"Tunnel Small"			"5"
					"Tunnel Medium"			"6"
					"Tunnel Large"			"7"
					"Chamber Small"			"8"
					"Chamber Medium"		"9"
					"Chamber Large"			"10"
					"Bright Small"			"11"
					"Bright Medium"			"12"
					"Bright Large"			"13"
					"Water 1"				"14"
					"Water 2"				"15"
					"Water 3"				"16"
					"Concrete Small"		"17"
					"Concrete Medium"		"18"
					"Concrete Large"		"19"
					"Big 1"					"20"
					"Big 2"					"21"
					"Big 3"					"22"
					"Cavern Small"			"23"
					"Cavern Medium"			"24"
					"Cavern Large"			"25"
					"Weirdo 1"				"26"
					"Weirdo 2"				"27"
					"Weirdo 3"				"28"
				}
			}
			"dsp_volume"
			{
				"DisplayName" "DSP Volume:"
				"Type" "TYPE_SLIDER"
					
				"Slider_MinValue" "0"
				"Slider_MaxValue" "100"
				"Slider_DefaultValue" "1"
				"Slider_Divisor" "1"
			}
			
			//soundmixer
			"Soundmixer"
			{
				"DisplayName" "Soundmixer:"
				"Type" "TYPE_COMBOBOX"
				
				"ComboBox_NumKvToSkip" "1"		//always skip the 1st KV as it always should be GROUPRULES
				"ComboBox_UseFirstChild" "0"
				"ComboBox_DefaultSelected" "0"
				"ComboBox_Filename" "scripts/soundmixers.txt"
			}
			
			//rain
			"RainSoundscape"
			{
				"DisplayName" "Rain Soundscape:"
				"Type" "TYPE_CHOOSE_SOUND"
				
				"ChooseSound_IsSoundscape" "1"
				"ChooseSound_DefaultSound" "%USE_DEFAULT%"
				"ChooseSound_SupportsDefaultValue" "1"
			}
			"RainVolume"
			{
				"DisplayName" "Rain Volume:"
				"Type" "TYPE_SLIDER"
					
				"Slider_MinValue" "0"
				"Slider_MaxValue" "101"
				"Slider_DefaultValue" "101"
				"Slider_Divisor" "100"
				"Slider_DontSaveValue" "101"
			}
			
			//snow
			"SnowSoundscape"
			{
				"DisplayName" "Snow Soundscape:"
				"Type" "TYPE_CHOOSE_SOUND"
				
				"ChooseSound_IsSoundscape" "1"
				"ChooseSound_DefaultSound" "%USE_DEFAULT%"
				"ChooseSound_SupportsDefaultValue" "1"
			}
			"SnowVolume"
			{
				"DisplayName" "Snow Volume:"
				"Type" "TYPE_SLIDER"
					
				"Slider_MinValue" "0"
				"Slider_MaxValue" "101"
				"Slider_DefaultValue" "101"
				"Slider_Divisor" "100"
				"Slider_DontSaveValue" "101"
			}
		}
	}
	"EventData"
	{
		//defaults
		"Defaults"
		{
			//all soundscapes use this
			"PlaySoundscapeData"
			{
				"Data"
				{	
					//position
					"position"
					{
						"DisplayName" "Position:"
						"Type" "TYPE_COMBOBOX"
						
						"ComboBox_NumKvToSkip" "0"
						"ComboBox_UseFirstChild" "0"
						"ComboBox_DefaultSelected" "0"
						"ComboBox_KeyValues"
						{
							"Play Everywhere"	"%RESERVED_NO_OUTPUT%"
							"Random Position"	"Random"
							"Position 0"		"0"
							"Position 1"		"1"
							"Position 2"		"2"
							"Position 3"		"3"
							"Position 4"		"4"
							"Position 5"		"5"
							"Position 6"		"6"
							"Position 7"		"7"
							"Position 8"		"8"
							"Position 9"		"9"
							"Position 10"		"10"
							"Position 11"		"11"
							"Position 12"		"12"
							"Position 13"		"13"
							"Position 14"		"14"
							"Position 15"		"15"
							"Position 16"		"16"
							"Position 17"		"17"
							"Position 18"		"18"
							"Position 19"		"19"
							"Position 20"		"20"
							"Position 21"		"21"
							"Position 22"		"22"
							"Position 23"		"23"
							"Position 24"		"24"
							"Position 25"		"25"
							"Position 26"		"26"
							"Position 27"		"27"
							"Position 28"		"28"
							"Position 29"		"29"
							"Position 30"		"30"
							"Position 31"		"31"
						}
					}
				}
			}
			
			//the other soundscape events
			"PlayOtherData"
			{
				"Data"
				{
					//soundlevel
					"soundlevel"
					{
						"DisplayName" "Sound Level:"
						"Type" "TYPE_COMBOBOX"
						
						"ComboBox_NumKvToSkip" "0"
						"ComboBox_UseFirstChild" "0"
						"ComboBox_DefaultSelected" "0"
						"ComboBox_KeyValues"
						{
							"Default Soundlevel"	"%RESERVED_NO_OUTPUT%"
							"50 Decibels"			"SNDLVL_50dB"
							"55 Decibels"			"SNDLVL_55dB"
							"Idle Level"			"SNDLVL_IDLE"
							"Talking Level"			"SNDLVL_TALKING"
							"60 Decibels"			"SNDLVL_60dB"
							"65 Decibels"			"SNDLVL_65dB"
							"Static Level"			"SNDLVL_STATIC"
							"70 Decibels"			"SNDLVL_70dB"
							"Normal Level"			"SNDLVL_NORM"
							"75 Decibels"			"SNDLVL_75dB"
							"80 Decibels"			"SNDLVL_80dB"
							"85 Decibels"			"SNDLVL_85dB"
							"90 Decibels"			"SNDLVL_90dB"
							"95 Decibels"			"SNDLVL_95dB"
							"100 Decibels"			"SNDLVL_100dB"
							"105 Decibels"			"SNDLVL_105dB"
							"120 Decibels"			"SNDLVL_120dB"
							"130 Decibels"			"SNDLVL_130dB"
							"Gunfire Level"			"SNDLVL_GUNFIRE"
							"140 Decibels"			"SNDLVL_140dB"
							"150 Decibels"			"SNDLVL_150dB"
						}
					}
				
					//position
					"position"
					{
						"DisplayName" "Position:"
						"Type" "TYPE_COMBOBOX"
						
						"ComboBox_NumKvToSkip" "0"
						"ComboBox_UseFirstChild" "0"
						"ComboBox_DefaultSelected" "0"
						"ComboBox_KeyValues"
						{
							"Play Everywhere"	"%RESERVED_NO_OUTPUT%"
							"Random Position"	"Random"
							"Position 0"		"0"
							"Position 1"		"1"
							"Position 2"		"2"
							"Position 3"		"3"
							"Position 4"		"4"
							"Position 5"		"5"
							"Position 6"		"6"
							"Position 7"		"7"
							"Position 8"		"8"
							"Position 9"		"9"
							"Position 10"		"10"
							"Position 11"		"11"
							"Position 12"		"12"
							"Position 13"		"13"
							"Position 14"		"14"
							"Position 15"		"15"
							"Position 16"		"16"
							"Position 17"		"17"
							"Position 18"		"18"
							"Position 19"		"19"
							"Position 20"		"20"
							"Position 21"		"21"
							"Position 22"		"22"
							"Position 23"		"23"
							"Position 24"		"24"
							"Position 25"		"25"
							"Position 26"		"26"
							"Position 27"		"27"
							"Position 28"		"28"
							"Position 29"		"29"
							"Position 30"		"30"
							"Position 31"		"31"
						}
					}
				}
			}
		}
	
		//play looping
		"playlooping"
		{
			"DisplayName" "Looping Sound"
			"SoundName" "common/null.wav"
			"SoundType" "0"
			
			//data
			"InheritFrom" "PlayOtherData"
			"Data"
			{
				//volume
				"volume"
				{
					"DisplayName" "Volume:"
					"Type" "TYPE_SLIDER"
					
					"Slider_MinValue" "0"
					"Slider_MaxValue" "100"
					"Slider_DefaultValue" "100"
					"Slider_Divisor" "100"
				}
				"pitch"
				{
					"DisplayName" "Pitch:"
					"Type" "TYPE_SLIDER"
					
					"Slider_MinValue" "50"
					"Slider_MaxValue" "150"
					"Slider_DefaultValue" "100"
					"Slider_Divisor" "1"
				}
				"suppress_on_restore"
				{
					"DisplayName" "Supress On Restore:"
					"Type" "TYPE_SLIDER"
					
					"Slider_MinValue" "0"
					"Slider_MaxValue" "1"
					"Slider_DefaultValue" "0"
					"Slider_Divisor" "1"
				}
			}
		}
		
		//play soundscape
		"playsoundscape"
		{
			"DisplayName" "Sub-Soundscape"
			"SoundName" "nothing"
			"SoundType" "1"
			
			//data
			"InheritFrom" "PlaySoundscapeData"
			"Data"
			{
				//volume
				"volume"
				{
					"DisplayName" "Volume:"
					"Type" "TYPE_SLIDER"
					
					"Slider_MinValue" "0"
					"Slider_MaxValue" "100"
					"Slider_DefaultValue" "100"
					"Slider_Divisor" "100"
				}
			}
		}
		
		//play random
		"playrandom"
		{
			"DisplayName" "Random Sounds"
			"SoundName" "rndwave"
			"SoundType" "2"
			
			//data
			"InheritFrom" "PlayOtherData"
			"Data"
			{
				//volume
				"volume"
				{
					"DisplayName" "Volume:"
					"Type" "TYPE_RANDOM_VALUE"
					
					"RandomValue_DefaultString" "0.5,0.8"
				}
				"pitch"
				{
					"DisplayName" "Pitch:"
					"Type" "TYPE_RANDOM_VALUE"
					
					"RandomValue_DefaultString" "95,105"
				}
				"time"
				{
					"DisplayName" "Play Time:"
					"Type" "TYPE_RANDOM_VALUE"
					
					"RandomValue_DefaultString" "16,32"
				}
				"suppress_on_restore"
				{
					"DisplayName" "Supress On Restore:"
					"Type" "TYPE_SLIDER"
					
					"Slider_MinValue" "0"
					"Slider_MaxValue" "1"
					"Slider_DefaultValue" "0"
					"Slider_Divisor" "1"
				}
			}
		}
	}
}