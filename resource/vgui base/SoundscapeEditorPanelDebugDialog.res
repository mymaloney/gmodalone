"resource/vgui base/SoundscapeEditorPanelDebugDialog.res"
{
    "SoundscapeDebugPanel"
    {
        "ControlName"        "CSoundscapeDebugPanel"
        "fieldName"          "SoundscapeDebugPanel"
        "xpos"               "c-325"
        "ypos"               "c-315"
        "wide"               "650"
        "tall"               "700"
        "visible"            "1"
        "enabled"            "1"
        "settitlebarvisible" "1"
		"title"				 "Soundscape Debug Panel"
    }
	
	//event list view
	"EventListPanel"
    {
        "ControlName"        "ListPanel"
        "fieldName"          "EventListPanel"
        "xpos"               "5"
        "ypos"               "30"
        "wide"               "640"
        "tall"               "200"
        "visible"            "1"
        "enabled"            "1"
    }
	
	//waves list view
	"WavesListPanel"
    {
        "ControlName"        "ListPanel"
        "fieldName"          "WavesListPanel"
        "xpos"               "5"
        "ypos"               "235"
        "wide"               "640"
        "tall"               "130"
        "visible"            "1"
        "enabled"            "1"
    }
	
	//data text entry
	"DataTextEntry"
    {
        "ControlName"        "RichText"
        "fieldName"          "DataTextEntry"
        "xpos"               "5"
        "ypos"               "375"
        "wide"               "640"
        "tall"               "155"
        "visible"            "1"
        "enabled"            "1"
    }
	"DataTextBorder"
    {
        "ControlName"        "Divider"
        "fieldName"          "DataTextBorder"
        "xpos"               "5"
        "ypos"               "375"
		"zpos"				 "-1"
        "wide"               "640"
        "tall"               "155"
        "visible"            "1"
        "enabled"            "1"
    }
	
	//event history list view
	"EventHistoryTextEntryLabel"
    {
        "ControlName"        "Label"
        "fieldName"          "EventHistoryTextEntryLabel"
        "xpos"               "5"
        "ypos"               "530"
        "wide"               "640"
        "tall"               "20"
        "visible"            "1"
        "enabled"            "1"
		"textAlignment"      "center"
		"labelText"			 "Soundscape system event history:"
    }
	"EventHistoryTextEntry"
    {
        "ControlName"        "RichText"
        "fieldName"          "EventHistoryTextEntry"
        "xpos"               "5"
        "ypos"               "555"
        "wide"               "640"
        "tall"               "120"
        "visible"            "1"
        "enabled"            "1"
    }
	"EventHistoryTextBorder"
    {
        "ControlName"        "Divider"
        "fieldName"          "EventHistoryTextBorder"
        "xpos"               "5"
        "ypos"               "555"
		"zpos"				 "-1"
        "wide"               "640"
        "tall"               "120"
        "visible"            "1"
        "enabled"            "1"
    }
	
	//show sounds check button
	"ShowInWorldSoundsCheckButton"
    {
        "ControlName" 	"CheckButton"
		"fieldName"		"ShowInWorldSoundsCheckButton"
        "xpos"          "228"
        "ypos"          "675"
        "wide"          "225"
        "tall"          "20"
		"visible"		"1"
		"enabled"		"1"
		"labelText"		"Show Sounds In The World?"
		"command"		"ToggleShowSounds"
    }
}