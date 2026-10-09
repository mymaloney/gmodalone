--[[
	Background panel (ToggleBackgroundPanel; original CBackgroundPanel):
	pick one of the mod's menu-background maps, with its preview image, and
	load it. GMod can't use them as its main-menu background, but they load
	as scenes, and the chapter select opens on them as before.

	The maps (maps/backgrounds/) are left out of normal builds to save
	~400 MB; build with --keep-background-maps to include them. Previews:
	materials/vgui/backgrounds/<theme or default>/<map>.
]]

local frame

local function backgrounds()
	local out = {}
	for _, f in ipairs( file.Find( "maps/backgrounds/*.bsp", "GAME" ) ) do out[ #out + 1 ] = f:gsub( "%.bsp$", "" ):lower() end
	table.sort( out )
	return out
end

local function previewOf( map )
	local theme = HL2A.ConVars.hl2a_timeinfo_theme:GetString()
	for _, dir in ipairs( { theme ~= "" and theme or "default", "default", "" } ) do
		local path = "vgui/backgrounds/" .. ( dir ~= "" and ( dir .. "/" ) or "" ) .. map
		if file.Exists( "materials/" .. path .. ".vmt", "GAME" ) or file.Exists( "materials/" .. path .. ".vtf", "GAME" ) then return path end
	end
end

local function open()
	frame = vgui.Create( "DFrame" )
	frame:SetTitle( language.GetPhrase( "AMod_BackgroundPanel_Title" ) )
	frame:SetSize( 250, 229 )
	frame:Center()
	frame:MakePopup()

	local maps = backgrounds()
	local image = frame:Add( "DImage" )
	image:SetPos( 10, 30 ) image:SetSize( 230, 135 )

	local box = frame:Add( "DComboBox" )
	box:SetPos( 10, 174 ) box:SetSize( 230, 23 )
	box:SetSortItems( false )

	local load = frame:Add( "DButton" )
	load:SetPos( 10, 201 ) load:SetSize( 230, 23 )
	load:SetText( language.GetPhrase( "AMod_BackgroundPanel_LoadBackground" ) )

	if #maps == 0 then
		box:SetValue( "No background maps installed" )
		load:SetEnabled( false )
		local note = frame:Add( "DLabel" )
		note:SetPos( 10, 30 ) note:SetSize( 230, 135 )
		note:SetWrap( true )
		note:SetText( "The menu-background maps aren't in this build. Rebuild the addon with --keep-background-maps to include them." )
		return
	end

	local function show( map )
		local p = previewOf( map )
		image:SetVisible( p ~= nil )
		if p then image:SetImage( p ) end
	end
	local cur = HL2A.MapPath():match( "^backgrounds/(.+)" )
	for _, m in ipairs( maps ) do box:AddChoice( m, m, m == cur ) end
	if not cur then box:ChooseOptionID( 1 ) end
	local _, sel = box:GetSelected()
	show( sel or maps[ 1 ] )
	box.OnSelect = function( _, _, _, m ) show( m ) end
	load.DoClick = function()
		local _, m = box:GetSelected()
		if m then RunConsoleCommand( "hl2a_background", m ) frame:Remove() end
	end
end

function HL2A.ToggleBackgroundPanel()
	if IsValid( frame ) then frame:Remove() return end
	open()
end

concommand.Add( "ToggleBackgroundPanel", HL2A.ToggleBackgroundPanel, nil, "Alone Mod background panel" )
