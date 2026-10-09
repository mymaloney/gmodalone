--[[
	Effects panel (ToggleEffectsPanel / toggleeffectspanel, or the button on
	the Options panel). Rebuilt in Derma from the original's pages, with its
	slider ranges and localization; changes apply immediately. The effects
	themselves are in cl_effects.lua.
]]

local CV = HL2A.ConVars
local E = HL2A.Effects

local function phrase( token ) return ( language.GetPhrase( ( token:gsub( "^#", "" ) ) ):gsub( "\\n", "\n" ) ) end
local function P( key ) return phrase( "#Amod_EffectsPanel_" .. key ) end

local panel

-- Shared widgets ----------------------------------------------------------------------------

local function label( parent, text, x, y, w )
	local l = parent:Add( "DLabel" )
	l:SetPos( x, y )
	l:SetSize( w or 200, 20 )
	l:SetText( text )
	l:SetDark( false )
	return l
end

local function check( parent, text, tip, x, y, get, set )
	local cb = parent:Add( "DCheckBoxLabel" )
	cb:SetPos( x, y )
	cb:SetText( text )
	cb:SizeToContents()
	if tip then cb:SetTooltip( tip ) end
	cb:SetValue( get() )
	cb.OnChange = function( _, v ) set( v ) end
	return cb
end

local function slider( parent, text, tip, x, y, w, min, max, get, set )
	label( parent, text, x, y, w )
	local s = parent:Add( "DNumSlider" )
	s:SetPos( x - 4, y + 14 )
	s:SetSize( w, 24 )
	s:SetMinMax( math.min( min, max ), math.max( min, max ) )
	s:SetDecimals( 0 )
	s:SetValue( get() )
	s.Label:SetVisible( false )
	s.PerformLayout = function( self ) self.Label:SetWide( 0 ) end
	if tip then s:SetTooltip( tip ) end
	s.OnValueChanged = function( _, v ) set( math.Round( v ) ) end
	return s
end

local function textEntry( parent, x, y, w, value, tip )
	local t = parent:Add( "DTextEntry" )
	t:SetPos( x, y )
	t:SetSize( w, 20 )
	t:SetValue( value or "" )
	if tip then t:SetTooltip( tip ) end
	return t
end

local function button( parent, text, x, y, w, onClick, tip )
	local b = parent:Add( "DButton" )
	b:SetPos( x, y )
	b:SetSize( w, 22 )
	b:SetText( text )
	if tip then b:SetTooltip( tip ) end
	b.DoClick = onClick
	return b
end

--- 12 condition checkboxes in two columns; returns the panel with GetMask/SetMask
local function typePicker( parent, prefix, x, y, w )
	local p = parent:Add( "DPanel" )
	p:SetPos( x, y )
	p:SetSize( w, 6 * 18 + 22 )
	p:SetPaintBackground( false )
	local l = label( p, P( prefix .. "_ActiveTypes" ), 0, 0, w )
	l:SetTooltip( P( "ConvarPage_Tooltip_ActiveTypes" ) )

	local boxes = {}
	for i, c in ipairs( E.CONDITIONS ) do
		local cb = p:Add( "DCheckBoxLabel" )
		cb:SetPos( ( i - 1 ) % 2 * ( w / 2 ), 20 + math.floor( ( i - 1 ) / 2 ) * 18 )
		cb:SetText( P( prefix .. "_ActiveType_" .. c[ 1 ] ) )
		cb:SizeToContents()
		boxes[ i ] = cb
	end

	function p:GetMask()
		local m = 0
		for i, cb in ipairs( boxes ) do if cb:GetChecked() then m = bit.bor( m, bit.lshift( 1, i - 1 ) ) end end
		return m
	end
	function p:SetMask( m )
		for i, cb in ipairs( boxes ) do cb:SetValue( bit.band( m or 0, bit.lshift( 1, i - 1 ) ) ~= 0 ) end
	end
	p:SetMask( 1 )
	return p
end

