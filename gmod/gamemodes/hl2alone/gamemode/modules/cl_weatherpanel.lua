--[[
	Weather panel (toggleweatherpanel / ToggleWeatherPanel, original key T;
	also a button on the chapter select). Rebuilt from the original's
	resource/panels/WeatherPanel*.txt pages and client.dll:

	Weather     override + type (none/rain/snow/ash); per type: rain splashes,
	            rain intensity 1-100 -> amod_weather_rain_density
	            0.0002 + (i - 1) / 99 * 0.0058, snow-covered maps (snow only),
	            intervals with wait min 10-600 / max 30-1200 s (swapped if
	            min > max).
	Atmosphere  clouds (with colour override), horizon fog, stars
	            (cl_sky.lua), disable sun, thunder, breath.
	Skybox      the night skies from resource/Skyboxs.txt with a preview.
	            The original's sky angle slider needed its engine changes, so
	            it's left out.

	Changes are staged until Apply, like the original.
]]

local CV = HL2A.ConVars
local KV = HL2A.KV

local function phrase( token ) return ( language.GetPhrase( ( token:gsub( "^#", "" ) ) ):gsub( "\\n", "\n" ) ) end
local function P( key ) return phrase( "#Amod_WeatherPanel_" .. key ) end

local DENSITY_MIN, DENSITY_RANGE = 0.0002, 0.0058

local function densityToSlider( d ) return math.Clamp( math.Round( ( d - DENSITY_MIN ) / DENSITY_RANGE * 99 + 1 ), 1, 100 ) end
local function sliderToDensity( i ) return DENSITY_MIN + ( i - 1 ) / 99 * DENSITY_RANGE end

local panel

