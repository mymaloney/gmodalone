--[[
	Video playback. The mod's videos are Bink (.bik), which GMod can't play;
	tools/build_addon.py --videos converts them to WebM in
	html/hl2alone/videos/, and they play full screen in GMod's built-in
	browser (html/hl2alone/video.html). Space, Enter, Escape or a click
	skips.

	Used for the Episode 2 outro (sv_mappatches.lua; Ending 1 or 2 from the
	Options panel, amod_new_ending, as in the original) and for maps that
	fire "playvideo <name>". amod_playvideo <name> plays one by hand.
]]

local CV = HL2A.ConVars

local PAGE = "asset://garrysmod/html/hl2alone/video.html"
local START_TIMEOUT = 8 -- seconds to wait for playback to begin before giving up

local panel

--- Whether a converted video is installed (name without extension)
function HL2A.HasVideo( name )
	return file.Exists( "html/hl2alone/videos/" .. name:lower() .. ".webm", "GAME" )
end

local function close( why, onDone )
	if IsValid( panel ) then panel:Remove() end
	panel = nil
	MsgN( "[HL2A] video " .. why )
	if onDone then onDone( why ) end
end

--- Plays a video full screen; onDone( "done" | "skipped" | "failed" | "missing" )
function HL2A.PlayVideo( name, onDone )
	name = name:lower():gsub( "%.%w+$", "" )
	if not HL2A.HasVideo( name ) then
		MsgN( "[HL2A] no converted video '" .. name .. "' (build with --videos)" )
		if onDone then onDone( "missing" ) end
		return
	end
	if IsValid( panel ) then panel:Remove() end

	local started = false
	panel = vgui.Create( "DHTML" )
	panel:SetPos( 0, 0 )
	panel:SetSize( ScrW(), ScrH() )
	panel:MakePopup()
	panel:SetKeyboardInputEnabled( true )
	panel.Paint = function( _, w, h ) surface.SetDrawColor( 0, 0, 0 ) surface.DrawRect( 0, 0, w, h ) end

	panel.ConsoleMessage = function( self, msg )
		if not isstring( msg ) or not msg:StartWith( "HL2A:" ) then return end
		local what = msg:sub( 6 )
		if what == "started" then started = true return end
		close( what, onDone )
	end

	local snd = GetConVar( "snd_musicvolume" )
	local vol = ( snd and snd:GetFloat() or 1 ) * CV.hl2a_music_volume:GetFloat()
	panel:OpenURL( PAGE .. "?v=" .. name .. ".webm&vol=" .. string.format( "%.2f", vol ) )

	-- The browser can't play it (codec, missing file): don't leave the screen black
	local this = panel
	timer.Simple( START_TIMEOUT, function()
		if panel == this and IsValid( panel ) and not started then close( "failed to start", onDone ) end
	end )
end

-- Server asks to play (map-fired playvideo, the Episode 2 outro) -----------------------------

net.Receive( "hl2a.video", function()
	local name, report = net.ReadString(), net.ReadBool()

	-- The outro honours the ending choice, as the original did
	if name == "amod_outrovideo" and CV.amod_new_ending:GetBool() and HL2A.HasVideo( "amod_outrovideo2" ) then
		name = "amod_outrovideo2"
	end

	HL2A.PlayVideo( name, function()
		if not report then return end
		net.Start( "hl2a.video" )
		net.SendToServer()
	end )
end )

concommand.Add( "amod_playvideo", function( _, _, args )
	if args[ 1 ] then HL2A.PlayVideo( args[ 1 ] ) end
end, nil, "Play one of the mod's videos (converted with build_addon.py --videos)" )
