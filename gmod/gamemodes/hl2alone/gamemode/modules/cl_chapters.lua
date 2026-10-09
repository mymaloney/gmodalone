--[[
	Chapter select panel (the mod's "New Game" panel, togglenewgamepanel).

	Opens with F1 (GM:ShowHelp), the togglenewgamepanel command, or
	automatically on the menu background maps. Chapter images are looked up
	the way the original did: materials/vgui/chapters/<theme|default>/<prefix>/chapterN.
]]

local CV = HL2A.ConVars

local BG = Color( 18, 18, 20, 245 )
local TILE = Color( 34, 34, 38 )
local TILE_HOVER = Color( 48, 48, 54 )
local ACCENT = Color( 255, 176, 0 )
local DIM = Color( 150, 150, 150 )

surface.CreateFont( "HL2A.ChapTitle", { font = "Verdana", size = 26, weight = 700 } )
surface.CreateFont( "HL2A.ChapNum", { font = "Verdana", size = 13, weight = 700 } )
surface.CreateFont( "HL2A.ChapName", { font = "Verdana", size = 16, weight = 500 } )

local function phrase( token ) return language.GetPhrase( ( token:gsub( "^#", "" ) ) ) end

local matCache = {}
local function chapterMaterial( theme, dir, n )
	local key = theme .. "|" .. dir .. "|" .. n
	if matCache[ key ] ~= nil then return matCache[ key ] or nil end

	local candidates = {
		"vgui/chapters/" .. ( theme ~= "" and theme or "default" ) .. "/" .. dir .. "/chapter" .. n,
		"vgui/chapters/default/" .. dir .. "/chapter" .. n,
		"vgui/chapters/" .. dir .. "/chapter" .. n,
	}
	if dir == "hl2" then candidates[ #candidates + 1 ] = "vgui/chapters/chapter" .. n end -- stock HL2

	for _, path in ipairs( candidates ) do
		if file.Exists( "materials/" .. path .. ".vmt", "GAME" ) then
			matCache[ key ] = Material( path )
			return matCache[ key ]
		end
	end
	matCache[ key ] = false
	return nil
end

local panel

local function buildPanel()
	local games = HL2A.GetGames()
	local themes = HL2A.GetThemes()
	local state = { game = nil, theme = CV.hl2a_timeinfo_theme:GetString(), selected = nil }

	local frame = vgui.Create( "DFrame" )
	frame:SetSize( math.min( ScrW() - 80, 960 ), math.min( ScrH() - 80, 640 ) )
	frame:Center()
	frame:SetTitle( "" )
	frame:SetDeleteOnClose( false )
	frame:DockPadding( 20, 56, 20, 20 )
	frame.Paint = function( _, w, h )
		draw.RoundedBox( 8, 0, 0, w, h, BG )
		draw.SimpleText( phrase( "#Amod_NewGamePanel_Title" ), "HL2A.ChapTitle", 20, 16, color_white )
	end

	-- Top bar: game + theme --------------------------------------------------------
	local top = frame:Add( "DPanel" )
	top:Dock( TOP )
	top:SetTall( 30 )
	top:DockMargin( 0, 0, 0, 12 )
	top:SetPaintBackground( false )

	local gameBox = top:Add( "DComboBox" )
	gameBox:Dock( LEFT )
	gameBox:SetWide( 260 )

	local themeBox = top:Add( "DComboBox" )
	themeBox:Dock( RIGHT )
	themeBox:SetWide( 260 )
	for _, t in ipairs( themes ) do
		themeBox:AddChoice( t == "" and phrase( "#Amod_NewGamePanel_DefaultThemeText" ) or ( phrase( "#Amod_NewGamePanel_ThemeText" ) .. " " .. t ), t, t == state.theme )
	end

	-- Bottom bar: status + load ----------------------------------------------------------
	local bottom = frame:Add( "DPanel" )
	bottom:Dock( BOTTOM )
	bottom:SetTall( 40 )
	bottom:DockMargin( 0, 12, 0, 0 )
	bottom:SetPaintBackground( false )

	local load = bottom:Add( "DButton" )
	load:Dock( RIGHT )
	load:SetWide( 200 )
	load:SetText( phrase( "#Amod_NewGamePanel_LoadChapter" ) )
	load:SetEnabled( false )

	local options = bottom:Add( "DButton" )
	options:Dock( LEFT )
	options:SetWide( 140 )
	options:DockMargin( 0, 0, 12, 0 )
	options:SetText( phrase( "#AMod_OptionsPanel_Title" ) )
	options.DoClick = function() HL2A.ToggleOptionsPanel() end

	-- The other panels (the original bound them to T, O and X)
	for _, b in ipairs( {
		{ "#Amod_WeatherPanel_Title", function() HL2A.ToggleWeatherPanel() end },
		{ "#Amod_EffectsPanel_Title", function() HL2A.ToggleEffectsPanel() end },
		{ "Songs", function() RunConsoleCommand( "ToggleSongPanel" ) end },
	} ) do
		local btn = bottom:Add( "DButton" )
		btn:Dock( LEFT )
		btn:SetWide( 120 )
		btn:DockMargin( 0, 0, 12, 0 )
		btn:SetText( phrase( b[ 1 ] ) )
		btn.DoClick = b[ 2 ]
	end

	local status = bottom:Add( "DLabel" )
	status:Dock( FILL )
	status:SetTextColor( DIM )
	status:SetText( "" )

	-- Chapter grid -------------------------------------------------------------------------
	local scroll = frame:Add( "DScrollPanel" )
	scroll:Dock( FILL )

	local grid = scroll:Add( "DIconLayout" )
	grid:Dock( FILL )
	grid:SetSpaceX( 12 )
	grid:SetSpaceY( 12 )

	local function loadSelected()
		local ch = state.selected
		if not ch or not ch.installed then return end
		net.Start( "hl2a.loadchapter" )
			net.WriteString( state.game.prefix )
			net.WriteUInt( ch.n, 8 )
			net.WriteString( state.theme )
		net.SendToServer()
		frame:Close()
	end
	load.DoClick = loadSelected

	local function select( ch )
		state.selected = ch
		load:SetEnabled( ch.installed )
		if ch.map == HL2A.RANDOM_MAP then
			status:SetText( "Loads a random map" )
		else
			status:SetText( ch.installed and ch.map or ( ch.map .. " is not installed" ) )
		end
	end

	local function fillGrid()
		grid:Clear()
		state.selected = nil
		load:SetEnabled( false )
		status:SetText( "" )
		if not state.game then return end

		local tileW = 210
		local imgH = math.floor( tileW * 9 / 16 )

		for _, ch in ipairs( HL2A.GetChapters( state.game.prefix ) ) do
			ch.installed = HL2A.IsMapInstalled( ch.map )
			local mat = chapterMaterial( state.theme, state.game.dir, ch.n )
			local name = phrase( ch.title )

			local tile = grid:Add( "DButton" )
			tile:SetSize( tileW, imgH + 50 )
			tile:SetText( "" )
			tile:SetTooltip( ch.map ~= HL2A.RANDOM_MAP and ch.map or nil )
			tile.Paint = function( self, w, h )
				local sel = state.selected == ch
				draw.RoundedBox( 6, 0, 0, w, h, self:IsHovered() and TILE_HOVER or TILE )
				if mat then
					surface.SetDrawColor( 255, 255, 255, ch.installed and 255 or 70 )
					surface.SetMaterial( mat )
					surface.DrawTexturedRect( 0, 0, w, imgH )
				else
					draw.RoundedBox( 0, 0, 0, w, imgH, Color( 10, 10, 12 ) )
				end
				draw.SimpleText( "CHAPTER " .. ch.n, "HL2A.ChapNum", 8, imgH + 6, sel and ACCENT or DIM )
				draw.SimpleText( name, "HL2A.ChapName", 8, imgH + 24, ch.installed and color_white or DIM )
				if sel then
					surface.SetDrawColor( ACCENT )
					surface.DrawOutlinedRect( 0, 0, w, h, 2 )
				end
			end
			tile.DoClick = function() select( ch ) end
			tile.DoDoubleClick = function() select( ch ) loadSelected() end
		end
		grid:Layout()
	end

	gameBox.OnSelect = function( _, _, _, game )
		state.game = game
		fillGrid()
	end
	themeBox.OnSelect = function( _, _, _, theme )
		state.theme = theme
		fillGrid()
	end

	for _, g in ipairs( games ) do
		gameBox:AddChoice( "Game: " .. g.name, g, g.default )
		if g.default then state.game = g end
	end
	state.game = state.game or games[ 1 ]
	fillGrid()

	return frame
end

local function toggle()
	if IsValid( panel ) and panel:IsVisible() then panel:Close() return end
	if IsValid( panel ) then panel:Remove() end -- rebuild so installed maps/themes are current
	panel = buildPanel()
	panel:MakePopup()
end

concommand.Add( "togglenewgamepanel", toggle, nil, "Toggles the alone mod new game panel" )

-- The mod showed its menu over these maps
hook.Add( "InitPostEntity", "hl2a.chapters", function()
	local map = HL2A.Map()
	if map:match( "^background%d+_d$" ) or map == "portal_background" then
		timer.Simple( 1, toggle )
	end
end )
