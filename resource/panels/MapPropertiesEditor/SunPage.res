"Map Properties Editor"
{
	"Wide" "560"
	"Tall" "410"

	//our dividers
	"Dividers"
	{
		//sun -overlay size divider
		"SunOverlaySizeDivider"
		{
			"x" "-1"
			"y" "208"
			"w" "802"
			"h" "1"
		}
	}
	
	//our labels
	"Labels"
	{
		//sun labels
		"SunPitchLabel"
		{
			"Text" "#MapProperties_SunPage_Label_SunPitch"
			"x" "85"
			"y" "10"
			"w" "95"
			"h" "20"
		}
		"SunYawLabel"
		{
			"Text" "#MapProperties_SunPage_Label_SunYaw"
			"x" "365"
			"y" "10"
			"w" "95"
			"h" "20"
		}
		"SunSizeLabel"
		{
			"Text" "#MapProperties_SunPage_Label_SunSize"
			"x" "5"
			"y" "105"
			"w" "540"
			"h" "20"
			"alignment" "center"
		}
		"SunMaterialLabel"
		{
			"Text" "#MapProperties_SunPage_Label_SunMaterial"
			"x" "245"
			"y" "150"
			"w" "295"
			"h" "25"
			"alignment" "center"
		}
		"SunOverlaySizeLabel"
		{
			"Text" "#MapProperties_SunPage_Label_SunOverlaySize"
			"x" "5"
			"y" "210"
			"w" "540"
			"h" "20"
			"alignment" "center"
		}
		"SunOverlayMaterialLabel"
		{
			"Text" "#MapProperties_SunPage_Label_SunOverlayMaterial"
			"x" "245"
			"y" "255"
			"w" "295"
			"h" "25"
			"alignment" "center"
		}
	}
	
	//sun
	"SunEnabledCheckButton"
	{
		"Text" "#MapProperties_SunPage_CheckButton_EnableSun"
		"x" "205"
		"y" "10"
		"w" "125"
		"h" "20"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text" "#MapProperties_SunPage_ToolTip_EnableSun"
		}
	}
	
	//sun pitch
	"SunPitchSlider"
	{
		"x" "5"
		"y" "35"
		"w" "270"
		"h" "20"
		"min" "180"
		"max" "-179"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text" "#MapProperties_SunPage_ToolTip_SunPitch"
		}
	}
	"SunPitchText"
	{
		"x" "5"
		"y" "55"
		"w" "25"
		"h" "20"
	}
	
	//sun yaw
	"SunYawSlider"
	{
		"x" "275"
		"y" "35"
		"w" "270"
		"h" "20"
		"min" "180"
		"max" "-179"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text" "#MapProperties_SunPage_ToolTip_SunYaw"
		}
	}
	"SunYawText"
	{
		"x" "275"
		"y" "55"
		"w" "25"
		"h" "20"
	}
	
	//pitch to eye angle button
	"PitchToEyeAngleButton"
	{
		"x" "20"
		"y" "80"
		"w" "510"
		"h" "25"
		"Text" "#MapProperties_SunPage_Button_AngleFromEyes"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text" "#MapProperties_SunPage_ToolTip_AngleToEyes"
		}
	}
	
	//sun size
	"SunSizeSlider"
	{
		"x" "5"
		"y" "125"
		"w" "540"
		"h" "20"
		"min" "-150"
		"max" "300"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text" "#MapProperties_SunPage_ToolTip_SunSize"
		}
	}
	"SunSizeText"
	{
		"x" "5"
		"y" "150"
		"w" "25"
		"h" "20"
	}
	
	//sun color
	"SunColorButton"
	{
		"x" "5"
		"y" "175"
		"w" "200"
		"h" "25"
		"Text" "#MapProperties_SunPage_Button_SetSunsColor"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text" "#MapProperties_SunPage_ToolTip_SunColor"
		}
	}
	"SunColorRect" "210 175 25 25"
	
	//sun material text entry
	"SunMaterialTextEntry"
	{
		"x" "245"
		"y" "175"
		"w" "295"
		"h" "25"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text" "#MapProperties_SunPage_ToolTip_SunMaterial"
		}
	}
	
	//sun overlay size
	"SunOverlaySizeSlider"
	{
		"x" "5"
		"y" "230"
		"w" "540"
		"h" "20"
		"min" "-150"
		"max" "300"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text" "#MapProperties_SunPage_ToolTip_SunOverlaySize"
		}
	}
	"SunOverlaySizeText"
	{
		"x" "5"
		"y" "255"
		"w" "25"
		"h" "20"
	}
	
	//sun color
	"SunOverlayColorButton"
	{
		"x" "5"
		"y" "280"
		"w" "200"
		"h" "25"
		"Text" "#MapProperties_SunPage_Button_SetSunsOverlayColor"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text" "#MapProperties_SunPage_ToolTip_SunOverlayColor"
		}
	}
	"SunOverlayColorRect" "210 279 25 25"
	
	//sun material text entry
	"SunOverlayMaterialTextEntry"
	{
		"x" "245"
		"y" "280"
		"w" "295"
		"h" "25"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text" "#MapProperties_SunPage_ToolTip_SunOverlayMaterial"
		}
	}
}