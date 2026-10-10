--[[
	What the gamemode costs per frame, from the timings sh_instrument.lua
	keeps for every hook, timer and net message it registers.

	hl2a_perf 1                 on-screen readout (client): the port's total
	                            ms per frame and its costliest hooks, each second
	hl2a_perf_server [seconds]  the server side, measured for a while (default
	                            10 s) and printed to the console
]]

if SERVER then
	concommand.Add( "hl2a_perf_server", function( ply, _, args )
		if IsValid( ply ) and not ply:IsListenServerHost() and not ply:IsSuperAdmin() then return end
		local seconds = math.Clamp( tonumber( args[ 1 ] ) or 10, 1, 120 )
		HL2A.Perf.Reset()
		MsgN( string.format( "[HL2A] measuring the server for %d s...", seconds ) )
		timer.Simple( seconds, function()
			local total = 0
			local top = HL2A.Perf.Top()
			for _, t in ipairs( top ) do total = total + t[ 2 ] end
			MsgN( string.format( "[HL2A] server: %.3f ms per second in the gamemode's callbacks", total * 1000 / seconds ) )
			for i = 1, math.min( 15, #top ) do
				local t = top[ i ]
				MsgN( string.format( "  %8.3f ms/s  %6d calls  %s", t[ 2 ] * 1000 / seconds, t[ 3 ], t[ 1 ] ) )
			end
		end )
	end, nil, "Measure the gamemode's server-side cost: [seconds]" )
	return
end

local CV = HL2A.ConVars

surface.CreateFont( "HL2A.Perf", { font = "Courier New", size = 15, weight = 600 } )

local shown, frames, windowStart = {}, 0, RealTime()
local total = 0

hook.Add( "Think", "hl2a.perf", function()
	if not CV.hl2a_perf:GetBool() then return end
	frames = frames + 1
	if RealTime() - windowStart < 1 then return end
	local top = HL2A.Perf.Top()
	total = 0
	for _, t in ipairs( top ) do total = total + t[ 2 ] end
	shown = {}
	for i = 1, math.min( 8, #top ) do
		shown[ i ] = string.format( "%6.3f ms  %s", top[ i ][ 2 ] * 1000 / frames, top[ i ][ 1 ] )
	end
	total = total * 1000 / frames
	shown.fps = frames / ( RealTime() - windowStart )
	HL2A.Perf.Reset()
	frames, windowStart = 0, RealTime()
end )

hook.Add( "HUDPaint", "hl2a.perf", function()
	if not CV.hl2a_perf:GetBool() then return end
	local x, y = 20, ScrH() * 0.3
	draw.SimpleTextOutlined( string.format( "HL2A: %.3f ms/frame   %.0f fps", total, shown.fps or 0 ), "HL2A.Perf", x, y,
		total > 2 and Color( 255, 120, 80 ) or Color( 160, 255, 160 ), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, color_black )
	for i, line in ipairs( shown ) do
		draw.SimpleTextOutlined( line, "HL2A.Perf", x, y + i * 16, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, color_black )
	end
end )
