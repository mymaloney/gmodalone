"Map Properties Editor"
{
	"Wide" "560"
	"Tall" "455"
	
	//dividers
	"Dividers"
	{
		"RainSettingsDivider"
		{
			"x" "0"
			"y" "85"
			"w" "550"
			"h" "1"
		}
		"SnowSettingsDivider"
		{
			"x" "0"
			"y" "180"
			"w" "550"
			"h" "1"
		}
		"TimeSettingsDivider"
		{
			"x" "0"
			"y" "225"
			"w" "550"
			"h" "1"
		}
	}
	
	//labels
	"Labels"
	{
		"WeatherTypeLabel"
		{
			"x" "10"
			"y" "30"
			"w" "520"
			"h" "22"
			"Text" "#MapProperties_WeatherPage_WeatherType"
			"alignment" "center"
		}
		"RainSettingsLabel"
		{
			"x" "10"
			"y" "88"
			"w" "520"
			"h" "22"
			"Text" "#MapProperties_WeatherPage_RainSettings"
			"alignment" "center"
		}
		"SnowSettingsLabel"
		{
			"x" "10"
			"y" "180"
			"w" "520"
			"h" "22"
			"Text" "#MapProperties_WeatherPage_SnowSettings"
			"alignment" "center"
		}
		"TimeSettingsLabel"
		{
			"x" "10"
			"y" "225"
			"w" "520"
			"h" "22"
			"Text" "#MapProperties_WeatherPage_TimeSettings"
			"alignment" "center"
		}
	}
	
	//enable check button
	"EnableWeatherButton"
	{
		"Text" "#MapProperties_WeatherPage_EnableWeather"
		"x" "205"
		"y" "10"
		"w" "125"
		"h" "20"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text" "#MapProperties_WeatherPage_ToolTip_EnableWeather"
		}
	}
	
	//weather type combo box
	"WeatherTypeComboBox"
	{
		"Text" "#MapProperties_WeatherPage_EnableWeather"
		"x" "10"
		"y" "53"
		"w" "520"
		"h" "22"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text" "#MapProperties_WeatherPage_ToolTip_WeatherType"
		}
	}
	
	//rain splashes check button
	"EnableRainSplashesCheckButton"
	{
		"Text" "#MapProperties_WeatherPage_EnableRainSplashes"
		"x" "10"
		"y" "110"
		"w" "200"
		"h" "20"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text" "#MapProperties_WeatherPage_ToolTip_RainSplashes"
		}
	}
	
	//rain density text
	"RainDensityText"
	{
		"x" "10"
		"y" "130"
		"w" "520"
		"h" "20"
		"alignment" "center"
	}
	
	//rain density slider
	"RainDensitySlider"
	{
		"x" "10"
		"y" "150"
		"w" "530"
		"h" "20"
		"min" "1"
		"max" "1000"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text" "#MapProperties_WeatherPage_ToolTip_RainDensity"
		}
	}
	
	//snow settings
	"ShowSnowOnMapsCheckButton"
	{
		"Text" "#MapProperties_WeatherPage_EnableSnowOnMaps"
		"x" "10"
		"y" "202"
		"w" "250"
		"h" "20"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text" "#MapProperties_WeatherPage_ToolTip_SnowOnMaps"
		}
	}
	
	//interval stuff
	"WeatherInIntervalsCheckButton"
	{
		"Text" "#MapProperties_WeatherPage_EnableWeatherIntervals"
		"x" "10"
		"y" "250"
		"w" "250"
		"h" "20"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text" "#MapProperties_WeatherPage_ToolTip_WeatherInIntervals"
		}
	}
	"WeatherWaitTimeMinLabel"
	{
		"x" "10"
		"y" "270"
		"w" "520"
		"h" "20"
		"alignment" "center"
	}
	"WeatherWaitTimeMinSlider"
	{
		"x" "10"
		"y" "290"
		"w" "530"
		"h" "20"
		"min" "10"
		"max" "600"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text" "#MapProperties_WeatherPage_ToolTip_WeatherIntervalsWaitMin"
		}
	}
	"WeatherWaitTimeMaxLabel"
	{
		"x" "10"
		"y" "310"
		"w" "520"
		"h" "20"
		"alignment" "center"
	}
	"WeatherWaitTimeMaxSlider"
	{
		"x" "10"
		"y" "330"
		"w" "530"
		"h" "20"
		"min" "30"
		"max" "1200"
		
		"TooltipData"
		{
			"Enabled" "1"
			"DelayInMS" "100"
			"TooltipMultiline" "1"
			"Text" "#MapProperties_WeatherPage_ToolTip_WeatherIntervalsWaitMax"
		}
	}
}