"Map Properties Editor"
{
	"Wide" "550"
	"Tall" "550"

	//our dividers
	"Dividers"
	{
	 	//skybox side divider
		"SkyboxSideDivider"
		{
			"x" "240"
			"y" "4"
			"w" "1"
			"h" "280"
		}
		
		//post processing filter divider
		"PostProcessingFilterDIvider"
		{
			"x" "240"
			"y" "125"
			"w" "400"
			"h" "1"
		}
		
		//skybox angle divider
		"SkyboxAngleDivider"
		{
			"x" "0"
			"y" "284"
			"w" "550"
			"h" "1"
		}
	}
	
	//our labels
	"Labels"
	{
		//skybox
		"SkyboxTitle"
		{
			"Text" "#MapProperties_SkyboxPage_Label_SkyboxSettings"
			"x" "20"
			"y" "10"
			"w" "200"
			"h" "20"
			"alignment" "center"
		}

		//post processing filter
		"FilterTitle"
		{
			"Text" "#MapProperties_SkyboxPage_Label_PostProcessingSettings"
			"x" "245"
			"y" "10"
			"w" "290"
			"h" "20"
			"alignment" "center"
		}
		
		//bloom
		"BloomTitle"
		{
			"Text" "#MapProperties_SkyboxPage_Label_BloomSettings"
			"x" "245"
			"y" "133"
			"w" "290"
			"h" "20"
			"alignment" "center"
		}
		"BloomScaleLabel"
		{
			"Text" "#MapProperties_SkyboxPage_Label_BloomScale"
			"x" "255"
			"y" "180"
			"w" "290"
			"h" "20"
		}
		"BloomScalarLabel"
		{
			"Text" "#MapProperties_SkyboxPage_Label_BloomScalar"
			"x" "255"
			"y" "228"
			"w" "290"
			"h" "20"
		}
		
		//skybox angle label
		"SkyboxAngles"
		{
			"Text" "#MapProperties_SkyboxPage_Label_SkyboxAngles"
			"x" "0"
			"y" "285"
			"w" "520"
			"h" "20"
			"alignment" "center"
		}
	}
	
	
	//skybox section
	"SkyboxBackground"
	{
		"x" "15"
		"y" "31"
		"w" "210"
		"h" "210"
		"fillcolor" "0 0 0 255"
		"squaresize" "1"
	}
	"SkyboxForeground"
	{
		"x" "20"
		"y" "36"
		"w" "200"
		"h" "200"
		"fillcolor" "255 0 0 255"
		"squaresize" "1"
	}
	
	//combo box
	"SkyboxNames"
	{
		"x" "15"
		"y" "244"
		"w" "210"
		"h" "22"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text" "#MapProperties_SkyboxPage_ToolTip_SkyboxesList"
		}
	}
	
	
	
	
	
	
	//post processing filter
	"FilterIntensityComboBox"
	{
		"x" "255"
		"y" "35"
		"w" "270"
		"h" "22"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text" "#MapProperties_SkyboxPage_ToolTip_FilterList"
		}
	}
	"FilterIntensityText"
	{
		"x" "260"
		"y" "61"
		"w" "255"
		"h" "22"
		"alignment" "center"
	}
	"FilterIntensitySlider"
	{
		"x" "260"
		"y" "85"
		"w" "270"
		"h" "22"
		"min" "0"
		"max" "100"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text" "#MapProperties_SkyboxPage_ToolTip_FilterIntensity"
		}
	}
	
	
	
	
	
	
	//bloom
	"BloomEnabledButton"
	{
		"x" "245"
		"y" "155"
		"w" "400"
		"h" "18"
		"Text" "#MapProperties_SkyboxPage_CheckButton_EnableBloom"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text" "#MapProperties_SkyboxPage_ToolTip_EnableBloom"
		}
	}	
	
	//bloom scale
	"BloomScaleSlider"
	{
		"x" "255"
		"y" "200"
		"w" "240"
		"h" "20"
		"min" "1"
		"max" "500"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text" "#MapProperties_SkyboxPage_ToolTip_BloomScale"
		}
	}
	"BloomScaleText"
	{
		"x" "495"
		"y" "200"
		"w" "100"
		"h" "20"
	}
	
	//bloom scalar
	"BloomScalarSlider"
	{
		"x" "255"
		"y" "250"
		"w" "240"
		"h" "20"
		"min" "1"
		"max" "10000"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text" "#MapProperties_SkyboxPage_ToolTip_BloomScalar"
		}
	}
	"BloomScalarText"
	{
		"x" "495"
		"y" "250"
		"w" "100"
		"h" "20"
	}
	
	
	
	
	
	
	//skybox angles
	"SkyboxPitchSlider"
	{	
		"x" "10"
		"y" "320"
		"w" "520"
		"h" "20"
		"min" "0"
		"max" "360"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text" "#MapProperties_SkyboxPage_ToolTip_PitchAngle"
		}
	}
	"SkyboxYawSlider"
	{	
		"x" "10"
		"y" "365"
		"w" "520"
		"h" "20"
		"min" "0"
		"max" "360"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text" "#MapProperties_SkyboxPage_ToolTip_YawAngle"
		}
	}
	"SkyboxRollSlider"
	{	
		"x" "10"
		"y" "410"
		"w" "520"
		"h" "20"
		"min" "0"
		"max" "360"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text" "#MapProperties_SkyboxPage_ToolTip_RollAngle"
		}
	}
		
	//skybox pitch label
	"SkyboxPitchLabel"
	{
		"x" "20"
		"y" "300"
		"w" "200"
		"h" "20"
	}
	
	//skybox yaw label
	"SkyboxYawLabel"
	{
		"x" "20"
		"y" "345"
		"w" "200"
		"h" "20"
	}
	
	//skybox roll label
	"SkyboxRollLabel"
	{
		"x" "20"
		"y" "390"
		"w" "200"
		"h" "20"
	}
}