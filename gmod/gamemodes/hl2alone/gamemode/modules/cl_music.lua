--[[
	Song panel and background music (resource/songs/*.txt).

	Songs file format:
		"Songs"
		{
			"[random]" { "name" "<group>"  "song" "music/a.wav"  "song" ... }
			"<Display name>" "music/x.wav"       -- single song (loops)
			"<Display name>" "<group name>"      -- random song from a group
		}

	With amod_songs_transition_through_levels the current song and position
	survive map changes (stored in a cookie).
]]

local CV = HL2A.ConVars
local KV = HL2A.KV

HL2A.Music = HL2A.Music or {}
local M = HL2A.Music

M.Entries = {}   -- ordered { name = display name, value = path or group }
M.Groups = {}    -- group name -> { paths }

local channel, playing -- playing = entry table

function M.Load()
	M.Entries, M.Groups = {}, {}
	for _, rel in ipairs( HL2A.FindFiles( "resource/songs/*.txt" ) ) do
		for _, root in ipairs( KV.ParseFile( rel ) or {} ) do
			for _, kv in ipairs( istable( root.value ) and root.value or {} ) do
				if istable( kv.value ) then
					local name = KV.Get( kv.value, "name" )
					if name then M.Groups[ name ] = KV.GetAll( kv.value, "song" ) end
				else
					M.Entries[ #M.Entries + 1 ] = { name = kv.key, value = kv.value }
				end
			end
		end
	end
end

local function volume()
	local snd = GetConVar( "snd_musicvolume" )
	return CV.hl2a_music_volume:GetFloat() * ( snd and snd:GetFloat() or 1 )
end

function M.Stop()
	if IsValid( channel ) then channel:Stop() end
	channel, playing = nil, nil
	cookie.Delete( "hl2a.song" )
	cookie.Delete( "hl2a.song_time" )
end

function M.Play( entry, startTime )
	if IsValid( channel ) then channel:Stop() end
	channel, playing = nil, entry
	if CV.amod_music_disable:GetBool() then return end

	local group = M.Groups[ entry.value ]
	local path = group and group[ math.random( #group ) ] or entry.value
	if not path then return end

	sound.PlayFile( "sound/" .. path:gsub( "\\", "/" ), "noplay", function( ch, errId, errName )
		if not IsValid( ch ) then
			MsgN( "[HL2A] couldn't play " .. path .. ": " .. tostring( errName ) )
			return
		end
		if playing ~= entry then ch:Stop() return end -- superseded while loading

		channel = ch
		ch:EnableLooping( not group )
		ch:SetVolume( volume() )
		if startTime then ch:SetTime( startTime ) end
		ch:Play()
	end )
end

function M.PlayByName( name )
	for _, e in ipairs( M.Entries ) do
		if e.name:lower() == name:lower() then M.Play( e ) return true end
	end
	return false
end

-- Random groups move on to another song when one ends
hook.Add( "Think", "hl2a.music", function()
	if not playing or not IsValid( channel ) then return end
	channel:SetVolume( volume() )
	if channel:GetState() == GMOD_CHANNEL_STOPPED and M.Groups[ playing.value ] then
		M.Play( playing )
	end
end )

hook.Add( "ShutDown", "hl2a.music", function()
	if playing and IsValid( channel ) and CV.amod_songs_transition_through_levels:GetBool() then
		cookie.Set( "hl2a.song", playing.name )
		cookie.Set( "hl2a.song_time", tostring( channel:GetTime() ) )
	end
end )

hook.Add( "InitPostEntity", "hl2a.music", function()
	M.Load()
	local name = cookie.GetString( "hl2a.song" )
	if not name or not CV.amod_songs_transition_through_levels:GetBool() then return end

	for _, e in ipairs( M.Entries ) do
		if e.name == name then
			-- Random groups pick a fresh song, so the old position doesn't apply
			M.Play( e, not M.Groups[ e.value ] and cookie.GetNumber( "hl2a.song_time" ) or nil )
			break
		end
	end
end )

cvars.AddChangeCallback( "amod_music_disable", function( _, _, new )
	if tobool( new ) and IsValid( channel ) then channel:Stop() end
end, "hl2a.music" )

-- Panel -------------------------------------------------------------------------

local panel

local function buildPanel()
	local frame = vgui.Create( "DFrame" )
	frame:SetTitle( "Songs" )
	frame:SetSize( 360, 460 )
	frame:Center()
	frame:SetDeleteOnClose( false )

	local list = frame:Add( "DListView" )
	list:Dock( FILL )
	list:SetMultiSelect( false )
	list:AddColumn( "Song" )
	for _, e in ipairs( M.Entries ) do list:AddLine( e.name ).entry = e end

	local bottom = frame:Add( "DPanel" )
	bottom:Dock( BOTTOM )
	bottom:SetTall( 56 )
	bottom:DockPadding( 0, 4, 0, 0 )
	bottom:SetPaintBackground( false )

	local transition = bottom:Add( "DCheckBoxLabel" )
	transition:Dock( TOP )
	transition:SetText( "Keep playing through level changes" )
	transition:SetConVar( "amod_songs_transition_through_levels" )

	local play = bottom:Add( "DButton" )
	play:Dock( LEFT )
	play:SetWide( 170 )
	play:SetText( "Play" )
	play.DoClick = function()
		local _, line = list:GetSelectedLine()
		if line then M.Play( line.entry ) end
	end
	list.DoDoubleClick = function( _, _, line ) M.Play( line.entry ) end

	local stop = bottom:Add( "DButton" )
	stop:Dock( RIGHT )
	stop:SetWide( 170 )
	stop:SetText( "Stop" )
	stop.DoClick = M.Stop

	return frame
end

concommand.Add( "ToggleSongPanel", function()
	if #M.Entries == 0 then M.Load() end
	if IsValid( panel ) and panel:IsVisible() then panel:Close() return end
	if not IsValid( panel ) then panel = buildPanel() end
	panel:SetVisible( true )
	panel:MakePopup()
end, nil, "Toggles The Alone Mod Song Panel" )

concommand.Add( "hl2a_play_song", function( _, _, _, argStr )
	if #M.Entries == 0 then M.Load() end
	if not M.PlayByName( argStr:Trim() ) then MsgN( "[HL2A] no song named '" .. argStr .. "'" ) end
end, nil, "Play a song by its display name from resource/songs" )
