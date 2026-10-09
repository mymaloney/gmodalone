--[[
	Live changes from the Map Properties editor (cl_mapproperties.lua): the
	edited Night block is sent to the server, which applies it and passes it
	on to every client. Both realms then fire "HL2A_TimeInfoChanged" so the
	sky, fog, weather, clouds and bloom pick it up without a map reload.
]]

local KV = HL2A.KV
local TI = HL2A.TimeInfo

local function changed()
	hook.Run( "HL2A_TimeInfoChanged" )
end

if SERVER then
	util.AddNetworkString( "hl2a.mapprops" )

	net.Receive( "hl2a.mapprops", function( _, ply )
		if not ply:IsListenServerHost() then return end
		local map, text = net.ReadString(), net.ReadString()
		local root = KV.Parse( text )
		if not root then return end
		TI.SetNightBlock( map, root )
		changed()

		net.Start( "hl2a.mapprops" )
			net.WriteString( map )
			net.WriteString( text )
		net.Broadcast()
	end )

	util.AddNetworkString( "hl2a.timeinfo_reload" )

	-- Re-reads time_info everywhere (after deleting a map's saved properties)
	concommand.Add( "hl2a_timeinfo_reload", function( ply )
		if IsValid( ply ) and not ply:IsListenServerHost() then return end
		TI.Load()
		changed()
		net.Start( "hl2a.timeinfo_reload" ) net.Broadcast()
	end, nil, "Reload time_info (and saved map properties) and re-apply it" )

	hook.Add( "HL2A_TimeInfoChanged", "hl2a.mapprops", function()
		if HL2A.ApplyAtmosphere then HL2A.ApplyAtmosphere() end
		if HL2A.ApplyWeather then HL2A.ApplyWeather() end
	end )
	return
end

--- Sends an edited Night block for the current map (host only)
function HL2A.PreviewMapProperties( night )
	net.Start( "hl2a.mapprops" )
		net.WriteString( HL2A.Map() )
		net.WriteString( KV.Write( night ) )
	net.SendToServer()
end

net.Receive( "hl2a.mapprops", function()
	local map, text = net.ReadString(), net.ReadString()
	local root = KV.Parse( text )
	if root then
		TI.SetNightBlock( map, root )
		changed()
	end
end )

net.Receive( "hl2a.timeinfo_reload", function()
	TI.Load()
	changed()
end )
