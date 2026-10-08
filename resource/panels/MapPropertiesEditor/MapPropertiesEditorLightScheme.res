#base "../../SourceSchemeBase.res"

Scheme
{
	//base colors
	Colors
	{
		"VeryLightBlue"					"0 162 232 255"
		"LightBlue"						"0 120 215 255"
		"DarkishGrey"					"160 160 160 255"
		"LightishGrey"					"180 180 180 255"
	}

	//base settings
	BaseSettings
	{
		//border colors
		Border.Dark						"111 111 111 196"
		Border.Bright					"203 203 203 196"
	
		//frame
		Frame.BgColor					"130 130 132 255"
		Frame.OutOfFocusBgColor			"130 130 132 255"
		FrameTitleBar.TextColor			"Black"
		FrameTitleBar.DisabledTextColor	"Black"
		
		//property sheet
		PropertySheet.BgColor			"130 130 132 255"

		//button
		Button.BgColor					"DarkishGrey"
		Button.TextColor				"Black"
		Button.ArmedBgColor				"LightishGrey"
		Button.ArmedTextColor			"Black"
		Button.DepressedBgColor			"DullWhite"
		Button.DepressedTextColor		"Black"
		Button.FocusBorderColor			"LightBlue"

		//toggle button
		ToggleButton.SelectedTextColor	"Black"

		//check button
		CheckButton.BgColor				"DarkishGrey"
		CheckButton.ArmedBgColor		"LightishGrey"
		CheckButton.DepressedBgColor	"DullWhite"
		CheckButton.Check				"LightBlue"
		CheckButton.TextColor			"Black"
		CheckButton.SelectedTextColor	"Black"
		
		//slider
		Slider.NobColor					"LightBlue"
		Slider.TextColor				"Black"
		Slider.TrackColor				"Black"
		Slider.DisabledTextColor1		"LightishGrey"
		Slider.DisabledTextColor2		"DarkishGrey"
		
		//label
		Label.TextColor					"Black"
		Label.TextBrightColor			"Black"
		Label.SelectedTextColor			"Black"
		Label.TextDullColor				"LightishGrey"
		
		//combo box
		ComboBoxButton.BgColor			"DarkishGrey"
		
		//text entry
		TextEntry.TextColor				"Black"
		TextEntry.SelectedTextColor		"Black"
		TextEntry.SelectedTextColor		"Black"
		TextEntry.DisabledTextColor		"DullWhite"
		TextEntry.SelectedBgColor		"LightBlue"
		TextEntry.BgColor				"DarkishGrey"

		//menu
		Menu.BgColor					"DarkishGrey"
		Menu.TextColor					"White"
		Menu.ArmedTextColor				"Black"
		Menu.ArmedBgColor				"LightBlue"	
		
		//tool tip
		Tooltip.TextColor				"24 24 24 255"
		Tooltip.BgColor					"White"
	}
	
	//borders
	Borders
	{
		ToolTipBorder
		{
			"inset" "0 0 1 0"
			Left
			{
				"1"
				{
					"color" "LightBlue"
					"offset" "0 0"
				}
			}

			Right
			{
				"1"
				{
					"color" "LightBlue"
					"offset" "1 0"
				}
			}

			Top
			{
				"1"
				{
					"color" "LightBlue"
					"offset" "0 0"
				}
			}

			Bottom
			{
				"1"
				{
					"color" "VeryLightBlue"
					"offset" "0 0"
				}
			}
		}
	}
}
