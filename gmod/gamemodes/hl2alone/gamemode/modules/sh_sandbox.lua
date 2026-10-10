--[[
	Sandbox tools switch. The gamemode derives from Sandbox so its tools stay
	available, but in the campaign its hint pop-ups ("Hold C ..."), spawn
	menu (Q), context menu (C) and noclip get in the way. They're off unless
	hl2a_sandbox_tools is 1 (Options panel, Other section).

	The physgun/toolgun loadout is separate: hl2a_sandbox_loadout.
]]

local function enabled()
	if SERVER then return HL2A.ConVars.hl2a_sandbox_tools:GetBool() end
	-- Client copies of server settings can be stale; the server publishes it
	return GetGlobal2Bool( "hl2a.sandbox", false )
end
HL2A.SandboxTools = enabled

hook.Add( "PlayerNoClip", "hl2a.sandbox", function( ply, desired )
	if desired and not enabled() then return false end
end )

if SERVER then
	local function publish() SetGlobal2Bool( "hl2a.sandbox", HL2A.ConVars.hl2a_sandbox_tools:GetBool() ) end
	hook.Add( "InitPostEntity", "hl2a.sandbox", function() publish() end )
	hook.Add( "HL2A_PublishSettings", "hl2a.sandbox", function() publish() end ) -- sv_settings.lua, after a map change
	cvars.AddChangeCallback( "hl2a_sandbox_tools", function() timer.Simple( 0, publish ) end, "hl2a.sandbox" )

	-- Leaving noclip when the tools are switched off
	cvars.AddChangeCallback( "hl2a_sandbox_tools", function( _, _, new )
		if tobool( new ) then return end
		for _, ply in player.Iterator() do
			if ply:GetMoveType() == MOVETYPE_NOCLIP then ply:SetMoveType( MOVETYPE_WALK ) end
		end
	end, "hl2a.sandbox.noclip" )
	return
end

hook.Add( "SpawnMenuOpen", "hl2a.sandbox", function() if not enabled() then return false end end )
hook.Add( "ContextMenuOpen", "hl2a.sandbox", function() if not enabled() then return false end end )

-- Sandbox's hints are queued through its global AddHint (cl_hints.lua),
-- which is already loaded since Sandbox's files run before ours
if isfunction( AddHint ) and not HL2A.OrigAddHint then
	HL2A.OrigAddHint = AddHint
	AddHint = function( ... )
		if enabled() then return HL2A.OrigAddHint( ... ) end
	end
end
