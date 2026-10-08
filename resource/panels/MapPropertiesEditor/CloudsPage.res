"Map Properties Editor"
{
	"Wide" "560"
	"Tall" "580"
	
	//our dividers
	"Dividers"
	{
		"EnableCloudsDivider"
		{
			"x" "-1"
			"y" "54"
			"w" "802"
			"h" "1"
		}
		"CloudsMaterialDivider"
		{
			"x" "-1"
			"y" "162"
			"w" "802"
			"h" "1"
		}
		"CloudsColorDivider"
		{
			"x" "-1"
			"y" "265"
			"w" "802"
			"h" "1"
		}
	}
	
	//labels
	"Labels"
	{
		"CloudsMaterialText"
		{
			"x" "10"
			"y" "60"
			"w" "525"
			"h" "20"
			"Alignment" "center"
			"Text" "#MapProperties_CloudsPage_MaterialText"
		}
		"CloudsColorText"
		{
			"x" "10"
			"y" "165"
			"w" "525"
			"h" "20"
			"Alignment" "center"
			"Text" "#MapProperties_CloudsPage_ColorText"
		}
		"CloudsSettingsText"
		{
			"x" "10"
			"y" "265"
			"w" "525"
			"h" "20"
			"Alignment" "center"
			"Text" "#MapProperties_CloudsPage_SettingsText"
		}
	}
	
	//enable clouds
	"EnableCloudsButton"
	{
		"Text" "#MapProperties_CloudsPage_EnableClouds"
		"x" "215"
		"y" "10"
		"w" "100"
		"h" "20"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_CloudsPage_ToolTip_EnableClouds"
		}
	}
	
	//force clouds button
	"ForceCloudsButton"
	{
		"Text" "#MapProperties_CloudsPage_ForceClouds"
		"x" "150"
		"y" "32"
		"w" "100"
		"h" "20"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_CloudsPage_ToolTip_ForceClouds"
		}
	}
	
	//clip through 3d sky
	"ShouldCloudsClip3dSkybox"
	{
		"Text" "#MapProperties_CloudsPage_ShouldClipThrough3dSky"
		"x" "260"
		"y" "32"
		"w" "255"
		"h" "20"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_CloudsPage_ToolTip_ShouldClipThrough3dSky"
		}
	}
	
	//clouds material combo box
	"CloudsMaterialNames"
	{
		"x" "10"
		"y" "85"
		"w" "525"
		"h" "20"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_CloudsPage_ToolTip_CloudsMaterial"
		}
	}
	
	//material scale X
	"CloudsMatScaleXText"
	{
		"x" "10"
		"y" "110"
		"w" "255"
		"h" "20"
	}
	"CloudsMatScaleXSlider"
	{
		"x" "10"
		"y" "130"
		"w" "255"
		"h" "20"
		"min" "500"
		"max" "2000"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_CloudsPage_ToolTip_CloudsMatScaleX"
		}
	}
	
	//material scale Y
	"CloudsMatScaleYText"
	{
		"x" "270"
		"y" "110"
		"w" "255"
		"h" "20"
	}
	"CloudsMatScaleYSlider"
	{
		"x" "270"
		"y" "130"
		"w" "255"
		"h" "20"
		"min" "500"
		"max" "2000"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_CloudsPage_ToolTip_CloudsMatScaleY"
		}
	}
	
	//clouds color
	"CloudsColorButton"
	{
		"Text" "#MapProperties_CloudsPage_CloudsColor"
		"x" "10"
		"y" "190"
		"w" "495"
		"h" "20"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_CloudsPage_ToolTip_CloudsColor"
		}
	}
	"CloudsColorRect" "510 190 20 20"
	
	//clouds alpha
	"CloudsAlphaText"
	{
		"x" "10"
		"y" "215"
		"w" "525"
		"h" "20"
	}
	"CloudsAlphaSlider"
	{
		"x" "10"
		"y" "235"
		"w" "525"
		"h" "20"
		"min" "0"
		"max" "2500"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_CloudsPage_ToolTip_CloudsAlpha"
		}
	}
	
	//scroll speed X
	"ScrollSpeedXText"
	{
		"x" "10"
		"y" "290"
		"w" "255"
		"h" "20"
	}
	"ScrollSpeedXSlider"
	{
		"x" "10"
		"y" "310"
		"w" "255"
		"h" "20"
		"min" "-500"
		"max" "500"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_CloudsPage_ToolTip_CloudsSpeedX"
		}
	}
	
	//scroll speed Y
	"ScrollSpeedYText"
	{
		"x" "270"
		"y" "290"
		"w" "255"
		"h" "20"
	}
	"ScrollSpeedYSlider"
	{
		"x" "270"
		"y" "310"
		"w" "255"
		"h" "20"
		"min" "-500"
		"max" "500"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_CloudsPage_ToolTip_CloudsSpeedY"
		}
	}
	
	//x offset
	"CloudsOffsetXText"
	{
		"x" "10"
		"y" "340"
		"w" "170"
		"h" "20"
	}
	"CloudsOffsetXSlider"
	{
		"x" "10"
		"y" "360"
		"w" "170"
		"h" "20"
		"min" "-8000"
		"max" "8000"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_CloudsPage_ToolTip_CloudsOffsetX"
		}
	}

	//y offset
	"CloudsOffsetYText"
	{
		"x" "185"
		"y" "340"
		"w" "170"
		"h" "20"
	}
	"CloudsOffsetYSlider"
	{
		"x" "185"
		"y" "360"
		"w" "170"
		"h" "20"
		"min" "-8000"
		"max" "8000"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_CloudsPage_ToolTip_CloudsOffsetY"
		}
	}

	//z offset
	"CloudsOffsetZText"
	{
		"x" "360"
		"y" "340"
		"w" "170"
		"h" "20"
	}
	"CloudsOffsetZSlider"
	{
		"x" "360"
		"y" "360"
		"w" "170"
		"h" "20"
		"min" "-8000"
		"max" "8000"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_CloudsPage_ToolTip_CloudsOffsetZ"
		}
	}
	
	//x scale
	"CloudsScaleXText"
	{
		"x" "10"
		"y" "385"
		"w" "170"
		"h" "20"
	}
	"CloudsScaleXSlider"
	{
		"x" "10"
		"y" "405"
		"w" "170"
		"h" "20"
		"min" "0"
		"max" "5000"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_CloudsPage_ToolTip_CloudsScaleX"
		}
	}

	//y scale
	"CloudsScaleYText"
	{
		"x" "185"
		"y" "385"
		"w" "170"
		"h" "20"
	}
	"CloudsScaleYSlider"
	{
		"x" "185"
		"y" "405"
		"w" "170"
		"h" "20"
		"min" "0"
		"max" "5000"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_CloudsPage_ToolTip_CloudsScaleY"
		}
	}

	//z scale
	"CloudsScaleZText"
	{
		"x" "360"
		"y" "385"
		"w" "170"
		"h" "20"
	}
	"CloudsScaleZSlider"
	{
		"x" "360"
		"y" "405"
		"w" "170"
		"h" "20"
		"min" "0"
		"max" "5000"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_CloudsPage_ToolTip_CloudsScaleZ"
		}
	}
	
	//x angle
	"CloudsAngleXText"
	{
		"x" "10"
		"y" "430"
		"w" "170"
		"h" "20"
	}
	"CloudsAngleXSlider"
	{
		"x" "10"
		"y" "450"
		"w" "170"
		"h" "20"
		"min" "-360"
		"max" "360"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_CloudsPage_ToolTip_CloudsAngleX"
		}
	}

	//y angle
	"CloudsAngleYText"
	{
		"x" "185"
		"y" "430"
		"w" "170"
		"h" "20"
	}
	"CloudsAngleYSlider"
	{
		"x" "185"
		"y" "450"
		"w" "170"
		"h" "20"
		"min" "-360"
		"max" "360"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_CloudsPage_ToolTip_CloudsAngleY"
		}
	}

	//z angle
	"CloudsAngleZText"
	{
		"x" "360"
		"y" "430"
		"w" "170"
		"h" "20"
	}
	"CloudsAngleZSlider"
	{
		"x" "360"
		"y" "450"
		"w" "170"
		"h" "20"
		"min" "-360"
		"max" "360"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text"	"#MapProperties_CloudsPage_ToolTip_CloudsAngleZ"
		}
	}
}