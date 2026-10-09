--[[
	Server side of video playback (cl_video.lua).

	Episode 2 outro, from server.dll: on ep2_outland_12a_d the input to the
	"f_portal" fade is replaced by the outro video (Amod_OutroVideo, or
	Amod_OutroVideo2 for Ending 2), and when it ends logic_ending_credits is
	triggered. Without the converted video the map's own fade plays, as
	before.
]]

util.AddNetworkString( "hl2a.video" )

local pending -- callback for the video the server is waiting on

--- Plays a video on every client; onDone runs when the host's playback ends
function HL2A.SendVideo( name, onDone )
	pending = onDone
	net.Start( "hl2a.video" )
		net.WriteString( name:lower() )
		net.WriteBool( onDone ~= nil )
	net.Broadcast()
end

net.Receive( "hl2a.video", function( _, ply )
	if not ply:IsListenServerHost() or not pending then return end
	local cb = pending
	pending = nil
	cb()
end )

local function hasVideo( name )
	return file.Exists( "html/hl2alone/videos/" .. name .. ".webm", "GAME" )
end

local outroPlayed = false

hook.Add( "AcceptInput", "hl2a.outro", function( ent, input )
	if outroPlayed or HL2A.Map() ~= "ep2_outland_12a_d" or ent:GetName() ~= "f_portal" then return end
	if not hasVideo( "amod_outrovideo" ) and not hasVideo( "amod_outrovideo2" ) then return end
	outroPlayed = true

	MsgN( "[HL2A] f_portal " .. input .. ": playing the outro video" )
	HL2A.SendVideo( hasVideo( "amod_outrovideo" ) and "amod_outrovideo" or "amod_outrovideo2", function()
		for _, e in ipairs( ents.FindByName( "logic_ending_credits" ) ) do e:Fire( "Trigger" ) end
	end )
	return true
end )

hook.Add( "InitPostEntity", "hl2a.outro", function() outroPlayed = false end )
