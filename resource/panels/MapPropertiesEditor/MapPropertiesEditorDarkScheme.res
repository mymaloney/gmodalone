#base "../../SourceSchemeBase.res"

Scheme
{
	//base colors
	Colors
	{
		"LightBlue"						"0 120 215 255"
		"DarkBlue"						"42 74 119 255"
		"DarkishGrey"					"38 38 38 255"
		"LightishGrey"					"64 64 64 255"
	}

	//base settings
	BaseSettings
	{
		//border colors
		Border.Dark						"52 52 52 196"
		Border.Bright					"144 144 144 196"
	
		//frame
		Frame.BgColor					"15 15 15 255"
		Frame.OutOfFocusBgColor			"15 15 15 255"
		
		//property sheet
		PropertySheet.BgColor			"15 15 15 255"

		//button
		Button.BgColor					"DarkishGrey"
		Button.ArmedBgColor				"LightishGrey"
		Button.DepressedBgColor			"DullWhite"
		Button.FocusBorderColor			"LightBlue"

		//check button
		CheckButton.BgColor				"DarkishGrey"
		CheckButton.ArmedBgColor		"LightishGrey"
		CheckButton.DepressedBgColor	"DullWhite"
		CheckButton.Check				"LightBlue"
		
		//slider
		Slider.NobColor					"LightBlue"
		Slider.TextColor				"White"
		Slider.TrackColor				"White"
		Slider.DisabledTextColor1		"LightishGrey"
		Slider.DisabledTextColor2		"DarkishGrey"
		
		//combo box
		ComboBoxButton.BgColor			"DarkishGrey"
		
		//text entry
		TextEntry.SelectedBgColor		"LightBlue"
		TextEntry.BgColor				"DarkishGrey"

		//menu
		Menu.BgColor					"DarkishGrey"
		Menu.TextColor					"White"
		Menu.ArmedTextColor				"Black"
		Menu.ArmedBgColor				"LightBlue"	
		
		//tool tip
		Tooltip.TextColor				"White"
		Tooltip.BgColor					"33 33 33 255"
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
					"color" "DarkBlue"
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
					"color" "DarkBlue"
					"offset" "0 0"
				}
			}
		}
	}
}