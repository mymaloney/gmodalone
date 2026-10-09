--[[
	Server-side atmosphere from time_info: skybox, env_sun and the
	colour-correction "epic filter" (including FogCubeTrigger
	amod_trigger_filterintensity overrides).

	Fog is applied client-side in cl_fog.lua.
]]

local CV = HL2A.ConVars
local TI = HL2A.TimeInfo
local KV = HL2A.KV

local function applySky()
	local block = TI.GetCurrentBlock()

	local sky = CV.amod_night_sky:GetString()
	if sky == "" then sky = KV.Get( block, "DefaultNightSky" ) or "" end

	-- Skybox names in time_info may carry a "%lf"-style face suffix
	sky = sky:gsub( "%%.*$", "" )
	if sky ~= "" then RunConsoleCommand( "sv_skyname", sky ) end
end

local function applySun()
	local sun = TI.GetSubTable( "sun" )
	for _, ent in ipairs( ents.FindByClass( "env_sun" ) ) do
		if CV.amod_sun_disable:GetBool() then
			ent:Fire( "TurnOff" )
		elseif next( sun ) then
			for k, v in pairs( sun ) do ent:SetKeyValue( k, v ) end
			ent:Fire( "TurnOn" )
		end
	end
end

-- Colour correction ---------------------------------------------------------

local cc, ccFile, ccWeight

local function wantedFilter()
	if not CV.amod_epic_filter:GetBool() then return nil end

	local block = TI.GetCurrentBlock()

	local name = KV.Get( block, "FilterName" )
	if not name or name == "" then name = CV.amod_epic_filter_night_filename:GetString() end

	local weight = tonumber( KV.Get( block, "FilterIntensity" ) ) or CV.amod_epic_filter_night_intensity:GetFloat()

	local ply = Entity( 1 )
	if IsValid( ply ) then
		local vars = TI.GetTriggerVars( ply:GetPos() )
		local override = vars and tonumber( vars.amod_trigger_filterintensity )
		if override then weight = override end
	end

	return name:gsub( "\\", "/" ), weight
end

local function updateFilter()
	local name, weight = wantedFilter()

	if not name then
		if IsValid( cc ) then cc:Remove() end
		cc, ccFile, ccWeight = nil, nil, nil
		return
	end

	if not IsValid( cc ) or ccFile ~= name then
		if IsValid( cc ) then cc:Remove() end
		cc = ents.Create( "color_correction" )
		cc:SetKeyValue( "filename", name )
		cc:SetKeyValue( "minfalloff", "-1" )
		cc:SetKeyValue( "maxfalloff", "-1" )
		cc:SetKeyValue( "fadeInDuration", "1" )
		cc:SetKeyValue( "fadeOutDuration", "1" )
		cc:Spawn()
		ccFile, ccWeight = name, nil
	end

	if ccWeight ~= weight then
		-- maxweight is only read when the entity is (re)enabled
		cc:SetKeyValue( "maxweight", tostring( weight ) )
		cc:Fire( "Disable" )
		cc:Fire( "Enable", "", 0.05 )
		ccWeight = weight
	end
end

-- Lifecycle -----------------------------------------------------------------

function HL2A.ApplyAtmosphere()
	SetGlobal2Bool( "hl2a.epicfilter", CV.amod_epic_filter:GetBool() )
	applySky()
	applySun()
	ccWeight = nil
	updateFilter()
end

hook.Add( "InitPostEntity", "hl2a.atmosphere", function()
	timer.Simple( 0, HL2A.ApplyAtmosphere )
end )
hook.Add( "PostCleanupMap", "hl2a.atmosphere", function()
	cc = nil
	HL2A.ApplyAtmosphere()
end )

timer.Create( "hl2a.filter", 0.25, 0, updateFilter )

for _, name in ipairs( { "amod_night_sky", "amod_sun_disable", "hl2a_timeinfo_theme",
	"amod_epic_filter", "amod_epic_filter_night_filename", "amod_epic_filter_night_intensity" } ) do
	cvars.AddChangeCallback( name, function() timer.Simple( 0, HL2A.ApplyAtmosphere ) end, "hl2a.atmosphere" )
end

concommand.Add( "ToggleEpicFilter", function( ply )
	if IsValid( ply ) and not ply:IsListenServerHost() then return end
	RunConsoleCommand( "amod_epic_filter", CV.amod_epic_filter:GetBool() and "0" or "1" )
end, nil, "Toggles The Alone Mod Epic Filter" )
