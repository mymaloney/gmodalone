--[[
	Multiplayer level-exit HUD (sv_transitions.lua): the party count while
	someone waits at an exit, the countdown once everyone's there, and a
	marker to the exit for the stragglers.
]]

surface.CreateFont( "HL2A.Gather", { font = "Verdana", size = 24, weight = 700 } )
surface.CreateFont( "HL2A.GatherSmall", { font = "Verdana", size = 17, weight = 600 } )

local YELLOW = Color( 255, 220, 0 )
local OUTLINE = Color( 0, 0, 0, 200 )

local function text( str, font, y, col )
	draw.SimpleTextOutlined( str, font, ScrW() / 2, y, col or YELLOW, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, OUTLINE )
end

-- Marker at the exit, clamped to the screen edge when it's behind or off screen
local function marker( pos, dist )
	local s = pos:ToScreen()
	local w, h, m = ScrW(), ScrH(), 48
	local x, y = s.x, s.y
	if not s.visible then x, y = w - x, h - y end -- behind: mirror
	local off = not s.visible or x < m or y < m or x > w - m or y > h - m
	if off then
		local cx, cy = w / 2, h / 2
		local dx, dy = x - cx, y - cy
		if not s.visible then dy = math.max( dy, 1 ) end
		local k = math.min( ( cx - m ) / math.max( math.abs( dx ), 1 ), ( cy - m ) / math.max( math.abs( dy ), 1 ) )
		x, y = cx + dx * k, cy + dy * k
	end

	local pulse = 0.6 + 0.4 * math.abs( math.sin( RealTime() * 3 ) )
	surface.SetDrawColor( 255, 220, 0, 255 * pulse )
	draw.NoTexture()
	local r = 9
	surface.DrawPoly( { { x = x, y = y - r }, { x = x + r, y = y }, { x = x, y = y + r }, { x = x - r, y = y } } )
	draw.SimpleTextOutlined( string.format( "Exit  %d m", math.Round( dist * 0.01905 ) ), "HL2A.GatherSmall",
		x, y + r + 4, YELLOW, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, OUTLINE )
end

hook.Add( "HUDPaint", "hl2a.transitions", function()
	if not GetGlobal2Bool( "hl2a.gather", false ) or GetGlobal2Bool( "hl2a.capture", false ) then return end
	local ply = LocalPlayer()
	if not IsValid( ply ) then return end

	local have, need = GetGlobal2Int( "hl2a.gather.have", 0 ), GetGlobal2Int( "hl2a.gather.need", 0 )
	local ends = GetGlobal2Float( "hl2a.gather.ends", 0 )
	local y = ScrH() * 0.18

	if ends > 0 then
		text( string.format( "Moving on in %d...", math.max( math.ceil( ends - CurTime() ), 0 ) ), "HL2A.Gather", y )
	elseif ply:GetNW2Bool( "hl2a.gather.here" ) then
		text( string.format( "You must gather your party before moving forward (%d/%d)", have, need ), "HL2A.Gather", y )
	else
		text( "Your party is waiting for you at the exit", "HL2A.Gather", y )
		text( string.format( "%d/%d gathered", have, need ), "HL2A.GatherSmall", y + 26, color_white )
	end

	if ply:Alive() and not ply:GetNW2Bool( "hl2a.gather.here" ) then
		local pos = GetGlobal2Vector( "hl2a.gather.pos", vector_origin )
		marker( pos, ply:GetPos():Distance( pos ) )
	end
end )
