"resource/vgui base/SoundscapeEditorPanelSetNameDialog.res"
{
    "SetSoundscapeNamePanel"
    {
        "ControlName"        "CSetSoundscapeNamePanel"
        "fieldName"          "SetSoundscapeNamePanel"
        "xpos"               "c-150"
        "ypos"               "c-58"
        "wide"               "300"
        "tall"               "90"
        "visible"            "1"
        "enabled"            "1"
        "settitlebarvisible" "1"
    }
	
	"SetSoundscapeTextEntry"
	{
        "ControlName"        "TextEntry"
        "fieldName"          "SetSoundscapeTextEntry"
        "xpos"               "5"
        "ypos"               "30"
        "wide"               "290"
        "tall"               "25"
        "visible"            "1"
        "enabled"            "1"
		"maxchars"			 "100"
	}
	
	"SaveButton"
	{
        "ControlName"        "Button"
        "fieldName"          "SaveButton"
        "xpos"               "5"
        "ypos"               "60"
        "wide"               "143"
        "tall"               "25"
        "visible"            "1"
        "enabled"            "1"
		"labelText"		     "Save"
		"command"		     "SetName"
		"textAlignment"	     "center"
		"sound_released"	 "ui/buttonclickrelease.wav"
		"sound_armed"	 	 "ui/buttonrollover.wav"
		"default"			 "1"
	}
	
	"CancelButton"
	{
        "ControlName"        "Button"
        "fieldName"          "CancelButton"
        "xpos"               "152"
        "ypos"               "60"
        "wide"               "143"
        "tall"               "25"
        "visible"            "1"
        "enabled"            "1"
		"labelText"		     "Cancel"
		"command"		     "Close"
		"textAlignment"	     "center"
		"sound_released"	 "ui/buttonclickrelease.wav"
		"sound_armed"	 	 "ui/buttonrollover.wav"
	}
}