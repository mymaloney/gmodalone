"Map Properties Editor"
{
	"Wide" "550"
	"Tall" "320"
	
	//our dividers
	"Dividers"
	{
		"EnableStarsDivider"
		{
			"x" "-1"
			"y" "34"
			"w" "802"
			"h" "1"
		}
		"OffsetsDivider"
		{
			"x" "-1"
			"y" "135"
			"w" "802"
			"h" "1"
		}
	}
		
	//enable stars
	"EnableStarsButton"
	{
		"Text" "#MapProperties_StarsPage_EnableStars"
		"x" "100"
		"y" "10"
		"w" "135"
		"h" "20"
	
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_StarsPage_ToolTip_EnableStars"
		}
	}
	
	//clip through 3d sky
	"ShouldStarsClip3dSkybox"
	{
		"Text" "#MapProperties_StarsPage_ShouldClipThrough3dSky"
		"x" "240"
		"y" "10"
		"w" "255"
		"h" "20"
	
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_StarsPage_ToolTip_ShouldClipThrough3dSky"
		}
	}
	
	//scale
	"StarsScaleText"
	{
		"x" "10"
		"y" "40"
		"w" "515"
		"h" "20"
	}
	"StarsScaleSlider"
	{
		"x" "10"
		"y" "60"
		"w" "515"
		"h" "20"
		"min" "1"
		"max" "10000"
	
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_StarsPage_ToolTip_ScaleSlider"
		}
	}
	
	//scale
	"StarsRadiusText"
	{
		"x" "10"
		"y" "85"
		"w" "515"
		"h" "20"
	}
	"StarsRadiusSlider"
	{
		"x" "10"
		"y" "105"
		"w" "515"
		"h" "20"
		"min" "1"
		"max" "10000"
	
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_StarsPage_ToolTip_ScaleRadius"
		}
	}	


	//x offset
	"StarsOffsetXText"
	{
		"x" "10"
		"y" "140"
		"w" "170"
		"h" "20"
	}
	"StarsOffsetXSlider"
	{
		"x" "10"
		"y" "160"
		"w" "170"
		"h" "20"
		"min" "-8000"
		"max" "8000"
	
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_StarsPage_ToolTip_OffsetX"
		}
	}

	//y offset
	"StarsOffsetYText"
	{
		"x" "185"
		"y" "140"
		"w" "170"
		"h" "20"
	}
	"StarsOffsetYSlider"
	{
		"x" "185"
		"y" "160"
		"w" "170"
		"h" "20"
		"min" "-8000"
		"max" "8000"
	
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_StarsPage_ToolTip_OffsetY"
		}
	}

	//z offset
	"StarsOffsetZText"
	{
		"x" "360"
		"y" "140"
		"w" "170"
		"h" "20"
	}
	"StarsOffsetZSlider"
	{
		"x" "360"
		"y" "160"
		"w" "170"
		"h" "20"
		"min" "-8000"
		"max" "8000"
	
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_StarsPage_ToolTip_OffsetZ"
		}
	}
	
	//stars color
	"StarsColorButton"
	{
		"Text" "#MapProperties_StarsPage_StarsColor"
		"x" "10"
		"y" "195"
		"w" "485"
		"h" "20"
	
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_StarsPage_ToolTip_Color"
		}
	}
	"StarsColorRect" "500 195 20 20"
}