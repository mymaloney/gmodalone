"resource/vgui base/SoundscapeEditorPanelTextEditorDialog.res"
{
    "SoundscapeEditorPanelTextEditor"
    {
        "ControlName"        "CSoundscapeEditorTextEditorPanel"
        "fieldName"          "SoundscapeEditorPanelTextEditor"
        "xpos"               "c-380"
        "ypos"               "c-320"
        "wide"               "760"
        "tall"               "640"
        "visible"            "1"
        "enabled"            "1"
        "settitlebarvisible" "1"
        "title"              "Soundscape Text Editor"
    }
	
	"SaveButton"
	{
        "ControlName"        "Button"
        "fieldName"          "SaveButton"
        "xpos"               "5"
        "ypos"               "610"
        "wide"               "100"
        "tall"               "25"
        "visible"            "1"
        "enabled"            "1"
		"command"			 "SaveToEditor"
		"labelText"			 "Save To Editor"
		"textAlignment"		 "center"
		"sound_released"	 "ui/buttonclickrelease.wav"
		"sound_armed"	 	 "ui/buttonrollover.wav"
	}
	
	"TextEditBox"
	{
        "ControlName"        "CSoundscapeEditorTextEntry"
        "fieldName"          "TextEditBox"
        "xpos"               "5"
        "ypos"               "25"
        "wide"               "750"
        "tall"               "580"
        "visible"            "1"
        "enabled"            "1"
	}
	
	"FindTextEntry"
	{
        "ControlName"        "TextEntry"
        "fieldName"          "FindTextEntry"
        "xpos"               "450"
        "ypos"               "610"
        "wide"               "200"
        "tall"               "25"
        "visible"            "1"
        "enabled"            "1"
		"maxchars"			"128"
	}
	
	"FindButton"
	{
        "ControlName"        "Button"
        "fieldName"          "FindButton"
        "xpos"               "655"
        "ypos"               "610"
        "wide"               "100"
        "tall"               "25"
        "visible"            "1"
        "enabled"            "1"
		"command"			 "FindText"
		"labelText"			 "Find Text"
		"textAlignment"		 "center"
		"sound_released"	 "ui/buttonclickrelease.wav"
		"sound_armed"	 	 "ui/buttonrollover.wav"
		"default"			 "1"
	}
}