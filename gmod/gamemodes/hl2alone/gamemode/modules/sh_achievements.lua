--[[
	Alone mod achievements, driven by the maps' logic_achievement entities
	(AchievementEvent = ACHIEVEMENT_EVENT_<component>, input FireEvent).

	GMod's achievement system can't take custom achievements, so progress is
	tracked here and saved to data/hl2alone/achievements.json.
	Names/descriptions come from the mod's localization (#<ID>_NAME / _DESC).
]]

HL2A.Achievements = HL2A.Achievements or {}
local A = HL2A.Achievements

local NEW_LOCATIONS = {
	"APARTMENTS_RAID_ROOM", "APARTMENTS_UPSTAIRS_ROOM", "C17_04_NEW_APARTMENTS", "C17_04_NEW_EP1_APARTMENTS",
	"C17_05_NEW_APARTMENTS_DOWNSTAIRS", "C17_05_NEW_APARTMENTS_UPSTAIRS", "C17_05_NEW_OFFICES", "C17_06B_OUTSIDE",
	"C17_07_BRIDGE", "C17_07_MEETING_ROOM", "C17_07_SUBURBEN_BLOCK", "C17_09_TO_07_CONTINUITY",
	"C17_10A_CITY_STREET", "C17_13_STREET", "CANALS_BARN", "CANALS_CARGO_DECK", "CANALS_DAM", "CANALS_RAILLINE",
	"CANALS_SEWERS_ABOVE", "CANALS_SEWERS_ABOVE2", "CANALS_STATION_FROM_START", "CANALS_TRAINLINE",
	"CANALS_UNDER_HIGHWAY", "CANALS_VENT", "CANALS_WAREHOUSE_11", "CANALS_WAREHOUSE_CARGO_DECK",
	"CANALS_WAREHOUSE_CARGO_STORAGE_DECK", "CANALS_WAREHOUSE_NEXT_TO_STATION", "CANALS_WAREHOUSE_OUTSIDE",
	"CANALS_WAREHOUSE_SIDE_OUTSIDE", "COAST_DECK", "COAST_DECK2", "COAST_WAREHOUSE", "ELI_LAB_ELECTRICITY_ROOM",
	"KLAB_OUTSIDE_LADDER", "PLAZA_OUTSIDE_NEW_APARTMENTS", "PRISON_BLOCKED_DOOR", "PRISON_CELLS",
	"PRISON_COMBINE_CELLS", "PRISON_EZ2_SPOT", "PRISON_GUARD_ROOMS", "PRISON_HALLWAY", "RAV_TO_COAST_TRAINLINE",
	"RAV_TO_COAST_WAREHOUSE", "RAV_TO_COAST_WAREHOUSE_2", "STATION_APARTMENTS_STREETS", "STATION_SECURITY",
	"STATION_STREET_STORAGE_ABOVE", "STATION_TOCANROOM", "STATION_TONPROSPEKT", "TOWN_YARD",
}

local BUTTONS = {
	"PORTAL1_01", "PORTAL1_04", "PORTAL1_09", "PORTAL1_12", "PORTAL1_14", "PORTAL1_16", "PORTAL2_06",
}

local function components( prefix, list )
	local out = {}
	for i, c in ipairs( list ) do out[ i ] = prefix .. c end
	return out
end

-- Ordered list of { id, components = { event component ids } }
A.List = {
	{ id = "AMOD_FIND_NEWLOCATIONS", components = components( "AMOD_NEW_LOCATIONS_", NEW_LOCATIONS ) },
	{ id = "AMOD_PORTAL_FACILITY", components = { "AMOD_PORTAL_FACILITY" } },
	{ id = "AMOD_PORTAL_PRESS_ALL_BUTTONS", components = components( "AMOD_PORTAL_PRESS_ALL_BUTTONS_BUTTON_", BUTTONS ) },
}

-- component -> achievement
A.ByComponent = {}
for _, ach in ipairs( A.List ) do
	for _, c in ipairs( ach.components ) do A.ByComponent[ c ] = ach end
end

--- Progress for an achievement given a set of completed components.
function A.Progress( ach, done )
	local n = 0
	for _, c in ipairs( ach.components ) do if done[ c ] then n = n + 1 end end
	return n, #ach.components
end
