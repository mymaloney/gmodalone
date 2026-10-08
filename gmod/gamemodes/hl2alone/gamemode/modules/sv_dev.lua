--[[
	Porting helpers.

	hl2a_entcheck
		Reads garrysmod/data/hl2alone_entity_classes.txt (one classname per
		line, written by tools/audit_assets.py) and reports which classes the
		GMod engine/Lua can't create. Those need a Lua SENT or a map edit.

	hl2a_timeinfo_dump
		Prints what the current map gets from time_info.
]]

concommand.Add( "hl2a_entcheck", function( ply )
	if IsValid( ply ) and not ply:IsListenServerHost() then return end

	local text = file.Read( "hl2alone_entity_classes.txt", "DATA" )
	if not text then
		MsgN( "[HL2A] data/hl2alone_entity_classes.txt not found - run tools/audit_assets.py first" )
		return
	end

	local missing = {}
	for cls in text:gmatch( "[^\r\n]+" ) do
		cls = cls:Trim()
		if cls ~= "" and cls ~= "worldspawn" and not cls:StartWith( "#" ) then
			local ok, ent = pcall( ents.Create, cls )
			if ok and IsValid( ent ) then
				ent:Remove()
			else
				missing[ #missing + 1 ] = cls
			end
		end
	end

	table.sort( missing )
	MsgN( "[HL2A] " .. #missing .. " entity classes not available in GMod:" )
	for _, cls in ipairs( missing ) do MsgN( "    " .. cls ) end
end, nil, "Check which of the mod's map entity classes GMod can't create" )

concommand.Add( "hl2a_timeinfo_dump", function( ply )
	if IsValid( ply ) and not ply:IsListenServerHost() then return end

	local block = HL2A.TimeInfo.GetCurrentBlock()
	MsgN( "[HL2A] time_info for " .. HL2A.Map() )
	if not block then MsgN( "    no time_info entry" ) return end
	PrintTable( HL2A.KV.ToTable( block ), 1 )
end )

-- hl2a_timer <core|citadel> <seconds|stop|show>: drive the Episode One
-- countdowns directly (same as the amod_core_timer entity's inputs)
concommand.Add( "hl2a_timer", function( ply, _, args )
	if IsValid( ply ) and not ply:IsListenServerHost() then return end

	local kind, arg = args[ 1 ], args[ 2 ]
	if ( kind ~= "core" and kind ~= "citadel" ) or not arg then
		MsgN( "usage: hl2a_timer <core|citadel> <seconds|stop|show>" )
		return
	end
	if not GetConVar( "amod_do_" .. kind .. "_timer" ):GetBool() then
		MsgN( "[HL2A] amod_do_" .. kind .. "_timer is 0, so the timer is disabled" )
		return
	end

	if arg == "stop" then HL2A.StopTimer( kind )
	elseif arg == "show" then HL2A.ShowTimer( kind )
	else HL2A.StartTimer( kind, tonumber( arg ) or 0 ) end
end, nil, "Test the Episode One countdowns: hl2a_timer <core|citadel> <seconds|stop|show>" )
