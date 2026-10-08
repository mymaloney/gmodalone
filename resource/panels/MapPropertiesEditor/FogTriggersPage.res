"Map Properties Editor"
{
	"Wide" "550"
	"Tall" "585"
	
	//fog data
	"FogData"
	{
		//fog lerp stuff
		"fog_lerp_system_lerp_time" {
			"DisplayText" 		"Fog Transition Time"
			"Type" 				"TYPE_SLIDER"
			"Min" 				"0"
			"Max" 				"200"
			"Divisor" 			"100"
		}
		"fog_lerp_system_lerp_type" {
			"DisplayText" 		"Fog Transition Type"
			"Type" 				"TYPE_SLIDER"
			"Min" 				"0"
			"Max" 				"5"
		}
		"fog_lerp_system_lerp_parameter" {
			"DisplayText" 		"Fog Transition Parameter"
			"Type" 				"TYPE_SLIDER"
			"Min" 				"0"
			"Max" 				"1000"
			"Divisor" 			"1000"
		}
		
		//divider
		"Divider" {
			"Type"				"TYPE_DIVIDER"
		}
		
		//fog enabled states
		"fog_override" {
			"DisplayText" 		"Override The Maps Fog"
			"Type" 				"TYPE_SLIDER"
			"Min" 				"0"
			"Max" 				"1"
		}
		"r_pixelfog" {
			"DisplayText" 		"Enable Pixel Fog"
			"Type" 				"TYPE_SLIDER"
			"Min" 				"0"
			"Max" 				"1"
		}
		"fog_enable" {
			"DisplayText" 		"Enable Fog"
			"Type" 				"TYPE_SLIDER"
			"Min" 				"-1"
			"Max" 				"1"
		}
		"fog_enableskybox" {
			"DisplayText" 		"Enable Skybox Fog"
			"Type" 				"TYPE_SLIDER"
			"Min" 				"-1"
			"Max" 				"1"
		}
		
		//divider
		"Divider" {
			"Type"				"TYPE_DIVIDER"
		}
		
		//fog data
		"fog_color" {
			"DisplayText" 		"Fog Color"
			"Type" 				"TYPE_COLORPICKER"
		}
		"fog_colorskybox" {
			"DisplayText" 		"Fog Skybox Color"
			"Type" 				"TYPE_COLORPICKER"
		}
		"fog_start" {
			"DisplayText" 		"Fog Start Pos"
			"Type" 				"TYPE_SLIDER"
			"Min"				"-25000"
			"Max"				"50000"
		}
		"fog_end" {
			"DisplayText" 		"Fog End Pos"
			"Type" 				"TYPE_SLIDER"
			"Min"				"-10000"
			"Max"				"150000"
		}
		"fog_startskybox" {
			"DisplayText" 		"Fog Skybox Start Pos"
			"Type" 				"TYPE_SLIDER"
			"Min"				"-25000"
			"Max"				"50000"
		}
		"fog_endskybox" {
			"DisplayText" 		"Fog Skybox End Pos"
			"Type" 				"TYPE_SLIDER"
			"Min"				"-10000"
			"Max"				"150000"
		}
		"fog_maxdensity" {
			"DisplayText" 		"Fog Density"
			"Type" 				"TYPE_SLIDER"
			"Min"				"-1"
			"Max"				"1000"
			"Divisor"			"1000.0"
		}
		"fog_maxdensityskybox" {
			"DisplayText" 		"Fog Skybox Density"
			"Type" 				"TYPE_SLIDER"
			"Min"				"-1"
			"Max"				"1000"
			"Divisor"			"1000.0"
		}
		
		//divider
		"Divider" {
			"Type"				"TYPE_DIVIDER"
		}
		
		//fog blending
		"fog_blend" {
			"DisplayText" 		"Enable Fog Blending"
			"Type" 				"TYPE_SLIDER"
			"Min"				"-1"
			"Max"				"1"
		}
		"fog_blendskybox" {
			"DisplayText" 		"Enable Fog Skybox Blending"
			"Type" 				"TYPE_SLIDER"
			"Min"				"-1"
			"Max"				"1"
		}
		"fog_blendangle" {
			"DisplayText" 		"Fog Blending Angle"
			"Type" 				"TYPE_SLIDER"
			"Min"				"-1"
			"Max"				"359"
		}
		"fog_blendangleskybox" {
			"DisplayText" 		"Skybox Fog Blending Angle"
			"Type" 				"TYPE_SLIDER"
			"Min"				"-1"
			"Max"				"359"
		}
		"fog_blendcolor" {
			"DisplayText" 		"Fog Blend Color"
			"Type" 				"TYPE_COLORPICKER"
		}
		"fog_blendcolorskybox" {
			"DisplayText" 		"Skybox Fog Blend Color"
			"Type" 				"TYPE_COLORPICKER"
		}
		
		//divider
		"Divider" {
			"Type" 				"TYPE_DIVIDER"
		}
		
		//bloom
		"mat_force_bloom" {
			"DisplayText" 		"Enable bloom"
			"Type" 				"TYPE_SLIDER"
			"Min"				"0"
			"Max"				"1"
		}
		"mat_bloomscale" {
			"DisplayText" 		"Bloom Scale"
			"Type" 				"TYPE_SLIDER"
			"Min"				"0"
			"Max"				"500"
		}
		"mat_bloom_scalefactor_scalar" {
			"DisplayText" 		"Bloom scale factor"
			"Type" 				"TYPE_SLIDER"
			"Min"				"0"
			"Max"				"10000"
			"Divisor"			"100.0"
		}
		
		//divider
		"Divider" {
			"Type" 				"TYPE_DIVIDER"
		}
		
		//filter
		"amod_epic_filter_lerp_time" {
			"DisplayText" 		"Filter Fade Time"
			"Type" 				"TYPE_SLIDER"
			"Min"				"1"
			"Max"				"100"
			"Divisor"			"100"
		}
		"amod_trigger_filtername" {
			"DisplayText" 		"Filter Name"
			"Type" 				"TYPE_COMBO_BOX:FILTERS"
		}
		"amod_trigger_filterintensity" {
			"DisplayText" 		"Filter Intensity"
			"Type" 				"TYPE_SLIDER"
			"Min"				"1"
			"Max"				"100"
			"Divisor"			"100.0"
		}
		
		//divider
		"Divider" {
			"Type" 				"TYPE_DIVIDER"
		}
		
		//skybox
		"sv_skyname" {
			"DisplayText" 		"Skybox name"
			"Type" 				"TYPE_COMBO_BOX:SKYBOX"
		}
	}
	
	//dividers
	"Dividers"
	{
		"DataDivider"
		{
			"x" "0"
			"y" "148"
			"w" "550"
			"h" "1"
		}
	}
	
	//data
	"ShouldOverrideButton"
	{
		"Text" "#MapProperties_FogTriggersPage_ShouldOverrideButton"
		"x" "170"
		"y" "10"
		"w" "515"
		"h" "20"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_FogTriggersPage_Tooltip_OverrideButton"
		}
	}
	
	"DataLabel"
	{
		"Text" "#MapProperties_FogTriggersPage_NoItemSelected"
		"x" "10"
		"y" "33"
		"w" "225"
		"h" "20"
		"alignment" "east"
	}
	
	"DataSlider"
	{
		"x" "240"
		"y" "33"
		"w" "225"
		"h" "20"
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
		}
	}
	
	"DataFilter"
	{
		"x" "240"
		"y" "33"
		"w" "225"
		"h" "20"
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
		}
	}
	
	"DataButton"
	{
		"Text" "#MapProperties_FogTriggersPage_SetColorButton"
		"x" "240"
		"y" "33"
		"w" "225"
		"h" "20"
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
		}
	}
	"DataColorRect" "470 33 20 20"
	
	"DataShouldOverrideColor"
	{
		"Text" "#MapProperties_FogTriggersPage_OverrideColorButton"
		"x" "180"
		"y" "60"
		"w" "225"
		"h" "20"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_FogTriggersPage_Tooltip_OverrideColorButton"
		}
	}
	
	//transition sliders
	"TransitionSliderText"
	{
		"x" "10"
		"y" "59"
		"w" "225"
		"h" "20"
		"alignment" "east"
	}
	"TransitionSlider"
	{
		"x" "240"
		"y" "59"
		"w" "225"
		"h" "20"
		"min" "0"
		"max" "1000"
	}
	
	//apply button
	"ApplyButton"
	{
		"Text" "#MapProperties_FogTriggersPage_ApplyFogSettings"
		"x" "10"
		"y" "95"
		"w" "515"
		"h" "20"
	}
	
	//size button
	"SetSizeButton"
	{
		"Text" "#MapProperties_FogTriggersPage_SetSizeText"
		"x" "10"
		"y" "121"
		"w" "515"
		"h" "20"
	}
	
	//mins text entry
	"MinsTextEntry"
	{
		"x" "10"
		"y" "95"
		"w" "254"
		"h" "20"
	}
	
	//maxs text entry
	"MaxsTextEntry"
	{
		"x" "270"
		"y" "95"
		"w" "254"
		"h" "20"
	}
	
	//trigger data
	"TriggerData"
	{
		"x" "10"
		"y" "155"
		"w" "515"
		"h" "200"
	}
	
	//trigger list
	"TriggerList"
	{
		"x" "10"
		"y" "360"
		"w" "515"
		"h" "100"
	}
	
	//bottom buttons
	"AddButton"
	{
		"Text" "#MapProperties_FogTriggersPage_AddButton"
		"x" "10"
		"y" "465"
		"w" "168"
		"h" "20"
	}
	"RenameButton"
	{
		"Text" "#MapProperties_FogTriggersPage_RenameButton"
		"x" "184"
		"y" "465"
		"w" "168"
		"h" "20"
	}
	"RemoveButton"
	{
		"Text" "#MapProperties_FogTriggersPage_RemoveButton"
		"x" "358"
		"y" "465"
		"w" "168"
		"h" "20"
	}

}