--[[
	Geo-Guesser (gg_toggle / gg_reset_open, or the chapter select button):
	the mod's mini-game. A screenshot of a spot is shown; mark where it is on
	the map. Rebuilt from client.dll (CGG_*) and resource/geo_guesser/:

	maps/*.res     "Maplist" { "<map>" { "<position>" { "Easy" "x y"
	               "Medium" ... "Hard" ... "HardName" "<map image name>" ...
	               } "Images" { "EasyImages" "<image>" "MediumImages" ...
	               "HardImages" { <name> <image> | "$UseMacro$" <macro> } } } }
	maps/macros.res  "$Macros": "$Name$" strings and lists used above
	images         materials/vgui/geo_guesser/positions/<map>/<position>,
	               maps at materials/vgui/geo_guesser/full_maps/<image>

	Difficulties pick which map image(s) you answer on: Easy a close-up,
	Medium the whole chapter, Hard any Half-Life 2 chapter (pick it from the
	list), Challenging any chapter. Pin positions are in map image pixels.
	Score per round (from the DLL): no pin = 0; within gg_pin_maxpoints_falloff
	(10) pixels = gg_pin_maxpoints (1000); beyond gg_pin_maxdistance (150) = 0;
	linear in between. Picking the wrong map scores 0.

	Settings, enabled maps/positions and high scores are kept in
	data/hl2alone/geoguesser.json (the original's cfg/geo_guesser_config.cfg).
]]

local CV = HL2A.ConVars
local KV = HL2A.KV

HL2A.GeoGuesser = HL2A.GeoGuesser or {}
local G = HL2A.GeoGuesser

local DIFFICULTIES = { "Easy", "Medium", "Hard", "Challenging" }
local SAVE = "hl2alone/geoguesser.json"
local W, H = 750, 500

-- Data ------------------------------------------------------------------------------------

local macros

local function loadMacros()
	macros = {}
	local root = KV.ParseFile( "resource/geo_guesser/maps/macros.res" )
	for _, kv in ipairs( KV.Get( root, "$Macros" ) or {} ) do macros[ kv.key ] = kv.value end
end

local function resolve( s, depth )
	depth = depth or 0
	if isstring( s ) and macros[ s ] ~= nil and depth < 8 then return resolve( macros[ s ], depth + 1 ) end
	return s
end

-- { { name, image } } from a string or a block with $UseMacro$ entries
local function expandImages( v, out, depth )
	out, depth = out or {}, depth or 0
	v = resolve( v )
	if isstring( v ) then
		out[ #out + 1 ] = { name = v, image = v }
	elseif istable( v ) and depth < 8 then
		for _, kv in ipairs( v ) do
			if kv.key == "$UseMacro$" then
				expandImages( macros[ kv.value ], out, depth + 1 )
			else
				out[ #out + 1 ] = { name = resolve( kv.key ), image = resolve( kv.value ) }
			end
		end
	end
	return out
end

local function exists( path )
	return file.Exists( "materials/" .. path .. ".vmt", "GAME" ) or file.Exists( "materials/" .. path .. ".vtf", "GAME" )
end

local matCache = {}
local function material( path )
	if matCache[ path ] then return matCache[ path ] end
	local m
	if file.Exists( "materials/" .. path .. ".vmt", "GAME" ) then
		m = Material( path )
	elseif file.Exists( "materials/" .. path .. ".vtf", "GAME" ) then
		m = CreateMaterial( "hl2a_gg_" .. path:gsub( "[^%w]", "_" ), "UnlitGeneric", { [ "$basetexture" ] = path, [ "$vertexcolor" ] = 1 } )
	end
	matCache[ path ] = m or false
	return m or nil
end

-- The position folder named after the map entry (case and spaces vary)
local function positionsDir( mapName )
	for _, cand in ipairs( { mapName, mapName:lower(), mapName:gsub( " ", "_" ), mapName:lower():gsub( " ", "_" ) } ) do
		if file.IsDir( "materials/vgui/geo_guesser/positions/" .. cand, "GAME" ) then return "vgui/geo_guesser/positions/" .. cand end
	end
	return "vgui/geo_guesser/positions/" .. mapName
end

--- G.Maps = { { name, positions = { { name, image, answers = { Easy = { x, y, map } ... } } }, images = { Easy = { { name, image } } } } }
function G.Load()
	loadMacros()
	G.Maps, G.Problems = {}, {}
	for _, rel in ipairs( HL2A.FindFiles( "resource/geo_guesser/maps/*" ) ) do
		if not rel:find( "macros", 1, true ) then
			for _, root in ipairs( KV.ParseFile( rel ) or {} ) do
				for _, m in ipairs( istable( root.value ) and root.value or {} ) do
					if istable( m.value ) then
						local map = { name = m.key, positions = {}, images = {} }
						local imgs = KV.Get( m.value, "Images" )
						for _, d in ipairs( DIFFICULTIES ) do
							local list = expandImages( KV.Get( imgs, d .. "Images" ) )
							for _, e in ipairs( list ) do e.mat = "vgui/geo_guesser/full_maps/" .. e.image end
							map.images[ d ] = list
						end
						local dir = positionsDir( m.key )
						for _, p in ipairs( m.value ) do
							if istable( p.value ) and p.key ~= "Images" then
								local pos = { name = p.key, image = dir .. "/" .. p.key, answers = {} }
								for _, d in ipairs( DIFFICULTIES ) do
									local x, y = ( KV.Get( p.value, d ) or "" ):match( "(%-?[%d%.]+)%s+(%-?[%d%.]+)" )
									if x then
										local name = resolve( KV.Get( p.value, d .. "Name" ) )
										local list = map.images[ d ]
										pos.answers[ d ] = { x = tonumber( x ), y = tonumber( y ), map = name or ( list[ 1 ] and list[ 1 ].name ) }
									end
								end
								if exists( pos.image ) then
									map.positions[ #map.positions + 1 ] = pos
								else
									G.Problems[ #G.Problems + 1 ] = "missing image " .. pos.image
								end
							end
						end
						if #map.positions > 0 then G.Maps[ #G.Maps + 1 ] = map
						else G.Problems[ #G.Problems + 1 ] = "no usable positions for " .. m.key end
					end
				end
			end
		end
	end
end

-- Settings -------------------------------------------------------------------------------

G.Settings = G.Settings or nil

local function settings()
	if G.Settings then return G.Settings end
	local s = util.JSONToTable( file.Read( SAVE, "DATA" ) or "" ) or {}
	s.difficulty = s.difficulty or "Easy"
	s.rounds = s.rounds or 5
	s.highscores = s.highscores or {}
	s.disabled = s.disabled or {} -- "map" or "map/position" -> true
	G.Settings = s
	return s
end

local function save()
	file.CreateDir( "hl2alone" )
	file.Write( SAVE, util.TableToJSON( settings() ) )
end

local function enabled( map, pos )
	local s = settings()
	return not s.disabled[ map.name ] and not ( pos and s.disabled[ map.name .. "/" .. pos.name ] )
end

-- Scoring (client.dll CGG_MiniMap) ------------------------------------------------------------

function G.Score( dist )
	if not dist then return 0 end
	local maxPoints, falloff, maxDist = CV.gg_pin_maxpoints:GetInt(), CV.gg_pin_maxpoints_falloff:GetInt(), CV.gg_pin_maxdistance:GetInt()
	if dist < falloff then return maxPoints end
	if dist > maxDist then return 0 end
	return math.Clamp( math.floor( ( 1 - ( dist - falloff ) / math.max( maxDist - falloff, 1 ) ) * maxPoints ), 0, maxPoints )
end

-- Minimap widget ------------------------------------------------------------------------------

local function minimap( parent )
	local mm = parent:Add( "DPanel" )
	mm.zoom, mm.ox, mm.oy = 1, 0, 0

	function mm:SetMap( entry )
		self.entry = entry
		self.mat = entry and material( entry.mat )
		self.pin, self.answer = nil, nil
		local w, h = self:GetSize()
		if self.mat then
			local iw, ih = self.mat:Width(), self.mat:Height()
			self.zoom = math.min( w / iw, h / ih )
			self.ox, self.oy = ( w - iw * self.zoom ) / 2, ( h - ih * self.zoom ) / 2
		end
	end

	function mm:ToImage( x, y ) return ( x - self.ox ) / self.zoom, ( y - self.oy ) / self.zoom end
	function mm:ToPanel( x, y ) return x * self.zoom + self.ox, y * self.zoom + self.oy end

	function mm:Paint( w, h )
		surface.SetDrawColor( 0, 0, 0, 150 )
		surface.DrawRect( 0, 0, w, h )
		if not self.mat then
			draw.SimpleText( "Map image missing", "DermaDefault", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
			return
		end
		local x, y = self:LocalToScreen( 0, 0 )
		render.SetScissorRect( x, y, x + w, y + h, true )
		surface.SetDrawColor( 255, 255, 255 )
		surface.SetMaterial( self.mat )
		surface.DrawTexturedRect( self.ox, self.oy, self.mat:Width() * self.zoom, self.mat:Height() * self.zoom )

		local size = CV.gg_minimap_pin_size:GetInt()
		local function pin( p, matPath, col )
			local px, py = self:ToPanel( p.x, p.y )
			local m = material( matPath )
			if m then
				surface.SetDrawColor( 255, 255, 255 )
				surface.SetMaterial( m )
				surface.DrawTexturedRect( px - size / 2, py - size, size, size )
			else
				draw.RoundedBox( size / 4, px - size / 4, py - size / 4, size / 2, size / 2, col )
			end
			return px, py
		end
		if self.answer then
			local ax, ay = pin( self.answer, "vgui/geo_guesser/pin_actuall", Color( 60, 220, 60 ) )
			if self.pin then
				local px, py = self:ToPanel( self.pin.x, self.pin.y )
				surface.SetDrawColor( 255, 220, 0 )
				surface.DrawLine( px, py, ax, ay )
			end
		end
		if self.pin then pin( self.pin, "vgui/geo_guesser/pin", Color( 230, 60, 60 ) ) end
		render.SetScissorRect( 0, 0, 0, 0, false )
	end

	-- Wheel zooms around the cursor, right/middle drag pans, left click places the pin
	function mm:OnMouseWheeled( delta )
		if not self.mat then return end
		local mx, my = self:CursorPos()
		local ix, iy = self:ToImage( mx, my )
		self.zoom = math.Clamp( self.zoom * ( 1 + 0.03 * CV.gg_minimap_scroll_multiplyer:GetFloat() ) ^ delta, 0.05, 20 )
		self.ox, self.oy = mx - ix * self.zoom, my - iy * self.zoom
		return true
	end
	function mm:OnMousePressed( code )
		if code == MOUSE_LEFT then
			if self.locked or not self.mat then return end
			local ix, iy = self:ToImage( self:CursorPos() )
			self.pin = { x = ix, y = iy }
			if self.OnPin then self:OnPin() end
		else
			self.drag = { self:CursorPos() }
			self:MouseCapture( true )
		end
	end
	function mm:OnMouseReleased() self.drag = nil self:MouseCapture( false ) end
	function mm:Think()
		if not self.drag then return end
		local mx, my = self:CursorPos()
		self.ox, self.oy = self.ox + mx - self.drag[ 1 ], self.oy + my - self.drag[ 2 ]
		self.drag = { mx, my }
	end
	return mm
end

-- Pages ----------------------------------------------------------------------------------------

surface.CreateFont( "HL2A.GG.Button", { font = "Verdana", size = 22, weight = 600 } )
surface.CreateFont( "HL2A.GG.Text", { font = "Verdana", size = 19, weight = 500 } )
surface.CreateFont( "HL2A.GG.Title", { font = "Verdana", size = 34, weight = 800 } )

local frame
local showPage

local function bigButton( parent, text, x, y, w, h, onClick )
	local b = parent:Add( "DButton" )
	b:SetPos( x, y ) b:SetSize( w, h )
	b:SetFont( "HL2A.GG.Button" )
	b:SetText( text )
	b.DoClick = onClick
	return b
end

local function text( parent, str, x, y, w, h, font, center )
	local l = parent:Add( "DLabel" )
	l:SetPos( x, y ) l:SetSize( w, h )
	l:SetFont( font or "HL2A.GG.Text" )
	l:SetText( str )
	l:SetTextColor( color_white )
	if center then l:SetContentAlignment( 5 ) end
	return l
end

local function icon( parent, x, y, size )
	local m = material( "vgui/geo_guesser/icon" )
	if not m then return text( parent, "Geo-Guesser", x - 100, y, size + 200, size, "HL2A.GG.Title", true ) end
	local img = parent:Add( "DImage" )
	img:SetPos( x, y ) img:SetSize( size, size )
	img:SetMaterial( m )
	return img
end

local function mainMenu( pg )
	local s = settings()
	icon( pg, W / 2 - 80, 30, 160 )
	bigButton( pg, "Start New Game", W / 2 - 150, 210, 300, 44, function() showPage( "game" ) end )
	bigButton( pg, "Change Settings", W / 2 - 150, 262, 300, 44, function() showPage( "options" ) end )

	text( pg, "Difficulty level:", W / 2 - 150, 320, 140, 26 )
	local box = pg:Add( "DComboBox" )
	box:SetPos( W / 2 - 10, 320 ) box:SetSize( 160, 26 )
	box:SetSortItems( false )
	for _, d in ipairs( DIFFICULTIES ) do box:AddChoice( d, d, d == s.difficulty ) end

	local high = text( pg, "", W / 2 - 150, 370, 300, 26, nil, true )
	local function refresh() high:SetText( "High Score (" .. s.difficulty .. "): " .. ( s.highscores[ s.difficulty ] or 0 ) ) end
	refresh()
	box.OnSelect = function( _, _, d ) s.difficulty = d save() refresh() end

	if #G.Maps == 0 then
		local warn = text( pg, "No Geo-Guesser images found. They live in materials/vgui/geo_guesser/ in the mod's assets.", 40, 420, W - 80, 40, nil, true )
		warn:SetWrap( true )
		warn:SetTextColor( Color( 255, 120, 120 ) )
	end
end

local function optionsPage( pg )
	local s = settings()
	local list = pg:Add( "DCategoryList" )
	list:SetPos( 10, 10 ) list:SetSize( 440, H - 60 )

	local boxes = {} -- { map, pos, cb }
	for _, map in ipairs( G.Maps ) do
		local cat = list:Add( map.name )
		cat:SetExpanded( false )
		local mapBox = cat.Header:Add( "DCheckBox" )
		mapBox:SetPos( 418, 2 )
		mapBox:SetValue( enabled( map ) )
		mapBox.OnChange = function( _, v ) s.disabled[ map.name ] = not v or nil save() end
		boxes[ #boxes + 1 ] = { map = map, cb = mapBox }
		local contents = vgui.Create( "DListLayout" )
		cat:SetContents( contents )
		for _, pos in ipairs( map.positions ) do
			local cb = contents:Add( "DCheckBoxLabel" )
			cb:SetText( pos.name:gsub( "_", " " ) )
			cb:SetValue( not s.disabled[ map.name .. "/" .. pos.name ] )
			cb:DockMargin( 8, 2, 0, 2 )
			cb.OnChange = function( _, v ) s.disabled[ map.name .. "/" .. pos.name ] = not v or nil save() end
			boxes[ #boxes + 1 ] = { map = map, pos = pos, cb = cb }
		end
	end

	local x = 470
	local rounds = text( pg, "", x, 20, 260, 26 )
	local slider = pg:Add( "DNumSlider" )
	slider:SetPos( x - 4, 46 ) slider:SetSize( 270, 24 )
	slider:SetMinMax( 2, 50 ) slider:SetDecimals( 0 )
	slider.Label:SetVisible( false )
	slider.PerformLayout = function( self ) self.Label:SetWide( 0 ) end
	slider:SetValue( s.rounds )
	rounds:SetText( "Number Of Rounds: " .. s.rounds )
	slider.OnValueChanged = function( _, v ) s.rounds = math.Round( v ) rounds:SetText( "Number Of Rounds: " .. s.rounds ) save() end

	local function setAll( v, positionsOnly )
		for _, b in ipairs( boxes ) do
			if b.pos or not positionsOnly then b.cb:SetValue( v ) end
		end
	end
	bigButton( pg, "Select All Positions", x, 100, 260, 36, function() setAll( true, true ) end )
	bigButton( pg, "Deselect All Positions", x, 142, 260, 36, function() setAll( false, true ) end )
	bigButton( pg, "Select All", x, 196, 260, 36, function() setAll( true ) end )
	bigButton( pg, "Deselect All", x, 238, 260, 36, function() setAll( false ) end )
	bigButton( pg, "Back to title", x, H - 90, 260, 40, function() showPage( "menu" ) end )
end

local function buildQueue( difficulty, rounds )
	local pool = {}
	for _, map in ipairs( G.Maps ) do
		if enabled( map ) and #map.images[ difficulty ] > 0 then
			for _, pos in ipairs( map.positions ) do
				if enabled( map, pos ) and pos.answers[ difficulty ] then pool[ #pool + 1 ] = { map = map, pos = pos } end
			end
		end
	end
	local queue = {}
	for i = 1, math.min( rounds, #pool ) do
		queue[ i ] = table.remove( pool, math.random( #pool ) )
	end
	return queue
end

local result -- last game's score, for the finished page

local function gamePage( pg )
	local s = settings()
	local difficulty = s.difficulty
	local queue = buildQueue( difficulty, s.rounds )
	if #queue == 0 then
		Derma_Message( "You must select at least 1 map and position!", "Geo-Guesser", "OK" )
		return showPage( "options" )
	end

	local round, score = 0, 0

	local bg = pg:Add( "DPanel" )
	bg:SetPos( 5, 30 ) bg:SetSize( 365, 465 )
	bg.Paint = function( _, w, h ) surface.SetDrawColor( 0, 0, 0, 150 ) surface.DrawRect( 0, 0, w, h ) end
	local image = pg:Add( "DImage" )
	image:SetPos( 10, 35 ) image:SetSize( 355, 455 )
	image:SetKeepAspect( true )

	local roundLabel = text( pg, "", 70, 0, 200, 30, nil, true )
	local scoreLabel = text( pg, "", 400, 0, 270, 30, nil, true )

	local mapBox = pg:Add( "DComboBox" )
	mapBox:SetPos( 375, 30 ) mapBox:SetSize( 370, 30 )
	mapBox:SetSortItems( false )

	local mm = minimap( pg )
	mm:SetPos( 375, 65 ) mm:SetSize( 370, 325 )

	local info = text( pg, "", 375, 392, 370, 24, nil, true )
	local submit, skip, finish, entry

	local function finishGame()
		result = { score = score, difficulty = difficulty, rounds = #queue }
		if score > ( s.highscores[ difficulty ] or 0 ) then
			s.highscores[ difficulty ] = score
			result.newHigh = true
			save()
		end
		showPage( "finished" )
	end

	local function nextRound()
		round = round + 1
		if round > #queue then return finishGame() end
		entry = queue[ round ]
		roundLabel:SetText( string.format( "Round %d/%d", round, #queue ) )
		scoreLabel:SetText( "Current Score: " .. score )
		image:SetMaterial( material( entry.pos.image ) )
		info:SetText( "Click the map where this picture was taken." )
		submit:SetText( "Submit Answer" )
		submit.answered = false
		mm.locked = false

		local images = entry.map.images[ difficulty ]
		mapBox:Clear()
		mapBox:SetVisible( #images > 1 )
		for i, img in ipairs( images ) do mapBox:AddChoice( img.name, img, i == 1 ) end
		mm:SetMap( images[ 1 ] )
	end

	mapBox.OnSelect = function( _, _, _, img ) if not mm.locked then mm:SetMap( img ) end end

	submit = bigButton( pg, "Submit Answer", 375, 420, 370, 34, function()
		if submit.answered then return nextRound() end
		if not mm.pin then
			Derma_Message( "No position marked on the mini map!", "Geo-Guesser", "OK" )
			return
		end
		local answer = entry.pos.answers[ difficulty ]
		local correctMap = not answer.map or not mm.entry or mm.entry.name == answer.map
		local dist = correctMap and math.sqrt( ( mm.pin.x - answer.x ) ^ 2 + ( mm.pin.y - answer.y ) ^ 2 ) or nil
		local points = G.Score( dist )
		score = score + points
		scoreLabel:SetText( "Current Score: " .. score )

		mm.locked = true
		if correctMap then
			mm.answer = { x = answer.x, y = answer.y }
			info:SetText( string.format( "You Scored %d  (Distance = %dm)", points, math.floor( dist ) ) )
		else
			info:SetText( "Wrong map: it was " .. tostring( answer.map ) .. ". You Scored 0" )
		end
		submit.answered = true
		submit:SetText( round < #queue and "Next Location" or "See Results" )
	end )

	skip = bigButton( pg, "Skip Level", 375, 460, 180, 34, function() nextRound() end )
	finish = bigButton( pg, "Finish Now", 565, 460, 180, 34, function()
		Derma_Query( "Are you sure you would like to leave now?", "Are you sure", "Yes", finishGame, "No" )
	end )

	nextRound()
end

local function finishedPage( pg )
	icon( pg, W / 2 - 80, 30, 160 )
	local r = result or { score = 0, difficulty = settings().difficulty }
	text( pg, "Your Score: " .. r.score, W / 2 - 200, 220, 400, 34, "HL2A.GG.Button", true )
	text( pg, "High Score (" .. r.difficulty .. "): " .. ( settings().highscores[ r.difficulty ] or 0 ) .. ( r.newHigh and "  - new!" or "" ),
		W / 2 - 200, 260, 400, 30, nil, true )
	bigButton( pg, "Back To Menu", W / 2 - 150, 330, 300, 44, function() showPage( "menu" ) end )
end

local PAGES = { menu = mainMenu, options = optionsPage, game = gamePage, finished = finishedPage }

showPage = function( name )
	if not IsValid( frame ) then return end
	if IsValid( frame.page ) then frame.page:Remove() end
	local pg = frame:Add( "DPanel" )
	pg:SetPos( 0, 24 )
	pg:SetSize( W, H )
	pg.Paint = function( _, w, h ) surface.SetDrawColor( 20, 20, 24, 250 ) surface.DrawRect( 0, 0, w, h ) end
	frame.page = pg
	PAGES[ name ]( pg )
end

function G.Open( reset )
	if not G.Maps or reset then G.Load() end
	if IsValid( frame ) then frame:Remove() end
	frame = vgui.Create( "DFrame" )
	frame:SetTitle( "Geo-Guesser" )
	frame:SetSize( W, H + 24 )
	frame:Center()
	frame:MakePopup()
	showPage( "menu" )
end

function G.Toggle()
	if IsValid( frame ) then frame:Remove() return end
	G.Open()
end

concommand.Add( "gg_toggle", G.Toggle, nil, "Toggles the hl2 geo-guesser panel" )
concommand.Add( "gg_reset_open", function() G.Open( true ) end, nil, "Resets and opens the hl2 geo-guesser panel" )
concommand.Add( "gg_debug", function()
	G.Load()
	MsgN( string.format( "[HL2A] Geo-Guesser: %d maps", #G.Maps ) )
	for _, m in ipairs( G.Maps ) do
		local counts = {}
		for _, d in ipairs( DIFFICULTIES ) do counts[ #counts + 1 ] = d .. " " .. #m.images[ d ] .. " map(s)" end
		MsgN( string.format( "  %s: %d positions; %s", m.name, #m.positions, table.concat( counts, ", " ) ) )
		for _, d in ipairs( DIFFICULTIES ) do
			for _, img in ipairs( m.images[ d ] ) do
				if not material( img.mat ) then MsgN( "    missing map image " .. img.mat ) end
			end
		end
	end
	for _, p in ipairs( G.Problems ) do MsgN( "  " .. p ) end
end, nil, "List Geo-Guesser maps, positions and missing images" )
