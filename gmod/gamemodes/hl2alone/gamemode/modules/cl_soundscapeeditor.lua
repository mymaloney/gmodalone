--[[
	Soundscape editor (ToggleSoundscapeEditor / soundscape_editor): the core
	of the original's Soundscape Maker. Browse every soundscape in the mod's
	scripts/soundscapes*.txt, edit one as KeyValues text, preview it, and
	save.

	Previews play through the weather-sound layer player (cl_weathersound.lua:
	playlooping, playrandom, playsoundscape), with the map's own soundscape
	silenced meanwhile. GMod loads the engine's soundscapes at startup, so
	saved edits don't change what the maps play until they're copied back into
	the mod's scripts/ folder; Save writes complete soundscape files to
	data/hl2alone/soundscapes/ for that.
]]

local KV = HL2A.KV
local W = HL2A.Weather

local frame
local files      -- { { rel, name, entries = { { key, value } } } }
local preview    -- playing layer

local function load()
	files = {}
	for _, rel in ipairs( HL2A.FindFiles( "scripts/soundscapes*.txt" ) ) do
		if not rel:find( "manifest", 1, true ) then
			local entries = {}
			for _, root in ipairs( KV.ParseFile( rel ) or {} ) do
				if istable( root.value ) then entries[ #entries + 1 ] = root end
			end
			-- Saved edits replace the shipped version of a file
			local name = rel:match( "([^/]+)$" ):gsub( "%.txt%.txt$", ".txt" )
			local saved = file.Read( "hl2alone/soundscapes/" .. name, "DATA" )
			if saved then
				entries = {}
				for _, root in ipairs( KV.Parse( saved ) or {} ) do
					if istable( root.value ) then entries[ #entries + 1 ] = root end
				end
			end
			files[ #files + 1 ] = { rel = rel, name = name, entries = entries }
		end
	end
end

local function stopPreview()
	if preview then preview:Stop() end
	preview = nil
	W.Previewing = false
end

local function playPreview( rules )
	stopPreview()
	RunConsoleCommand( "stopsoundscape" )
	W.Previewing = true -- silences the soundscape cl_weathersound.lua plays
	preview = W.NewLayer( rules, 1 )
end

hook.Add( "Think", "hl2a.ssedit", function()
	if not preview then return end
	if not IsValid( frame ) then stopPreview() return end
	preview:Think( CurTime(), LocalPlayer():EyePos() )
end )

local TEMPLATE = [[
"playlooping"
{
	"volume"	"0.5"
	"pitch"	"100"
	"wave"	"ambient/atmosphere/ambience5.wav"
}
"playrandom"
{
	"time"		"10,20"
	"volume"	"0.3,0.5"
	"pitch"		"95,105"
	"position"	"random"
	"rndwave"
	{
		"wave"	"ambient/materials/creak5.wav"
	}
}
]]

local function open()
	if not files then load() end

	frame = vgui.Create( "DFrame" )
	frame:SetTitle( "Soundscape Editor" )
	frame:SetSize( 820, 560 )
	frame:Center()
	frame:MakePopup()
	frame.OnRemove = stopPreview

	local left = frame:Add( "DPanel" )
	left:Dock( LEFT ) left:SetWide( 280 ) left:DockMargin( 0, 0, 6, 0 )
	left:SetPaintBackground( false )

	local search = left:Add( "DTextEntry" )
	search:Dock( TOP ) search:SetPlaceholderText( "Search soundscapes..." )
	local tree = left:Add( "DTree" )
	tree:Dock( FILL ) tree:DockMargin( 0, 4, 0, 0 )

	local right = frame:Add( "DPanel" )
	right:Dock( FILL ) right:SetPaintBackground( false )
	local title = right:Add( "DLabel" )
	title:Dock( TOP ) title:SetTall( 20 ) title:SetDark( false )
	title:SetText( "Select a soundscape" )
	local editor = right:Add( "DTextEntry" )
	editor:Dock( FILL )
	editor:SetMultiline( true )
	editor:SetFont( "DebugFixed" )
	editor:SetTabbingDisabled( true )

	local bar = right:Add( "DPanel" )
	bar:Dock( BOTTOM ) bar:SetTall( 30 ) bar:DockPadding( 0, 6, 0, 0 )
	bar:SetPaintBackground( false )

	local current -- { file, entry }

	local function fill( filter )
		tree:Clear()
		filter = ( filter or "" ):lower()
		for _, f in ipairs( files ) do
			local node
			for _, e in ipairs( f.entries ) do
				if filter == "" or e.key:lower():find( filter, 1, true ) then
					node = node or tree:AddNode( f.name, "icon16/folder.png" )
					local leaf = node:AddNode( e.key, "icon16/sound.png" )
					leaf.DoClick = function()
						current = { file = f, entry = e }
						title:SetText( e.key .. "   (" .. f.name .. ")" )
						editor:SetValue( KV.Write( e.value ) )
					end
				end
			end
			if node and filter ~= "" then node:SetExpanded( true ) end
		end
	end
	fill()
	search.OnChange = function( self ) fill( self:GetValue() ) end

	-- Text -> rules; reports parse problems instead of applying them
	local function parsed()
		if not current then return nil end
		local rules = KV.Parse( editor:GetValue() )
		if not rules then Derma_Message( "That doesn't parse as KeyValues.", "Soundscape Editor", "OK" ) end
		return rules
	end

	local function apply()
		local rules = parsed()
		if not rules then return false end
		current.entry.value = rules
		W.SetDef( current.entry.key, rules )
		return true
	end

	local function btn( text, tip, fn )
		local b = bar:Add( "DButton" )
		b:Dock( LEFT ) b:DockMargin( 0, 0, 6, 0 ) b:SetText( text ) b:SizeToContentsX( 20 )
		b:SetTooltip( tip ) b.DoClick = fn
	end

	btn( "Play", "Preview this soundscape (the map's own soundscape is silenced meanwhile).", function()
		if apply() then playPreview( current.entry.value ) end
	end )
	btn( "Stop", "Stop the preview.", stopPreview )
	btn( "Save", "Write this soundscape's file to data/hl2alone/soundscapes/.", function()
		if not apply() then return end
		file.CreateDir( "hl2alone/soundscapes" )
		file.Write( "hl2alone/soundscapes/" .. current.file.name, KV.Write( current.file.entries ) )
		notification.AddLegacy( "Saved data/hl2alone/soundscapes/" .. current.file.name, NOTIFY_GENERIC, 4 )
	end )
	btn( "New", "Add a soundscape to the selected file.", function()
		local f = current and current.file or files[ 1 ]
		if not f then return end
		Derma_StringRequest( "New soundscape", "Name (e.g. mymap.outside):", "", function( name )
			name = name:Trim()
			if name == "" then return end
			local e = { key = name, value = KV.Parse( TEMPLATE ) }
			f.entries[ #f.entries + 1 ] = e
			fill( search:GetValue() )
			current = { file = f, entry = e }
			title:SetText( name .. "   (" .. f.name .. ")" )
			editor:SetValue( TEMPLATE )
		end )
	end )
	btn( "Copy", "Copy this soundscape as text.", function()
		if current then SetClipboardText( KV.Write( { { key = current.entry.key, value = parsed() or current.entry.value } } ) ) end
	end )
	btn( "Current", "Select the soundscape you're hearing now.", function()
		local name = LocalPlayer():GetNW2String( "hl2a.soundscape" )
		if name == "" then notification.AddLegacy( "No soundscape playing here", NOTIFY_HINT, 3 ) return end
		search:SetValue( name )
		fill( name )
	end )
end

function HL2A.ToggleSoundscapeEditor()
	if IsValid( frame ) then frame:Remove() return end
	open()
end

concommand.Add( "ToggleSoundscapeEditor", HL2A.ToggleSoundscapeEditor, nil, "Soundscape editor" )
concommand.Add( "soundscape_editor", HL2A.ToggleSoundscapeEditor )
concommand.Add( "soundscape_editor_reload", function() files = nil end, nil, "Re-read the soundscape files" )
