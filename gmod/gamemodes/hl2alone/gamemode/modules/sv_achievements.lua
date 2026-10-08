--[[
	Server side of achievements: records components fired by the
	logic_achievement entity (entities/entities/logic_achievement.lua) and
	tells the client (cl_achievements.lua).
]]

local A = HL2A.Achievements
local SAVE = "hl2alone/achievements.json"

util.AddNetworkString( "hl2a.achievement" )
util.AddNetworkString( "hl2a.achievements_sync" )

local function load()
	A.Done = util.JSONToTable( file.Read( SAVE, "DATA" ) or "" ) or {}
end

local function save()
	file.CreateDir( "hl2alone" )
	file.Write( SAVE, util.TableToJSON( A.Done, true ) )
end

local function sync( ply )
	net.Start( "hl2a.achievements_sync" )
		net.WriteTable( A.Done )
	if IsValid( ply ) then net.Send( ply ) else net.Broadcast() end
end

function A.Award( component )
	local ach = A.ByComponent[ component ]
	if not ach then
		MsgN( "[HL2A] unknown achievement event " .. component )
		return
	end
	if A.Done[ component ] then return end

	A.Done[ component ] = true
	save()

	local n, total = A.Progress( ach, A.Done )
	net.Start( "hl2a.achievement" )
		net.WriteString( ach.id )
		net.WriteUInt( n, 8 )
		net.WriteUInt( total, 8 )
	net.Broadcast()
	sync()
end

hook.Add( "PlayerInitialSpawn", "hl2a.achievements", function( ply )
	timer.Simple( 1, function() if IsValid( ply ) then sync( ply ) end end )
end )

concommand.Add( "hl2a_achievements_reset", function( ply )
	if IsValid( ply ) and not ply:IsListenServerHost() then return end
	A.Done = {}
	save()
	sync()
	MsgN( "[HL2A] achievements reset" )
end )

load()
