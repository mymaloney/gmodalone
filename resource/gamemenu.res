"GameMenu"
{
	"1"
	{
		"label" "#GameUI_GameMenu_ResumeGame"
		"command" "ResumeGame"
		"InGameOrder" "10"
		"OnlyInGame" "1"
	}
	"5"	
	{	
		"label" "#GameUI_GameMenu_NewGame"
		"command" "engine ToggleNewGamePanel"	[$WINDOWS]
		"command" "OpenNewGameDialog"			[!$WINDOWS]
		"InGameOrder" "25"
		"notmulti" "1"
	}
	"2"
	{
		"label" "#GameUI_GameMenu_BonusMaps"
		"command" "OpenBonusMapsDialog"
		"InGameOrder" "28"
		"notmulti" "1"
	}	
	"6"
	{
		"label" "#GameUI_GameMenu_LoadGame"
		"command" "OpenLoadGameDialog"
		"InGameOrder" "30"
		"notmulti" "1"
	}
	"7"
	{
		"label" "#GameUI_GameMenu_SaveGame"
		"command" "OpenSaveGameDialog"
		"InGameOrder" "40"
		"notmulti" "1"
		"OnlyInGame" "1"
	}
	"7_5"
	{
		"label" "#GameUI_GameMenu_ActivateVR"
		"command" "engine vr_activate"
		"InGameOrder" "50"
		"OnlyWhenVREnabled" "1"
		"OnlyWhenVRInactive" "1"
	}
	"7_6"
	{
		"label" "#GameUI_GameMenu_DeactivateVR"
		"command" "engine vr_deactivate"
		"InGameOrder" "60"
		"OnlyWhenVREnabled" "1"
		"OnlyWhenVRActive" "1"
	}
	"10"
	{
		"label" "#GameUI_GameMenu_Options"
		"command" "OpenOptionsDialog"
		"InGameOrder" "90"
	}
	"11"
	{
		"label" "#GameUI_GameMenu_Achievements"
		"command" "openachievementsdialog"
		"InGameOrder" "95"
	}
	"12"		[$WINDOWS]
	{
		"label" "#GameUI_GameMenu_AModOptions"
		"command" "engine ToggleOptionsPanel"
		"InGameOrder" "100"
	}
	"12.5"		[$WINDOWS]
	{
		"label" "#GameUI_GameMenu_AModWeather"
		"command" "engine ToggleWeatherPanel"
		"InGameOrder" "105"
	}
	//"12.75"
	//{
	//	"label" "#GameUI_GameMenu_GeoGuesser"
	//	"command" "engine gg_toggle"
	//	"InGameOrder" "107"
	//}
	"13"		[$WINDOWS]
	{
		"label" "#GameUI_GameMenu_MainMenu"
		"command" "engine ToggleBackgroundPanel"
		"InGameOrder" "110"
	}
	"14"		[!$WINDOWS]
	{
		"label" "#GameUI_LinuxFix"
		"command" "engine alias quit"
		"InGameOrder" "120"
	}
	"15"
	{
		//i hard coded it so the game crashes when you play the maps not in half life 2 alone mod
		//the only way to fix it for linux
		"label" "#GameUI_GameMenu_Quit"
		"command" "Quit"	[$WINDOWS]
		"command" "engine Test_ProxyToggle_EnsureValue" [!$WINDOWS]	//this crashes the game
		"InGameOrder" "130"
	}
}