local function typeNames( mask )
	local out = {}
	for i, c in ipairs( E.CONDITIONS ) do
		if bit.band( mask, bit.lshift( 1, i - 1 ) ) ~= 0 then out[ #out + 1 ] = c[ 1 ]:gsub( "^When", "" ) end
	end
	return table.concat( out, ", " )
end

local function warn( text ) Derma_Message( text, "Error", "Ok" ) surface.PlaySound( "resource/warning.wav" ) end

local function cvBool( name ) return function() return CV[ name ]:GetBool() end end
local function setBool( name ) return function( v ) RunConsoleCommand( name, v and "1" or "0" ) end end

-- View Effects -------------------------------------------------------------------------------

local function viewPage( sheet )
	local pg = vgui.Create( "DPanel", sheet )
	pg:SetPaintBackground( false )
	local VP = "ViewPage_"
	local function T( k ) return P( VP .. "Tooltip_" .. k ) end

	local checks = {
		{ "DontDrawViewmodel", "hl2a_hide_viewmodel" },
		{ "EnableBlackAndWhiteView", "hl2a_noir" },
		{ "EnableLenseDirtOnScreen", "amod_view_lense_dirt" },
		{ "EnableTvStyledView", "amod_view_bodycam" },
		{ "EnableColoredTvStyledView", "amod_view_binoculars" },
		{ "EnableBlurredView", "amod_view_blur" },
		{ "EnableBlackBoxes", "amod_view_square" },
		{ "OverrideViewmodelFov", "hl2a_viewmodel_fov_override" },
		{ "EnableClaustraphobia", "amod_view_claustrophobia" },
	}
	for i, c in ipairs( checks ) do
		check( pg, P( VP .. c[ 1 ] ), T( c[ 1 ] ), 8, 6 + ( i - 1 ) * 20, cvBool( c[ 2 ] ), setBool( c[ 2 ] ) )
	end

	local y = 196
	local function sl( key, tipKey, min, max, get, set )
		slider( pg, P( VP .. key ), T( tipKey ), 8, y, 290, min, max, get, set )
		y = y + 40
	end
	sl( "BlackBoxWidthText", "BlackBoxWidthSlider", 0, 30,
		function() return CV.amod_view_square_width:GetFloat() * 30 end,
		function( v ) RunConsoleCommand( "amod_view_square_width", tostring( v / 30 ) ) end )
	sl( "BlackBoxHeightText", "BlackBoxHeightSlider", 0, 30,
		function() return CV.amod_view_square_height:GetFloat() * 30 end,
		function( v ) RunConsoleCommand( "amod_view_square_height", tostring( v / 30 ) ) end )
	sl( "ClaustraphobiaAmountText", "ClaustraphobiaAmountSlider", 1, 40,
		function() return CV.amod_view_claustrophobia_amt:GetFloat() * 4 end,
		function( v ) RunConsoleCommand( "amod_view_claustrophobia_amt", tostring( v * 0.25 ) ) end )
	sl( "ClaustraphobiaFovText", "ClaustraphobiaFovSlider", 10, 170,
		function() return CV.hl2a_claustrophobia_fov:GetFloat() end,
		function( v ) RunConsoleCommand( "hl2a_claustrophobia_fov", tostring( v ) ) end )
	sl( "ViewmodelFovOverrideText", "ViewmodelFovOverrideSlider", 5, 179,
		function() return CV.hl2a_viewmodel_fov:GetFloat() end,
		function( v ) RunConsoleCommand( "hl2a_viewmodel_fov", tostring( v ) ) end )
	sl( "BlurAmountText", "BlurAmountSlider", 0, 40,
		function() return CV.amod_blur_amount:GetFloat() / 0.05 end,
		function( v ) RunConsoleCommand( "amod_blur_amount", tostring( v * 0.05 ) ) end )

	-- Camera editor (right column)
	local x = 320
	check( pg, P( VP .. "EnableCameraEditor" ), T( "EnableCameraEditor" ), x, 6, cvBool( "amod_camera_cinematic" ), setBool( "amod_camera_cinematic" ) )
	check( pg, P( VP .. "EnableCameraEditorViewmodelFix" ), T( "EnableCameraEditorViewmodelFix" ), x, 26,
		cvBool( "amod_camera_cinematic_fix" ), setBool( "amod_camera_cinematic_fix" ) )

	-- Smoothing sliders run 50 (off) down to 2 (smoothest), as in the original
	local function smooth( key, tipKey, yy, lag )
		slider( pg, P( VP .. key ), T( tipKey ), x, yy, 290, 2, 50,
			function() return CV[ lag ]:GetBool() and CV[ lag .. "_amt" ]:GetFloat() / 0.002 or 50 end,
			function( v ) E.SetSmooth( lag, v ) end )
	end
	smooth( "SmoothAngleAmountText", "SmoothAngleAmountSlider", 50, "amod_camera_cinematic_lag_angles" )
	smooth( "SmoothOriginAmountText", "SmoothOriginAmountSlider", 90, "amod_camera_cinematic_lag_origin" )

	label( pg, P( VP .. "OriginOverrideText" ), x, 134, 290 )
	local o = textEntry( pg, x, 152, 200, CV.amod_view_override_xyz_amt:GetString(), T( "OriginOverrideTextEntry" ) )
	o.OnChange = function( self ) RunConsoleCommand( "amod_view_override_xyz_amt", self:GetValue() ) end
	label( pg, P( VP .. "AngleOverrideText" ), x, 176, 290 )
	local a = textEntry( pg, x, 194, 200, CV.amod_view_override_pyr_amt:GetString(), T( "AngleOverrideTextEntry" ) )
	a.OnChange = function( self ) RunConsoleCommand( "amod_view_override_pyr_amt", self:GetValue() ) end

	-- 181 = no limit; GMod can't look past 89 degrees either way
	local function pitch( key, tipKey, yy, name )
		slider( pg, P( VP .. key ), T( tipKey ), x, yy, 290, 0, 181,
			function() local v = CV[ name ]:GetFloat() return v >= 89 and 181 or v end,
			function( v ) E.SetPitch( name, v ) end )
	end
	pitch( "MinimumPitchText", "MinimumPitchSlider", 222, "hl2a_pitch_down" )
	pitch( "MaximumPitchText", "MaximumPitchSlider", 262, "hl2a_pitch_up" )

	return pg
end

-- List pages -----------------------------------------------------------------------------

local function listView( parent, x, y, w, h, columns )
	local l = parent:Add( "DListView" )
	l:SetPos( x, y )
	l:SetSize( w, h )
	l:SetMultiSelect( false )
	for _, c in ipairs( columns ) do l:AddColumn( c ) end
	return l
end

local function convarPage( sheet )
	local pg = vgui.Create( "DPanel", sheet )
	pg:SetPaintBackground( false )
	local CP = "ConvarPage_"

	label( pg, P( CP .. "ConvarListText" ), 8, 4 )
	local list = listView( pg, 8, 24, 300, 300, { "Convar", "Value", "Active" } )
	list:SetTooltip( P( CP .. "Tooltip_ConvarList" ) )

	label( pg, P( CP .. "ConvarName" ), 320, 4 )
	local name = textEntry( pg, 320, 24, 280, "", P( CP .. "Tooltip_ConvarNameTextEntry" ) )
	label( pg, P( CP .. "ConvarValue" ), 320, 48 )
	local value = textEntry( pg, 320, 68, 280, "", P( CP .. "Tooltip_ConvarValueTextEntry" ) )
	local types = typePicker( pg, CP, 320, 96, 290 )

	local function refresh()
		list:Clear()
		for i, c in ipairs( E.State.convars ) do list:AddLine( c.name, c.value, typeNames( c.type ) ).index = i end
	end
	refresh()

	list.OnRowSelected = function( _, _, line )
		local c = E.State.convars[ line.index ]
		name:SetValue( c.name ) value:SetValue( c.value ) types:SetMask( c.type )
	end

	local function selected() local _, line = list:GetSelectedLine() return line and line.index end
	local function entry() return { name = name:GetValue():Trim(), value = value:GetValue(), type = types:GetMask() } end

	button( pg, P( CP .. "AddConvar" ), 320, 240, 280, function()
		local c = entry()
		if c.name == "" then return end
		E.State.convars[ #E.State.convars + 1 ] = c
		E.SaveSession() refresh()
	end, P( CP .. "Tooltip_AddButton" ) )
	button( pg, P( CP .. "UpdateConvar" ), 320, 266, 280, function()
		local i = selected()
		if not i then return end
		E.State.convars[ i ] = entry()
		E.SaveSession() refresh()
	end, P( CP .. "Tooltip_UpdateButton" ) )
	button( pg, P( CP .. "RemoveConvar" ), 320, 292, 280, function()
		local i = selected()
		if not i then return end
		table.remove( E.State.convars, i )
		E.SaveSession() refresh()
	end, P( CP .. "Tooltip_RemoveButton" ) )

	pg.Refresh = refresh
	return pg
end

local function overlayChoices()
	local out = {}
	for _, dir in ipairs( { "effects", "effects/view", "overlays" } ) do
		for _, f in ipairs( file.Find( "materials/" .. dir .. "/*.vmt", "GAME" ) ) do
			out[ #out + 1 ] = dir .. "/" .. f:gsub( "%.vmt$", "" )
		end
	end
	table.sort( out )
	return out
end

local function overlayPage( sheet )
	local pg = vgui.Create( "DPanel", sheet )
	pg:SetPaintBackground( false )
	local OP = "OverlayPage_"

	label( pg, P( OP .. "OverlayList" ), 8, 4 )
	local list = listView( pg, 8, 24, 300, 276, { "Overlay", "RGBA", "Active" } )
	list:SetTooltip( P( OP .. "Tooltip_OverlayList" ) )

	local mat = pg:Add( "DComboBox" )
	mat:SetPos( 320, 24 )
	mat:SetSize( 280, 20 )
	mat:SetTooltip( P( OP .. "Tooltip_OverlayTextEntry" ) )
	for _, m in ipairs( overlayChoices() ) do mat:AddChoice( m ) end
	local custom = textEntry( pg, 320, 48, 280, "", P( OP .. "Tooltip_OverlayTextEntry" ) )
	mat.OnSelect = function( _, _, v ) custom:SetValue( v ) end

	local rgba = { 255, 255, 255, 255 }
	local sliders = {}
	for i, key in ipairs( { "Red", "Green", "Blue", "Alpha" } ) do
		sliders[ i ] = slider( pg, P( OP .. key .. "Text" ), P( OP .. "Tooltip_" .. key .. "Slider" ), 320, 70 + ( i - 1 ) * 36, 290, 0, 255,
			function() return rgba[ i ] end, function( v ) rgba[ i ] = v end )
	end
	local types = typePicker( pg, OP, 320, 216, 290 )

	local function refresh()
		list:Clear()
		for i, o in ipairs( E.State.overlays ) do
			list:AddLine( o.name, string.format( "%d %d %d %d", o.r, o.g, o.b, o.a ), typeNames( o.type ) ).index = i
		end
	end
	refresh()

	list.OnRowSelected = function( _, _, line )
		local o = E.State.overlays[ line.index ]
		custom:SetValue( o.name )
		rgba = { o.r, o.g, o.b, o.a }
		for i, s in ipairs( sliders ) do s:SetValue( rgba[ i ] ) end
		types:SetMask( o.type )
	end

	local function selected() local _, line = list:GetSelectedLine() return line and line.index end
	local function entry()
		local name = custom:GetValue():Trim():lower():gsub( "\\", "/" )
		if name == "" then return nil end
		if not E.ScreenMaterial( name ) then
			warn( string.format( 'Error: Material "%s" is an error material!', name ) )
			return nil
		end
		return { name = name, r = rgba[ 1 ], g = rgba[ 2 ], b = rgba[ 3 ], a = rgba[ 4 ], type = types:GetMask() }
	end

	button( pg, P( OP .. "AddButton" ), 8, 306, 145, function()
		local o = entry()
		if not o then return end
		for _, x in ipairs( E.State.overlays ) do
			if x.name == o.name then warn( string.format( 'Error: Overlay "%s" Is already added!', o.name ) ) return end
		end
		E.State.overlays[ #E.State.overlays + 1 ] = o
		E.SaveSession() refresh()
	end, P( OP .. "Tooltip_AddButton" ) )
	button( pg, P( OP .. "ChangeButton" ), 163, 306, 145, function()
		local i, o = selected(), entry()
		if not i or not o then return end
		E.State.overlays[ i ] = o
		E.SaveSession() refresh()
	end, P( OP .. "Tooltip_ChangeButton" ) )
	button( pg, P( OP .. "RemoveButton" ), 8, 332, 145, function()
		local i = selected()
		if not i then return end
		table.remove( E.State.overlays, i )
		E.SaveSession() refresh()
	end, P( OP .. "Tooltip_RemoveButton" ) )

	-- Draw order (the original used shift + up/down)
	local function move( d )
		local i = selected()
		local j = i and i + d
		if not j or j < 1 or j > #E.State.overlays then return end
		local L = E.State.overlays
		L[ i ], L[ j ] = L[ j ], L[ i ]
		E.SaveSession() refresh()
		list:SelectItem( list:GetLine( j ) )
	end
	button( pg, "Move up", 163, 332, 70, function() move( -1 ) end )
	button( pg, "Move down", 238, 332, 70, function() move( 1 ) end )

	pg.Refresh = refresh
	return pg
end

local function lightingPage( sheet )
	local pg = vgui.Create( "DPanel", sheet )
	pg:SetPaintBackground( false )
	local LP = "LightingPage_"

	label( pg, P( LP .. "LightList" ), 8, 4 )
	local list = listView( pg, 8, 24, 220, 300, { "Light", "Active" } )

	local x, w = 240, 175
	label( pg, P( LP .. "LightNameLabel" ), x, 4 )
	local name = textEntry( pg, x, 22, w, "Light 1" )

	label( pg, P( LP .. "LightTypeLabel" ), x, 44 )
	local mode = pg:Add( "DComboBox" )
	mode:SetPos( x, 62 ) mode:SetSize( w, 20 )
	for i, t in ipairs( E.LIGHT_TYPES ) do mode:AddChoice( P( LP .. "LightType_" .. t ), i - 1, i == 1 ) end

	label( pg, P( LP .. "LightingMovementModeLabel" ), x, 84 )
	local move = pg:Add( "DComboBox" )
	move:SetPos( x, 102 ) move:SetSize( w, 20 )
	for i, m in ipairs( E.MOVEMENT_MODES ) do move:AddChoice( P( LP .. "MovementMode_" .. m ), i - 1, i == 2 ) end

	label( pg, P( LP .. "LightingOffsetLabel" ), x, 124 )
	local offset = textEntry( pg, x, 142, w, "0 0 0" )
	label( pg, P( LP .. "LightingAngleOffsetLabel" ), x, 164 )
	local angOffset = textEntry( pg, x, 182, w, "0 0 0" )
	label( pg, P( LP .. "LightingEntityLabel" ), x, 204 )
	local entity = textEntry( pg, x, 222, w, "" )
	label( pg, P( LP .. "LightingEntityAttachmentLabel" ), x, 244 )
	local attachment = textEntry( pg, x, 262, w, "" )
	label( pg, P( LP .. "ColorLabel" ), x, 284 )
	local color = textEntry( pg, x, 302, w, "255 255 255 255" )

	local x2 = 425
	local dist, fov = 750, 45
	local distSlider = slider( pg, P( LP .. "FarLabel" ), nil, x2, 4, 190, 0, 3000, function() return dist end, function( v ) dist = v end )
	local fovSlider = slider( pg, P( LP .. "FovLabel" ), nil, x2, 44, 190, 0, 179, function() return fov end, function( v ) fov = v end )
	local types = typePicker( pg, LP, x2, 88, 190 )

	local placed -- origin/angle for "Static" lights, set by the "to player" button

	local function refresh()
		list:Clear()
		for i, l in ipairs( E.State.lights ) do list:AddLine( l.name, typeNames( l.type ) ).index = i end
	end
	refresh()

	local function selected() local _, line = list:GetSelectedLine() return line and line.index end

	list.OnRowSelected = function( _, _, line )
		local l = E.State.lights[ line.index ]
		name:SetValue( l.name )
		mode:ChooseOptionID( l.mode + 1 )
		move:ChooseOptionID( l.movement + 1 )
		offset:SetValue( string.format( "%g %g %g", l.offset.x, l.offset.y, l.offset.z ) )
		angOffset:SetValue( string.format( "%g %g %g", l.angleOffset.x, l.angleOffset.y, l.angleOffset.z ) )
		entity:SetValue( l.entity ) attachment:SetValue( l.attachment )
		color:SetValue( string.format( "%d %d %d %d", l.color.r, l.color.g, l.color.b, l.color.a ) )
		dist, fov = l.distance, l.fov
		distSlider:SetValue( dist ) fovSlider:SetValue( fov )
		types:SetMask( l.type )
		placed = { l.origin, l.angle }
	end

	local function entry()
		local l = E.NewLight()
		l.name = name:GetValue():Trim()
		local _, m = mode:GetSelected()
		local _, mv = move:GetSelected()
		l.mode, l.movement = m or 0, mv or 1
		l.offset = HL2A.ParseVector( offset:GetValue() ) or l.offset
		l.angleOffset = HL2A.ParseVector( angOffset:GetValue() ) or l.angleOffset
		l.entity, l.attachment = entity:GetValue():Trim(), attachment:GetValue():Trim()
		local r, g, b, a = color:GetValue():match( "(%d+)%s+(%d+)%s+(%d+)%s*(%d*)" )
		l.color = { r = tonumber( r ) or 255, g = tonumber( g ) or 255, b = tonumber( b ) or 255, a = tonumber( a ) or 255 }
		l.distance, l.fov = dist, fov
		l.type = types:GetMask()
		if placed then l.origin, l.angle = placed[ 1 ], placed[ 2 ] end
		return l
	end

	local function nameTaken( n, except )
		for i, l in ipairs( E.State.lights ) do if l.name == n and i ~= except then return true end end
	end

	button( pg, P( LP .. "AddButton" ), 8, 330, 108, function()
		local l = entry()
		if l.name == "" then warn( "Error: Cant have empty light name" ) return end
		if nameTaken( l.name ) then warn( string.format( 'Error: Light with the name "%s" already exists!!', l.name ) ) return end
		E.State.lights[ #E.State.lights + 1 ] = l
		E.SaveSession() refresh()
	end )
	button( pg, P( LP .. "ChangeButton" ), 120, 330, 108, function()
		local i, l = selected(), entry()
		if not i or nameTaken( l.name, i ) then warn( "Error: No light currently selected OR got a light with the same name as the text entry" ) return end
		E.State.lights[ i ] = l
		E.SaveSession() refresh()
	end )
	button( pg, P( LP .. "RemoveButton" ), 8, 356, 220, function()
		local i = selected()
		if not i then warn( "Error: No light currently selected" ) return end
		table.remove( E.State.lights, i )
		E.SaveSession() refresh()
	end )
	button( pg, "Set to player's position", x2, 230, 190, function()
		local ply = LocalPlayer()
		placed = { ply:EyePos(), ply:EyeAngles() }
		local i = selected()
		if i then
			E.State.lights[ i ].origin, E.State.lights[ i ].angle = placed[ 1 ], placed[ 2 ]
			E.SaveSession()
		end
	end, P( LP .. "SetSelectedToPlayerButton" ) )

	pg.Refresh = refresh
	return pg
end

local function autoloadPage( sheet )
	local pg = vgui.Create( "DPanel", sheet )
	pg:SetPaintBackground( false )
	local SP = "SettingsPage_"

	label( pg, P( SP .. "FileList" ), 8, 4 )
	local list = listView( pg, 8, 24, 300, 300, { "Preset / folder" } )
	list:SetTooltip( P( SP .. "Tooltip_FileList" ) )

	label( pg, P( SP .. "FileLabel" ), 320, 4 )
	local choice = pg:Add( "DComboBox" )
	choice:SetPos( 320, 24 )
	choice:SetSize( 280, 20 )
	for _, n in ipairs( E.ListPresets() ) do choice:AddChoice( n ) end

	local function refresh()
		list:Clear()
		for _, n in ipairs( E.AutoloadList() ) do list:AddLine( n ) end
	end
	refresh()

	button( pg, P( SP .. "AddToListButton" ), 320, 50, 280, function()
		local v = choice:GetValue():Trim()
		if v == "" then warn( P( SP .. "Query_EmptyFile" ) ) return end
		local l = E.AutoloadList()
		l[ #l + 1 ] = v
		E.SetAutoloadList( l )
		timer.Simple( 0.1, refresh )
	end )
	button( pg, P( SP .. "RemoveButton" ), 320, 76, 280, function()
		local id = list:GetSelectedLine()
		if not id then warn( P( SP .. "Query_NoSelectedFile" ) ) return end
		local l = E.AutoloadList()
		table.remove( l, id )
		E.SetAutoloadList( l )
		timer.Simple( 0.1, refresh )
	end )

	local note = label( pg, "Presets live in garrysmod/data/hl2alone/effects/. A preset (or a file in a folder) named after a map only loads on that map.", 320, 110, 280 )
	note:SetWrap( true )
	note:SetTall( 60 )

	pg.Refresh = refresh
	return pg
end

-- Frame ---------------------------------------------------------------------------------

local function build()
	local frame = vgui.Create( "DFrame" )
	frame:SetTitle( P( "Title" ) )
	frame:SetSize( 640, 470 )
	frame:Center()
	frame:SetDeleteOnClose( true )

	local sheet = frame:Add( "DPropertySheet" )
	sheet:Dock( FILL )
	local pages = {
		viewPage( sheet ), convarPage( sheet ), overlayPage( sheet ), lightingPage( sheet ), autoloadPage( sheet ),
	}
	sheet:AddSheet( P( "PageTitle_ViewEffects" ), pages[ 1 ] )
	sheet:AddSheet( P( "PageTitle_Convars" ), pages[ 2 ] )
	sheet:AddSheet( P( "PageTitle_Overlays" ), pages[ 3 ] )
	sheet:AddSheet( P( "PageTitle_Lighting" ), pages[ 4 ] )
	sheet:AddSheet( P( "PageTitle_Autoload" ), pages[ 5 ] )

	local bar = frame:Add( "DPanel" )
	bar:Dock( BOTTOM )
	bar:SetTall( 30 )
	bar:DockPadding( 0, 6, 0, 0 )
	bar:SetPaintBackground( false )

	local function barButton( text, onClick )
		local b = bar:Add( "DButton" )
		b:Dock( LEFT )
		b:DockMargin( 0, 0, 6, 0 )
		b:SetWide( 80 )
		b:SetText( text )
		b.DoClick = onClick
	end

	-- Reopen so every page shows the new values
	local function rebuild()
		if not IsValid( frame ) then return end
		frame:Close()
		panel = nil
		timer.Simple( 0.05, HL2A.ToggleEffectsPanel )
	end

	barButton( P( "Buttons_Reset" ), function()
		Derma_Query( P( "ResetPrompt_Desc" ), P( "ResetPrompt_Title" ), "Yes", function()
			E.Reset()
			timer.Simple( 0.1, rebuild )
		end, "No" )
	end )
	barButton( P( "Buttons_Save" ), function()
		Derma_StringRequest( P( "SavePreset_Title" ), "Preset name (saved to data/hl2alone/effects/):", "", function( text )
			local ok = E.SavePreset( text )
			if not ok then warn( string.format( phrase( "#Amod_EffectsPanel_FailedToSavePreset_Desc" ), text ) ) end
		end )
	end )
	barButton( P( "Buttons_Load" ), function()
		local menu = DermaMenu()
		for _, n in ipairs( E.ListPresets() ) do
			if not n:EndsWith( "/" ) then
				menu:AddOption( n, function()
					if E.LoadPreset( n ) then
						timer.Simple( 0.1, rebuild )
					else
						warn( string.format( phrase( "#Amod_EffectsPanel_FailedToLoadPreset_Desc" ), n ) )
					end
				end )
			end
		end
		menu:Open()
	end )

	local debug = bar:Add( "DCheckBoxLabel" )
	debug:Dock( LEFT )
	debug:DockMargin( 8, 4, 8, 0 )
	debug:SetText( P( "Buttons_LightingDebug" ) )
	debug:SetTooltip( P( "Buttons_LightingDebug_Tooltip" ) )
	debug:SetConVar( "amod_lighting_debug" )
	debug:SizeToContents()

	local auto = bar:Add( "DCheckBoxLabel" )
	auto:Dock( LEFT )
	auto:DockMargin( 8, 4, 0, 0 )
	auto:SetText( P( "Buttons_ShouldAutoload" ) )
	auto:SetTooltip( P( "Buttons_ShouldAutoload_Tooltip" ) )
	auto:SetConVar( "hl2a_effects_autoload" )
	auto:SizeToContents()

	return frame
end

function HL2A.ToggleEffectsPanel()
	if IsValid( panel ) then panel:Close() panel = nil return end
	panel = build()
	panel:MakePopup()
end

concommand.Add( "ToggleEffectsPanel", HL2A.ToggleEffectsPanel, nil, "Toggles The Alone Mod Effects Panel" )
concommand.Add( "toggleeffectspanel", HL2A.ToggleEffectsPanel )
