--[[
	Achievement toasts and the amod_show_achievements panel.
]]

local A = HL2A.Achievements
A.Done = A.Done or {}

local function title( id ) return language.GetPhrase( id .. "_NAME" ) end
local function desc( id ) return language.GetPhrase( id .. "_DESC" ) end

net.Receive( "hl2a.achievements_sync", function()
	A.Done = net.ReadTable()
end )

-- Toasts ------------------------------------------------------------------------

local toasts = {}
local TOAST_TIME = 5

surface.CreateFont( "HL2A.Toast", { font = "Tahoma", size = 18, weight = 700 } )
surface.CreateFont( "HL2A.ToastSmall", { font = "Tahoma", size = 15 } )

net.Receive( "hl2a.achievement", function()
	local id, n, total = net.ReadString(), net.ReadUInt( 8 ), net.ReadUInt( 8 )
	toasts[ #toasts + 1 ] = {
		title = title( id ),
		text = n >= total and "Achievement unlocked!" or string.format( "Progress: %d / %d", n, total ),
		start = RealTime(),
	}
	surface.PlaySound( n >= total and "garrysmod/save_load4.wav" or "garrysmod/ui_click.wav" )
end )

hook.Add( "HUDPaint", "hl2a.achievements", function()
	local now = RealTime()
	local y = ScrH() - 90
	for i = #toasts, 1, -1 do
		local t = toasts[ i ]
		local age = now - t.start
		if age > TOAST_TIME then
			table.remove( toasts, i )
		else
			local a = math.Clamp( math.min( age, TOAST_TIME - age ) * 4, 0, 1 ) * 255
			local w, x = 280, ScrW() - 300
			draw.RoundedBox( 6, x, y, w, 64, Color( 20, 20, 20, a * 0.85 ) )
			draw.SimpleText( t.title, "HL2A.Toast", x + 12, y + 10, Color( 255, 220, 120, a ) )
			draw.SimpleText( t.text, "HL2A.ToastSmall", x + 12, y + 36, Color( 220, 220, 220, a ) )
			y = y - 72
		end
	end
end )

-- Panel ---------------------------------------------------------------------------

concommand.Add( "amod_show_achievements", function()
	local frame = vgui.Create( "DFrame" )
	frame:SetTitle( "Achievements" )
	frame:SetSize( 460, 300 )
	frame:Center()
	frame:MakePopup()

	local scroll = frame:Add( "DScrollPanel" )
	scroll:Dock( FILL )

	for _, ach in ipairs( A.List ) do
		local n, total = A.Progress( ach, A.Done )
		local row = scroll:Add( "DPanel" )
		row:Dock( TOP )
		row:DockMargin( 0, 0, 0, 6 )
		row:SetTall( 58 )
		row.Paint = function( _, w, h )
			draw.RoundedBox( 4, 0, 0, w, h, Color( 40, 40, 40 ) )
			draw.SimpleText( title( ach.id ), "HL2A.Toast", 10, 6, n >= total and Color( 255, 220, 120 ) or color_white )
			draw.SimpleText( desc( ach.id ), "HL2A.ToastSmall", 10, 30, Color( 200, 200, 200 ) )
			draw.SimpleText( n .. " / " .. total, "HL2A.ToastSmall", w - 10, 8, color_white, TEXT_ALIGN_RIGHT )
		end
	end
end, nil, "Show the Alone mod achievements" )
