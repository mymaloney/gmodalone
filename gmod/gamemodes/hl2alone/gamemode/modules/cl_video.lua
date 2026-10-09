--[[
	Video playback. The mod's videos are Bink (.bik), which GMod can't play;
	tools/build_addon.py --videos converts them to WebM and ships them as
	data_static/hl2alone/videos/<name>.dat (the Workshop allows no video or
	web files). Here the file is read in chunks and handed to GMod's
	built-in browser, which plays it full screen from memory. Space, Enter,
	Escape or a click skips.

	Used for the Episode 2 outro (sv_video.lua; Ending 1 or 2 from the
	Options panel, amod_new_ending, as in the original) and for maps that
	fire "playvideo <name>". amod_playvideo <name> plays one by hand.
]]

local CV = HL2A.ConVars

local START_TIMEOUT = 8      -- seconds to wait for playback to begin once loaded
local CHUNK = 3 * 262144     -- bytes per piece sent to the browser (a multiple of 3 for base64)
local CHUNKS_PER_FRAME = 4

local PAGE = [[
<!doctype html>
<html><head><meta charset="utf-8">
<style>
	html, body { margin: 0; height: 100%; background: #000; overflow: hidden; cursor: none; }
	video { width: 100%; height: 100%; object-fit: contain; }
</style></head>
<body>
<video id="v" playsinline></video>
<script>
	var v = document.getElementById( "v" );
	var parts = [];
	var finished = false;
	function finish( why ) {
		if ( finished ) return;
		finished = true;
		v.pause();
		console.log( "HL2A:" + why );
	}
	function add( b64 ) {
		var bin = atob( b64 ), bytes = new Uint8Array( bin.length );
		for ( var i = 0; i < bin.length; i++ ) bytes[ i ] = bin.charCodeAt( i );
		parts.push( bytes );
	}
	function play( vol ) {
		v.volume = Math.max( 0, Math.min( 1, vol ) );
		v.src = URL.createObjectURL( new Blob( parts, { type: "video/webm" } ) );
		parts = [];
		var p = v.play();
		if ( p && p.catch ) p.catch( function () { finish( "failed" ); } );
	}
	v.addEventListener( "playing", function () { console.log( "HL2A:started" ); } );
	v.addEventListener( "ended", function () { finish( "done" ); } );
	v.addEventListener( "error", function () { finish( "failed" ); } );
	document.addEventListener( "keydown", function ( e ) {
		if ( e.keyCode == 27 || e.keyCode == 32 || e.keyCode == 13 ) finish( "skipped" );
	} );
	document.addEventListener( "mousedown", function () { finish( "skipped" ); } );
	console.log( "HL2A:ready" );
</script>
</body></html>
]]

local panel
local feeding -- the video file being streamed in

--- Whether a converted video is installed (name without extension)
function HL2A.HasVideo( name )
	return HL2A.VideoFile( name ) ~= nil
end

local function close( why, onDone )
	if IsValid( panel ) then panel:Remove() end
	panel = nil
	timer.Remove( "hl2a.video.feed" )
	if feeding then feeding:Close() feeding = nil end
	MsgN( "[HL2A] video " .. why )
	if onDone then onDone( why ) end
end

-- Streams the file into the page a few chunks per frame, then starts it
local function feed( this, path, searchPath, onDone )
	local f = file.Open( path, "rb", searchPath )
	if not f then close( "failed (can't open " .. path .. ")", onDone ) return end
	feeding = f
	local snd = GetConVar( "snd_musicvolume" )
	local vol = ( snd and snd:GetFloat() or 1 ) * CV.hl2a_music_volume:GetFloat()

	timer.Create( "hl2a.video.feed", 0, 0, function()
		if panel ~= this or not IsValid( this ) then timer.Remove( "hl2a.video.feed" ) return end
		for _ = 1, CHUNKS_PER_FRAME do
			local data = f:Read( CHUNK )
			if not data or #data == 0 then
				f:Close()
				feeding = nil
				timer.Remove( "hl2a.video.feed" )
				this:RunJavascript( string.format( "play(%.2f);", vol ) )
				-- The browser can't play it (codec): don't leave the screen black
				timer.Simple( START_TIMEOUT, function()
					if panel == this and IsValid( this ) and not this.hl2aStarted then close( "failed to start", onDone ) end
				end )
				return
			end
			this:RunJavascript( "add('" .. util.Base64Encode( data, true ) .. "');" )
		end
	end )
end

--- Plays a video full screen; onDone( "done" | "skipped" | "failed" | "missing" )
function HL2A.PlayVideo( name, onDone )
	name = name:lower():gsub( "%.%w+$", "" )
	local path, searchPath = HL2A.VideoFile( name )
	if not path then
		MsgN( "[HL2A] no converted video '" .. name .. "' (build with --videos)" )
		if onDone then onDone( "missing" ) end
		return
	end
	if IsValid( panel ) then close( "replaced" ) end

	panel = vgui.Create( "DHTML" )
	panel:SetPos( 0, 0 )
	panel:SetSize( ScrW(), ScrH() )
	panel:MakePopup()
	panel:SetKeyboardInputEnabled( true )
	panel.Paint = function( _, w, h ) surface.SetDrawColor( 0, 0, 0 ) surface.DrawRect( 0, 0, w, h ) end

	local this = panel
	panel.ConsoleMessage = function( self, msg )
		if not isstring( msg ) or not msg:StartWith( "HL2A:" ) then return end
		local what = msg:sub( 6 )
		if what == "ready" then
			if not self.hl2aFed then self.hl2aFed = true feed( this, path, searchPath, onDone ) end
		elseif what == "started" then
			self.hl2aStarted = true
		elseif panel == this then
			close( what, onDone )
		end
	end
	panel:SetHTML( PAGE )

	-- The page never loaded
	timer.Simple( START_TIMEOUT, function()
		if panel == this and IsValid( this ) and not this.hl2aFed then close( "failed (browser didn't load)", onDone ) end
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
