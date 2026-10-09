--[[
	Map Properties editor (ToggleMapProperties / mapproperties): edits the
	current map's time_info "Night" block, like the original's
	CMapPropertiesPanel pages: fog, sky & colour grade, sun, weather, clouds,
	stars, horizon fog and fog triggers.

	Each setting has a tick box: ticked = this map sets it, unticked = the
	default is used (the original's "Override" boxes). Changes preview live
	(sh_mapproperties.lua). Save writes
	data/hl2alone/map_properties/<theme or default>/<map>.txt, which loads over
	the shipped time_info; "Copy as time_info" puts the block on the
	clipboard for pasting into resource/time_info/*.txt.
]]

local KV = HL2A.KV
local TI = HL2A.TimeInfo

-- { key, type, min, max, decimals }; types: bool, int, num, color, string, sky, filter
local PAGES = {
	{ "Fog", "fog", {
		{ "fog_override", "bool" }, { "fog_enable", "int", -1, 1 }, { "fog_color", "color" },
		{ "fog_start", "num", -5000, 20000 }, { "fog_end", "num", 0, 50000 }, { "fog_maxdensity", "num", 0, 1, 2 },
		{ "r_farz", "num", 0, 100000 },
		{ "fog_enableskybox", "int", -1, 1 }, { "fog_colorskybox", "color" }, { "fog_startskybox", "num", -20000, 50000 },
		{ "fog_endskybox", "num", 0, 100000 }, { "fog_maxdensityskybox", "num", 0, 1, 2 },
	} },
	{ "Sky & Colour", nil, {
		{ "DefaultNightSky", "sky" }, { "FilterName", "filter" }, { "FilterIntensity", "num", 0, 1, 2 },
		{ "BloomEnabled", "bool" }, { "BloomScale", "num", 0, 50, 1 }, { "BloomScalarFactor", "num", 0, 5, 2 },
	} },
	{ "Sun", "sun", {
		{ "enabled", "bool" }, { "pitch", "num", -90, 90 }, { "angles", "string" }, { "use_angles", "bool" },
		{ "rendercolor", "color" }, { "size", "num", 0, 100 }, { "overlaycolor", "color" }, { "overlaysize", "num", -1, 200 },
		{ "material", "string" }, { "overlaymaterial", "string" },
	} },
	{ "Weather", "weather", {
		{ "WeatherEnabled", "bool" }, { "WeatherType", "int", 0, 3 }, { "RainIntensity", "num", 0.0002, 0.006, 4 },
		{ "RainSplashParticles", "bool" }, { "ShowSnowOnMaps", "bool" }, { "WeatherRunInIntervals", "bool" },
		{ "WeatherWaitTimeMin", "num", 10, 600 }, { "WeatherWaitTimeMax", "num", 30, 1200 },
	} },
	{ "Clouds", "clouds", {
		{ "r_clouds", "bool" }, { "r_clouds_force", "bool" }, { "r_clouds_no3dskyclip", "bool" }, { "r_clouds_material", "string" },
		{ "r_clouds_red", "int", 0, 255 }, { "r_clouds_green", "int", 0, 255 }, { "r_clouds_blue", "int", 0, 255 },
		{ "r_clouds_alpha", "int", 0, 1000 }, { "r_clouds_scrollrate_x", "num", -0.1, 0.1, 3 }, { "r_clouds_scrollrate_y", "num", -0.1, 0.1, 3 },
		{ "r_clouds_offset_x", "num", -5000, 5000 }, { "r_clouds_offset_y", "num", -5000, 5000 }, { "r_clouds_offset_z", "num", -5000, 5000 },
		{ "r_clouds_scale_x", "num", 0, 15, 2 }, { "r_clouds_scale_y", "num", 0, 15, 2 }, { "r_clouds_scale_z", "num", 0, 15, 2 },
		{ "r_clouds_angle_x", "num", -180, 180 }, { "r_clouds_angle_y", "num", -180, 180 }, { "r_clouds_angle_z", "num", -180, 180 },
		{ "r_clouds_material_scale_x", "num", 1, 3000 }, { "r_clouds_material_scale_y", "num", 1, 3000 },
	} },
	{ "Stars", "stars", {
		{ "r_stars", "bool" }, { "r_stars_size", "num", 1, 100 }, { "r_stars_raduis", "num", 16, 4096 },
		{ "r_stars_red", "int", 0, 255 }, { "r_stars_green", "int", 0, 255 }, { "r_stars_blue", "int", 0, 255 }, { "r_stars_alpha", "int", 0, 255 },
		{ "r_stars_offset_x", "num", -2000, 2000 }, { "r_stars_offset_y", "num", -2000, 2000 }, { "r_stars_offset_z", "num", -2000, 2000 },
	} },
	{ "Horizon", "horizon", {
		{ "r_horizonfog", "bool" }, { "r_horizonfog_force", "bool" }, { "r_horizonfog_pitch", "num", -90, 90 }, { "r_horizonfog_yaw", "num", -180, 360 },
		{ "r_horizonfog_width", "num", 1, 360 }, { "r_horizonfog_height", "num", 0, 4, 2 }, { "r_horizonfog_scale", "num", 0, 5, 2 },
		{ "r_horizonfog_offset_x", "num", -5000, 5000 }, { "r_horizonfog_offset_y", "num", -5000, 5000 }, { "r_horizonfog_offset_z", "num", -5000, 5000 },
		{ "r_horizonfog_top_r", "num", 0, 1, 2 }, { "r_horizonfog_top_g", "num", 0, 1, 2 }, { "r_horizonfog_top_b", "num", 0, 1, 2 },
		{ "r_horizonfog_mid_r", "num", 0, 1, 2 }, { "r_horizonfog_mid_g", "num", 0, 1, 2 }, { "r_horizonfog_mid_b", "num", 0, 1, 2 },
		{ "r_horizonfog_bot_r", "num", 0, 1, 2 }, { "r_horizonfog_bot_g", "num", 0, 1, 2 }, { "r_horizonfog_bot_b", "num", 0, 1, 2 },
		{ "r_horizonfog_alpha", "num", 0, 1, 2 },
	} },
}

-- Fog trigger variables the port understands (cl_fog.lua, sv_atmosphere.lua)
local TRIGGER_VARS = { "fog_color", "fog_start", "fog_end", "fog_maxdensity", "fog_lerp_system_lerp_time",
	"amod_trigger_filterintensity", "amod_trigger_filtername" }

local frame
local night, original   -- the block being edited, and as it was when opened
local selectedTrigger   -- for drawing

local function sub( name )
	if not name then return night end
	local b = KV.Get( night, name )
	if not istable( b ) then
		b = {}
		KV.Set( night, name, b )
	end
	return b
end

local previewPending
local function preview()
	if previewPending then return end
	previewPending = true
	timer.Simple( 0.25, function()
		previewPending = false
		if night then HL2A.PreviewMapProperties( night ) end
	end )
end

local function nightSkies()
	local out = {}
	local root = KV.ParseFile( "resource/Skyboxs.txt" )
	local list = root and KV.Get( KV.Get( root, "SkyPanel" ), "night" )
	for _, kv in ipairs( istable( list ) and list or {} ) do
		if isstring( kv.value ) then out[ #out + 1 ] = kv.value end
	end
	return out
end

local function filters()
	local out = {}
	-- Listed under their original scripts/ path (what time_info stores); the
	-- Workshop build keeps them in materials/colorcorrection/
	local seen = {}
	for _, dir in ipairs( { "scripts/colorcorrection/", "materials/colorcorrection/" } ) do
		for _, f in ipairs( file.Find( dir .. "*.raw", "GAME" ) ) do
			local path = "scripts/colorcorrection/" .. f:lower()
			if not seen[ path ] then seen[ path ] = true out[ #out + 1 ] = path end
		end
	end
	table.sort( out )
	return out
end

-- One setting row: [x] key  <control>
local function fieldRow( parent, block, f )
	local key, kind = f[ 1 ], f[ 2 ]
	local row = parent:Add( "DPanel" )
	row:Dock( TOP )
	row:SetTall( 26 )
	row:DockMargin( 0, 0, 0, 2 )
	row:SetPaintBackground( false )

	local set = row:Add( "DCheckBox" )
	set:SetPos( 2, 5 )
	set:SetTooltip( "Ticked: this map sets it. Unticked: the default is used." )
	local name = row:Add( "DLabel" )
	name:SetPos( 24, 0 ) name:SetSize( 190, 26 )
	name:SetText( key )
	name:SetDark( false )

	local cur = KV.Get( block, key )
	set:SetValue( cur ~= nil )

	local control
	local function write( v )
		KV.Set( block, key, tostring( v ) )
		set:SetValue( true )
		preview()
	end

	if kind == "bool" then
		control = row:Add( "DCheckBox" )
		control:SetPos( 220, 5 )
		control:SetValue( tobool( cur ) )
		control.OnChange = function( _, v ) write( v and 1 or 0 ) end
	elseif kind == "int" or kind == "num" then
		control = row:Add( "DNumSlider" )
		control:SetPos( 216, 0 ) control:SetSize( 300, 26 )
		control:SetMinMax( f[ 3 ], f[ 4 ] )
		control:SetDecimals( kind == "int" and 0 or ( f[ 5 ] or 0 ) )
		control.Label:SetVisible( false )
		control.PerformLayout = function( self ) self.Label:SetWide( 0 ) end
		control:SetValue( tonumber( cur ) or f[ 3 ] )
		control.OnValueChanged = function( self, v )
			if self.updating then return end
			local d = kind == "int" and 0 or ( f[ 5 ] or 0 )
			write( string.format( "%." .. d .. "f", v ) )
		end
	elseif kind == "color" then
		local c = HL2A.ParseColor( cur ) or Color( 255, 255, 255 )
		control = row:Add( "DButton" )
		control:SetPos( 220, 2 ) control:SetSize( 120, 22 )
		control:SetText( "" )
		control.Paint = function( _, w, h )
			surface.SetDrawColor( c ) surface.DrawRect( 0, 0, w, h )
			surface.SetDrawColor( 0, 0, 0 ) surface.DrawOutlinedRect( 0, 0, w, h )
		end
		control.DoClick = function()
			local pick = vgui.Create( "DFrame" )
			pick:SetTitle( key ) pick:SetSize( 280, 260 ) pick:Center() pick:MakePopup()
			local mixer = pick:Add( "DColorMixer" )
			mixer:Dock( FILL ) mixer:SetAlphaBar( false ) mixer:SetPalette( false )
			mixer:SetColor( c )
			mixer.ValueChanged = function( _, v )
				c = Color( v.r, v.g, v.b )
				write( string.format( "%d %d %d", v.r, v.g, v.b ) )
			end
		end
	else
		local choices = kind == "sky" and nightSkies() or kind == "filter" and filters() or nil
		if choices then
			control = row:Add( "DComboBox" )
			control:SetPos( 220, 2 ) control:SetSize( 296, 22 )
			for _, ch in ipairs( choices ) do control:AddChoice( ch ) end
			control:SetValue( cur or "" )
			control.OnSelect = function( _, _, v ) write( v ) end
		else
			control = row:Add( "DTextEntry" )
			control:SetPos( 220, 2 ) control:SetSize( 296, 22 )
			control:SetValue( cur or "" )
			control.OnEnter = function( self ) write( self:GetValue() ) end
			control.OnLoseFocus = function( self ) write( self:GetValue() ) end
		end
	end

	set.OnChange = function( _, v )
		if v then
			if KV.Get( block, key ) == nil then
				local val = kind == "bool" and "0" or kind == "color" and "255 255 255" or ( f[ 3 ] and tostring( f[ 3 ] ) ) or ""
				KV.Set( block, key, val )
			end
		else
			KV.Set( block, key, nil )
		end
		preview()
	end
end

local function settingsPage( sheet, page )
	local scroll = vgui.Create( "DScrollPanel", sheet )
	local block = sub( page[ 2 ] )
	for _, f in ipairs( page[ 3 ] ) do fieldRow( scroll, block, f ) end
	return scroll
end

-- Fog triggers --------------------------------------------------------------------------------

local function vecText( v ) return string.format( "%.0f %.0f %.0f", v.x, v.y, v.z ) end

local function triggersPage( sheet )
	local pg = vgui.Create( "DPanel", sheet )
	pg:SetPaintBackground( false )
	local triggers = sub( "FogCubeTriggers" )

	local list = pg:Add( "DListView" )
	list:SetPos( 0, 0 ) list:SetSize( 200, 360 )
	list:SetMultiSelect( false )
	list:AddColumn( "Trigger" )

	local x = 210
	local name = pg:Add( "DTextEntry" ) name:SetPos( x, 0 ) name:SetSize( 200, 22 )
	local mins = pg:Add( "DTextEntry" ) mins:SetPos( x, 28 ) mins:SetSize( 200, 22 )
	local maxs = pg:Add( "DTextEntry" ) maxs:SetPos( x, 56 ) maxs:SetSize( 200, 22 )
	local vars = pg:Add( "DListView" )
	vars:SetPos( x, 114 ) vars:SetSize( 320, 160 )
	vars:SetMultiSelect( false )
	vars:AddColumn( "Variable" ) vars:AddColumn( "Value" )
	local varKey = pg:Add( "DComboBox" ) varKey:SetPos( x, 280 ) varKey:SetSize( 200, 22 )
	for _, k in ipairs( TRIGGER_VARS ) do varKey:AddChoice( k ) end
	local varVal = pg:Add( "DTextEntry" ) varVal:SetPos( x + 206, 280 ) varVal:SetSize( 114, 22 )

	local current

	local function refreshVars()
		vars:Clear()
		if not current then return end
		for _, kv in ipairs( KV.Get( current.value, "Variables" ) or {} ) do vars:AddLine( kv.key, kv.value ) end
	end

	local function refresh()
		list:Clear()
		for _, t in ipairs( triggers ) do
			if istable( t.value ) then list:AddLine( t.key ).trigger = t end
		end
	end
	refresh()

	list.OnRowSelected = function( _, _, line )
		current = line.trigger
		selectedTrigger = current
		name:SetValue( current.key )
		mins:SetValue( KV.Get( current.value, "mins" ) or "" )
		maxs:SetValue( KV.Get( current.value, "maxs" ) or "" )
		refreshVars()
	end

	local function commit()
		if not current then return end
		current.key = name:GetValue()
		KV.Set( current.value, "mins", mins:GetValue() )
		KV.Set( current.value, "maxs", maxs:GetValue() )
		preview()
	end
	for _, e in ipairs( { name, mins, maxs } ) do e.OnEnter = commit e.OnLoseFocus = commit end

	local function btn( text, bx, by, w, fn )
		local b = pg:Add( "DButton" ) b:SetPos( bx, by ) b:SetSize( w, 22 ) b:SetText( text ) b.DoClick = fn
	end
	btn( "Mins = my position", x + 206, 28, 114, function()
		if not current then return end
		mins:SetValue( vecText( LocalPlayer():GetPos() ) ) commit()
	end )
	btn( "Maxs = my position", x + 206, 56, 114, function()
		if not current then return end
		maxs:SetValue( vecText( LocalPlayer():GetPos() + Vector( 0, 0, 72 ) ) ) commit()
	end )
	local hint = pg:Add( "DLabel" ) hint:SetPos( x, 84 ) hint:SetSize( 320, 26 )
	hint:SetText( "Name, mins, maxs (Enter to apply). Variables apply inside the box:" )
	hint:SetDark( false )

	btn( "Set variable", x, 308, 156, function()
		if not current or varKey:GetValue() == "" then return end
		local v = KV.Get( current.value, "Variables" )
		if not istable( v ) then v = {} KV.Set( current.value, "Variables", v ) end
		KV.Set( v, varKey:GetValue(), varVal:GetValue() )
		refreshVars() preview()
	end )
	btn( "Remove variable", x + 164, 308, 156, function()
		local _, line = vars:GetSelectedLine()
		if not current or not line then return end
		KV.Set( KV.Get( current.value, "Variables" ), line:GetColumnText( 1 ), nil )
		refreshVars() preview()
	end )
	vars.OnRowSelected = function( _, _, line ) varKey:SetValue( line:GetColumnText( 1 ) ) varVal:SetValue( line:GetColumnText( 2 ) ) end

	btn( "New trigger around me", 0, 366, 200, function()
		local p = LocalPlayer():GetPos()
		local t = { key = "Trigger" .. ( #triggers + 1 ), value = {
			{ key = "mins", value = vecText( p - Vector( 256, 256, 64 ) ) },
			{ key = "maxs", value = vecText( p + Vector( 256, 256, 256 ) ) },
			{ key = "Variables", value = {} },
		} }
		triggers[ #triggers + 1 ] = t
		refresh() preview()
	end )
	btn( "Delete trigger", 0, 392, 200, function()
		if not current then return end
		for i, t in ipairs( triggers ) do if t == current then table.remove( triggers, i ) break end end
		current, selectedTrigger = nil, nil
		refresh() refreshVars() preview()
	end )
	return pg
end

-- Draw trigger boxes while the editor is open
hook.Add( "PostDrawTranslucentRenderables", "hl2a.mapprops", function( _, sky )
	if sky or not IsValid( frame ) or not night then return end
	for _, t in ipairs( KV.Get( night, "FogCubeTriggers" ) or {} ) do
		if istable( t.value ) then
			local a, b = HL2A.ParseVector( KV.Get( t.value, "mins" ) ), HL2A.ParseVector( KV.Get( t.value, "maxs" ) )
			if a and b then
				OrderVectors( a, b )
				render.DrawWireframeBox( vector_origin, angle_zero, a, b, t == selectedTrigger and Color( 255, 220, 0 ) or Color( 80, 160, 255 ), true )
			end
		end
	end
end )

-- Frame -----------------------------------------------------------------------------------------

-- Drops sub-blocks left empty (pages create them when opened)
local function pruned( block )
	local out = {}
	for _, kv in ipairs( block ) do
		if not istable( kv.value ) then out[ #out + 1 ] = kv
		else
			local p = pruned( kv.value )
			if #p > 0 or kv.key == "Variables" then out[ #out + 1 ] = { key = kv.key, value = p } end
		end
	end
	return out
end

local function wrap( map )
	return { { key = map, value = { { key = "Night", value = pruned( night ) } } } }
end

local function open()
	local block = TI.GetCurrentBlock()
	original = block and KV.Copy( block ) or {}
	night = KV.Copy( original )

	frame = vgui.Create( "DFrame" )
	frame:SetTitle( "Map Properties - " .. HL2A.Map() )
	frame:SetSize( 580, 520 )
	frame:Center()
	frame:MakePopup()
	frame.OnRemove = function() selectedTrigger = nil end

	local sheet = frame:Add( "DPropertySheet" )
	sheet:Dock( FILL )
	for _, page in ipairs( PAGES ) do sheet:AddSheet( page[ 1 ], settingsPage( sheet, page ) ) end
	sheet:AddSheet( "Fog Triggers", triggersPage( sheet ) )

	local bar = frame:Add( "DPanel" )
	bar:Dock( BOTTOM ) bar:SetTall( 30 ) bar:DockPadding( 0, 6, 0, 0 )
	bar:SetPaintBackground( false )
	local function barButton( text, tip, fn )
		local b = bar:Add( "DButton" )
		b:Dock( LEFT ) b:DockMargin( 0, 0, 6, 0 ) b:SetText( text ) b:SizeToContentsX( 20 )
		b:SetTooltip( tip ) b.DoClick = fn
	end

	barButton( "Save", "Keep these settings for this map (data/hl2alone/map_properties/).", function()
		file.CreateDir( TI.OverrideDir() )
		file.Write( TI.OverrideDir() .. HL2A.Map() .. ".txt", KV.Write( wrap( HL2A.Map() ) ) )
		original = KV.Copy( night )
		notification.AddLegacy( "Map properties saved", NOTIFY_GENERIC, 3 )
	end )
	barButton( "Revert", "Undo the changes made since opening or the last save.", function()
		night = KV.Copy( original )
		HL2A.PreviewMapProperties( night )
		frame:Remove()
		timer.Simple( 0.1, open )
	end )
	barButton( "Mod default", "Delete this map's saved properties and go back to the mod's time_info.", function()
		Derma_Query( "Delete this map's saved properties?", "Map Properties", "Delete", function()
			file.Delete( TI.OverrideDir() .. HL2A.Map() .. ".txt" )
			RunConsoleCommand( "hl2a_timeinfo_reload" )
			frame:Remove()
			timer.Simple( 0.5, open )
		end, "Cancel" )
	end )
	barButton( "Copy as time_info", "Copy this map's block in time_info format, to paste into resource/time_info/*.txt.", function()
		SetClipboardText( KV.Write( wrap( HL2A.Map() ) ) )
		notification.AddLegacy( "Copied to the clipboard", NOTIFY_GENERIC, 3 )
	end )
end

function HL2A.ToggleMapProperties()
	if IsValid( frame ) then frame:Remove() return end
	open()
end

concommand.Add( "ToggleMapProperties", HL2A.ToggleMapProperties, nil, "Map Properties editor (time_info for the current map)" )
concommand.Add( "mapproperties", HL2A.ToggleMapProperties )
