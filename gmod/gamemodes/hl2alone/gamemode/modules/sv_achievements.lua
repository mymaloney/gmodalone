--[[
	Server side of achievements: listens for logic_achievement FireEvent,
	records the component and tells the client (cl_achievements.lua).
]]

local A = HL2A.Achievements
local SAVE = "hl2alone/achievements.json"
local EVENT_PREFIX = "ACHIEVEMENT_EVENT_"

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

-- logic_achievement: remember its event and enabled state
hook.Add( "EntityKeyValue", "hl2a.achievements", function( ent, key, value )
	if ent:GetClass() ~= "logic_achievement" then return end
	key = key:lower()
	if key == "achievementevent" then
		ent.HL2A_Event = value
	elseif key == "startdisabled" then
		ent.HL2A_Disabled = tobool( value )
	end
end )

hook.Add( "AcceptInput", "hl2a.achievements", function( ent, input )
	if ent:GetClass() ~= "logic_achievement" then return end
	input = input:lower()

	if input == "enable" then ent.HL2A_Disabled = false
	elseif input == "disable" then ent.HL2A_Disabled = true
	elseif input == "toggle" then ent.HL2A_Disabled = not ent.HL2A_Disabled
	elseif input == "fireevent" then
		local event = ent.HL2A_Event or ""
		if not ent.HL2A_Disabled and event:StartWith( EVENT_PREFIX ) then
			A.Award( event:sub( #EVENT_PREFIX + 1 ) )
			return true
		end
	end
end )

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
