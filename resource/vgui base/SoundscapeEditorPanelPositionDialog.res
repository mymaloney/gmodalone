"resource/vgui base/SoundscapeEditorPositionDialog.res"
{
    "SoundscapePositionEditorPanel"
    {
        "ControlName"        "CSoundscapePositionEditorPanel"
        "fieldName"          "SoundscapePositionEditorPanel"
        "xpos"               "c-175"
        "ypos"               "c-175"
        "wide"               "350"
        "tall"               "350"
        "visible"            "1"
        "enabled"            "1"
        "settitlebarvisible" "1"
		"title"				 "Soundscape Position Editor"
    }
	
	"SoundscapePositionListPanel"
    {
        "ControlName"        "CSoundscapePositionListPanel"
        "fieldName"          "SoundscapePositionListPanel"
        "xpos"               "5"
        "ypos"               "30"
        "wide"               "340"
        "tall"               "285"
        "visible"            "1"
        "enabled"            "1"
    }
	
	"AlwaysShowPositionsCheckButton"
	{
		"ControlName" 	"CheckButton"
		"fieldName"		"AlwaysShowPositionsCheckButton"
        "xpos"          "90"
        "ypos"          "320"
        "wide"          "220"
        "tall"          "20"
		"visible"		"1"
		"enabled"		"1"
		"labelText"		"Always Show Positions"
		"command"		"AlwaysShowPositions"
	}
}