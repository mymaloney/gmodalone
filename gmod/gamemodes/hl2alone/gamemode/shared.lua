--[[
	Half-Life 2: Alone - Garry's Mod port.

	The Source mod's behaviour lived in compiled client.dll/server.dll, which
	GMod cannot load, so each feature is re-implemented in Lua under
	core/ (infrastructure) and modules/ (features). Files are realm-routed by
	prefix: sh_ = shared, sv_ = server, cl_ = client.

	Derives from sandbox so noclip/spawnmenu stay available while porting.
]]

DeriveGamemode( "sandbox" )

GM.Name = "Half-Life 2: Alone"
GM.Author = "WadDelz (original mod), GMod port"
GM.Website = "moddb.com/mods/half-life-2-alone-mod"

HL2A = HL2A or {}

local ROOT = GM.FolderName .. "/gamemode/"

function HL2A.Include( rel )
	local prefix = rel:match( "([^/]+)$" ):sub( 1, 3 )
	local path = ROOT .. rel

	if prefix == "sv_" then
		if SERVER then include( path ) end
	elseif prefix == "cl_" then
		if SERVER then AddCSLuaFile( path ) else include( path ) end
	else
		if SERVER then AddCSLuaFile( path ) end
		include( path )
	end
end

-- Order matters: later files use what earlier ones define.
local FILES = {
	"core/sh_keyvalues.lua",
	"core/sh_data.lua",
	"core/sh_convars.lua",
	"core/sh_timeinfo.lua",
	"core/sh_sounds.lua",
	"core/cl_localization.lua",

	"modules/sv_settings.lua",
	"modules/sv_player.lua",
	"modules/sv_atmosphere.lua",
	"modules/cl_fog.lua",
	"modules/cl_view.lua",
	"modules/cl_screenfilter.lua",
	"modules/cl_effects.lua",
	"modules/cl_effectspanel.lua",
	"modules/cl_weatherpanel.lua",
	"modules/sv_effects.lua",
	"modules/cl_flashlight.lua",
	"modules/sv_weather.lua",
	"modules/sh_stormfox.lua",
	"modules/cl_weather.lua",
	"modules/sv_soundscapes.lua",
	"modules/cl_weathersound.lua",
	"modules/sh_breath.lua",
	"modules/cl_bloom.lua",
	"modules/cl_sky.lua",
	"modules/cl_snowmaterials.lua",
	"modules/cl_music.lua",
	"modules/sh_chapters.lua",
	"modules/sv_chapters.lua",
	"modules/cl_chapters.lua",
	"modules/sv_mapcommands.lua",
	"modules/cl_mapcommands.lua",
	"modules/sv_timers.lua",
	"modules/sv_transitions.lua",
	"modules/cl_transitions.lua",
	"modules/sv_mappatches.lua",
	"modules/sh_achievements.lua",
	"modules/sv_achievements.lua",
	"modules/cl_achievements.lua",
	"modules/sh_options.lua",
	"modules/sv_options.lua",
	"modules/cl_options.lua",
	"modules/sh_sandbox.lua",
	"modules/sh_mapproperties.lua",
	"modules/cl_mapproperties.lua",
	"modules/cl_soundscapeeditor.lua",
	"modules/cl_backgroundpanel.lua",
	"modules/sv_graphs.lua",
	"modules/sv_video.lua",
	"modules/cl_video.lua",
	"modules/cl_credits.lua",
	"modules/sv_dev.lua",
}

for _, f in ipairs( FILES ) do HL2A.Include( f ) end

function GM:Initialize()
	self.BaseClass.Initialize( self )

	HL2A.TimeInfo.Load()
	HL2A.LoadSoundScripts()
	HL2A.LoadParticles()
	if CLIENT then HL2A.LoadLocalization() end
end