--- Night skies from resource/Skyboxs.txt: { { name, sky, face } }
local function nightSkies()
	local out = {}
	local root = KV.ParseFile( "resource/Skyboxs.txt" )
	local night = root and KV.Get( KV.Get( root, "SkyPanel" ), "night" )
	for _, kv in ipairs( istable( night ) and night or {} ) do
		if isstring( kv.value ) then
			local sky, face = kv.value:match( "^([^%%]+)%%?(%a*)$" )
			if sky then out[ #out + 1 ] = { kv.key, sky, face ~= "" and face or "ft" } end
		end
	end
	return out
end

local function build()
	local pending = {}
	local function value( name ) return pending[ name ] or CV[ name ]:GetString() end
	local function set( name, v ) pending[ name ] = tostring( v ) end

	local frame = vgui.Create( "DFrame" )
	frame:SetTitle( P( "Title" ) )
	frame:SetSize( 300, 470 )
	frame:Center()
	frame:SetDeleteOnClose( true )

	local sheet = frame:Add( "DPropertySheet" )
	sheet:Dock( FILL )

	local function check( parent, text, tip, x, y, name, enabled )
		local cb = parent:Add( "DCheckBoxLabel" )
		cb:SetPos( x, y )
		cb:SetText( text )
		cb:SizeToContents()
		if tip then cb:SetTooltip( tip ) end
		if name then
			cb:SetValue( tobool( value( name ) ) )
			cb.OnChange = function( _, v ) set( name, v and 1 or 0 ) end
		end
		if enabled == false then cb:SetEnabled( false ) end
		return cb
	end

	local function heading( parent, text, y )
		local l = parent:Add( "DLabel" )
		l:SetPos( 0, y )
		l:SetSize( 260, 18 )
		l:SetText( text )
		l:SetFont( "DermaDefaultBold" )
		return l
	end

	local function slider( parent, fmt, tip, y, min, max, get, onChange )
		local l = parent:Add( "DLabel" )
		l:SetPos( 10, y )
		l:SetSize( 245, 18 )
		local s = parent:Add( "DNumSlider" )
		s:SetPos( 6, y + 18 )
		s:SetSize( 250, 22 )
		s:SetMinMax( min, max )
		s:SetDecimals( 0 )
		s.Label:SetVisible( false )
		s.PerformLayout = function( self ) self.Label:SetWide( 0 ) end
		if tip then s:SetTooltip( tip ) end
		s:SetValue( get() )
		l:SetText( string.format( fmt, get() ) )
		s.OnValueChanged = function( _, v )
			v = math.Round( v )
			l:SetText( string.format( fmt, v ) )
			onChange( v )
		end
		return { l, s }
	end

	-- Weather page ------------------------------------------------------------------------

	local wp = vgui.Create( "DPanel", sheet )
	wp:SetPaintBackground( false )
	local WP = "WeatherPage_"

	check( wp, P( WP .. "OverrideWeather" ), P( WP .. "ToolTip_OverrideWeather" ), 10, 10, "amod_weather_override" )

	local typeBox = wp:Add( "DComboBox" )
	typeBox:SetPos( 10, 35 )
	typeBox:SetSize( 240, 22 )
	typeBox:SetSortItems( false )
	typeBox:SetTooltip( P( WP .. "ToolTip_WeatherType" ) )
	local curType = tonumber( value( "amod_weather_type" ) ) or 0
	for t = 0, 3 do typeBox:AddChoice( P( WP .. "WeatherType" .. t ), t, t == curType ) end

	heading( wp, P( WP .. "SettingsLabel" ), 65 )

	-- Each weather type shows its own controls, at the original's positions
	local controls = {}
	local function at( widgets, positions ) controls[ #controls + 1 ] = { widgets = widgets, pos = positions } end

	local splashes = check( wp, P( WP .. "EnableRainSplashes" ), P( WP .. "ToolTip_RainSplashParticles" ), 5, 95, "amod_weather_rain_splashes" )
	at( { splashes }, { [ 1 ] = 95 } )

	local intensity = slider( wp, P( WP .. "RainIntensity" ), P( WP .. "ToolTip_RainIntensity" ), 115, 1, 100,
		function() return densityToSlider( tonumber( value( "amod_weather_rain_density" ) ) or 0.001 ) end,
		function( v ) set( "amod_weather_rain_density", sliderToDensity( v ) ) end )
	at( intensity, { [ 1 ] = 115 } )

	local snowMaps = check( wp, P( WP .. "ShowSnowOnMaps" ), P( WP .. "ToolTip_SnowOnMaps" ), 5, 93, "amod_weather_snow_show_on_maps" )
	at( { snowMaps }, { [ 2 ] = 93 } )

	local intervals = check( wp, P( WP .. "InIntervals" ), nil, 5, 165, "amod_weather_do_in_intervals" )
	at( { intervals }, { [ 1 ] = 165, [ 2 ] = 113, [ 3 ] = 93 } )

	local waitMin = slider( wp, P( WP .. "IntervalTimeMin" ), nil, 185, 10, 600,
		function() return tonumber( value( "amod_weather_wait_min" ) ) or 300 end,
		function( v ) set( "amod_weather_wait_min", v ) end )
	at( waitMin, { [ 1 ] = 185, [ 2 ] = 135, [ 3 ] = 115 } )

	local waitMax = slider( wp, P( WP .. "IntervalTimeMax" ), nil, 230, 30, 1200,
		function() return tonumber( value( "amod_weather_wait_max" ) ) or 600 end,
		function( v ) set( "amod_weather_wait_max", v ) end )
	at( waitMax, { [ 1 ] = 230, [ 2 ] = 180, [ 3 ] = 160 } )

	local function layout( t )
		for _, c in ipairs( controls ) do
			local y = c.pos[ t ]
			for i, w in ipairs( c.widgets ) do
				w:SetVisible( y ~= nil )
				if y then w:SetY( y + ( i - 1 ) * 18 ) end
			end
		end
	end
	layout( curType )
	typeBox.OnSelect = function( _, _, _, t )
		set( "amod_weather_type", t )
		layout( t )
	end

	sheet:AddSheet( P( WP .. "Title" ), wp )

	-- Atmosphere page ----------------------------------------------------------------------

	local ap = vgui.Create( "DPanel", sheet )
	ap:SetPaintBackground( false )
	local AP = "AtmospherePage_"

	heading( ap, P( AP .. "CloudsLabel" ), 2 )
	check( ap, P( AP .. "EnableClouds" ), P( AP .. "ToolTip_EnableClouds" ), 10, 25, "r_clouds_enable" )
	check( ap, P( AP .. "OverrideCloudsColor" ), P( AP .. "ToolTip_OverrideCloudsColor" ), 10, 45, "r_clouds_color_override" )

	local function cloudColor()
		return Color( tonumber( value( "r_clouds_red_override" ) ) or 255, tonumber( value( "r_clouds_green_override" ) ) or 255,
			tonumber( value( "r_clouds_blue_override" ) ) or 255 )
	end
	local color = ap:Add( "DButton" )
	color:SetPos( 10, 65 )
	color:SetSize( 200, 20 )
	color:SetText( P( AP .. "SetCloudsColor" ) )
	color:SetTooltip( P( AP .. "ToolTip_SetCloudsColor" ) )
	local swatch = ap:Add( "DPanel" )
	swatch:SetPos( 216, 65 )
	swatch:SetSize( 34, 20 )
	swatch.Paint = function( _, w, h )
		surface.SetDrawColor( cloudColor() ) surface.DrawRect( 0, 0, w, h )
		surface.SetDrawColor( 0, 0, 0 ) surface.DrawOutlinedRect( 0, 0, w, h )
	end
	color.DoClick = function()
		local pick = vgui.Create( "DFrame" )
		pick:SetTitle( P( AP .. "SetCloudsColor" ) )
		pick:SetSize( 280, 260 )
		pick:Center()
		pick:MakePopup()
		local mixer = pick:Add( "DColorMixer" )
		mixer:Dock( FILL )
		mixer:SetAlphaBar( false )
		mixer:SetPalette( false )
		mixer:SetColor( cloudColor() )
		mixer.ValueChanged = function( _, c )
			set( "r_clouds_red_override", c.r ) set( "r_clouds_green_override", c.g ) set( "r_clouds_blue_override", c.b )
		end
	end

	heading( ap, P( AP .. "HorizonLabel" ), 90 )
	check( ap, P( AP .. "EnableHorizon" ), P( AP .. "ToolTip_EnableHorizon" ), 10, 110, "r_horizonfog_enable" )

	heading( ap, P( AP .. "StarsLabel" ), 130 )
	check( ap, P( AP .. "EnableStars" ), P( AP .. "ToolTip_EnableStars" ), 10, 150, "r_stars_enable" )
	check( ap, P( AP .. "ForceStars" ), P( AP .. "ToolTip_ForceStars" ), 10, 170, "r_stars_force" )

	heading( ap, P( AP .. "SunLabel" ), 190 )
	check( ap, P( AP .. "DisableSun" ), P( AP .. "ToolTip_DisableSun" ), 10, 210, "amod_sun_disable" )

	heading( ap, P( AP .. "OtherLabel" ), 230 )
	check( ap, P( AP .. "EnableThunder" ), P( AP .. "ToolTip_EnableThunder" ), 10, 250, "amod_weather_thunder" )
	check( ap, P( AP .. "ShowBreaths" ), P( AP .. "ToolTip_ShowBreaths" ), 10, 270, "amod_do_breathing" )

	sheet:AddSheet( P( AP .. "Title" ), ap )

	-- Skybox page -----------------------------------------------------------------------------

	local sp = vgui.Create( "DPanel", sheet )
	sp:SetPaintBackground( false )

	local image = sp:Add( "DImage" )
	image:SetPos( 10, 10 )
	image:SetSize( 240, 240 )

	local skyBox = sp:Add( "DComboBox" )
	skyBox:SetPos( 10, 258 )
	skyBox:SetSize( 240, 22 )
	skyBox:SetSortItems( false )

	local function preview( sky, face )
		local mat = sky and ( "skybox/" .. sky .. face )
		image:SetVisible( mat ~= nil and file.Exists( "materials/" .. mat .. ".vmt", "GAME" ) )
		if mat then image:SetImage( mat ) end
	end

	local cur = value( "amod_night_sky" ):gsub( "%%.*$", "" ):lower()
	skyBox:AddChoice( "Map default", { "", nil, nil }, cur == "" )
	for _, s in ipairs( nightSkies() ) do
		skyBox:AddChoice( s[ 1 ], { s[ 2 ], s[ 2 ], s[ 3 ] }, s[ 2 ]:lower() == cur )
	end
	local _, sel = skyBox:GetSelected()
	if sel then preview( sel[ 2 ], sel[ 3 ] ) else preview() end
	skyBox.OnSelect = function( _, _, _, d )
		set( "amod_night_sky", d[ 1 ] )
		preview( d[ 2 ], d[ 3 ] )
	end

	local note = sp:Add( "DLabel" )
	note:SetPos( 10, 287 )
	note:SetSize( 240, 40 )
	note:SetWrap( true )
	note:SetText( "If the sky doesn't change straight away, it will on the next map load." )

	sheet:AddSheet( P( "SkyboxPage_Title" ), sp )

	-- Apply -----------------------------------------------------------------------------------

	local apply = frame:Add( "DButton" )
	apply:Dock( BOTTOM )
	apply:DockMargin( 0, 6, 0, 0 )
	apply:SetTall( 26 )
	apply:SetText( P( "ApplyButtonText" ) )
	apply.DoClick = function()
		local t = tonumber( value( "amod_weather_type" ) ) or 0
		local override = tobool( value( "amod_weather_override" ) )

		-- As the original: max is at least min, snow-covered maps only with snow overriding
		local wMin, wMax = tonumber( value( "amod_weather_wait_min" ) ) or 300, tonumber( value( "amod_weather_wait_max" ) ) or 600
		if wMin > wMax then set( "amod_weather_wait_min", wMax ) set( "amod_weather_wait_max", wMin ) end
		set( "amod_weather_snow_show_on_maps", ( override and t == 2 and tobool( value( "amod_weather_snow_show_on_maps" ) ) ) and 1 or 0 )
		set( "hl2a_weather_enable", t ~= 0 and 1 or 0 )

		local list = {}
		for name, v in pairs( pending ) do
			if CV[ name ] and CV[ name ]:GetString() ~= v then
				if HL2A.ClientConVars[ name ] then RunConsoleCommand( name, v ) else list[ #list + 1 ] = { name, v } end
			end
		end
		if #list > 0 then
			net.Start( "hl2a.options" )
				net.WriteUInt( #list, 8 )
				for _, kv in ipairs( list ) do net.WriteString( kv[ 1 ] ) net.WriteString( kv[ 2 ] ) end
			net.SendToServer()
		end
		frame:Close()
	end

	return frame
end

function HL2A.ToggleWeatherPanel()
	if IsValid( panel ) then panel:Close() panel = nil return end
	panel = build()
	panel:MakePopup()
end

concommand.Add( "ToggleWeatherPanel", HL2A.ToggleWeatherPanel, nil, "Toggles The Alone Mod Weather Panel" )
concommand.Add( "toggleweatherpanel", HL2A.ToggleWeatherPanel )
