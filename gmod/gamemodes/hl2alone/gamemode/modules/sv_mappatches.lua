--[[
	Runtime map edits the original server.dll made when certain maps loaded
	(recovered by disassembling bin/server.dll; the maps alone don't contain
	these changes).

	Each patch runs once per map load, after entities spawn.
]]

local function remove( ent ) SafeRemoveEntity( ent ) end

local function create( class, kvs )
	local ent = ents.Create( class )
	for k, v in pairs( kvs ) do ent:SetKeyValue( k, v ) end
	ent:Spawn()
	ent:Activate()
	return ent
end

local function addOutputs( ent, output, list )
	for _, o in ipairs( list ) do ent:SetKeyValue( output, o ) end
end

local function prefix( str, p ) return str:lower():StartWith( p:lower() ) end

HL2A.MapPatches = {}

-- Episode One core: strip NPCs and the advisor/alarm set-pieces, add the
-- "Alone" music and the core-collapse countdown, rewire the lift triggers.
HL2A.MapPatches.ep1_citadel_03_d = function()
	local hasSong, hasTimer = false, false

	local REMOVE_NAMES = {
		pclip_door1 = true, monitor_advisor_1 = true, template_manhacks = true,
		template_combine_upperfirstroom = true, template_combine_exit = true,
		template_combine_1c = true, text_linux = true, command_linux = true,
	}

	for _, ent in ipairs( ents.GetAll() ) do
		local name = ent:GetName()
		local class = ent:GetClass()

		if name == "" then
			-- The only unnamed entity the DLL touched: the trigger at this origin
			if ent:GetPos():DistToSqr( Vector( 1152, 13654, 5312 ) ) < 1 then
				addOutputs( ent, "OnStartTouch", {
					"Teleport_lift_doors,close,,0,-1",
					"Train_lift_coreexit,startforward,,3,-1",
					"!self,kill,,1,-2",
				} )
			end
		elseif name:lower() == "song_" then
			hasSong = true
		elseif name:lower() == "timer_core" then
			hasTimer = true
		elseif prefix( class, "npc_" ) then
			if class ~= "npc_bullseye" then remove( ent ) end
		elseif class == "func_door" then
			if prefix( name, "shutter_door_" ) or prefix( name, "door_comb_1_" ) then remove( ent ) end
		elseif class == "logic_relay" then
			local n = name:lower()
			if n == "relay_alarm1" or n == "logic_door_comb_1_close" then remove( ent ) end
		elseif class == "env_soundscape" then
			remove( ent )
		elseif prefix( name, "song" ) or prefix( name, "sound_advisor" ) or REMOVE_NAMES[ name:lower() ] then
			remove( ent )
		elseif name:lower() == "trigger_entry" then
			addOutputs( ent, "OnStartTouch", {
				"func_areaportal,open,,0,-1",
				"lift_airlock,close,,0,-1",
				"maker_balltrap,forcespawn,,0,-1",
				"Core_lift_doors,open,,8,-1",
				"Trigger_lift,enable,,0,-1",
				"relay_core_enable,trigger,,0,-1",
				"song_,playsound,,0,-1",
				"door_core_exit,setanimation,idle_open,0,-1",
				"relay_laserpower_fail,kill,,0,-1",
				"template_battery_counters,forcespawn,,0,-1",
				"template_battery_counters,kill,,0.5,-1",
				"relay_controlroom3_finished,enable,,2,-1",
			} )
		elseif class == "func_areaportal" then
			ent:SetKeyValue( "targetname", "" )
			ent:Fire( "Open" )
		elseif name:lower() == "trigger_lift" then
			addOutputs( ent, "OnStartTouch", {
				"lift_airlock,open,,2.5,-1",
				"pclip_core_elevator_1,enable,,0,-1",
				"!self,kill,,3,-1",
			} )
		elseif name:lower() == "trigger_socket_6" then
			addOutputs( ent, "OnStartTouch", {
				"relay_controlroom3_finished,enable,,2,-1",
				"relay_controlroom3_finished,trigger,,9,-1",
				"timer_core,StopCoreTimer,,0,-1",
				"timer_core,Disable,,0,-1",
			} )
		end
	end

	-- Original ran "wait 200; playsoundscape inside.citadel_ep1" (~200 frames)
	timer.Simple( 3, function()
		for _, ply in player.Iterator() do ply:ConCommand( "playsoundscape inside.citadel_ep1" ) end
	end )

	if not hasSong then
		create( "ambient_generic", {
			targetname = "song_", message = "music/away.mp3",
			health = "8", spawnflags = "49", radius = "1250",
		} )
	end

	if not hasTimer then
		create( "amod_core_timer", { targetname = "timer_core" } )
		-- The DLL added a logic_auto firing StartCoreTimer 450 on map spawn;
		-- OnMapSpawn has already passed here, so start it directly.
		-- (Its OnLoadGame/OnMapTransition "ShowCoreTimer" outputs named an input
		-- that doesn't exist, so they never did anything.)
		HL2A.StartTimer( "core", 450 )
	end
end

hook.Add( "InitPostEntity", "hl2a.mappatches", function()
	local patch = HL2A.MapPatches[ HL2A.Map() ]
	if patch then
		MsgN( "[HL2A] applying map patch for " .. HL2A.Map() )
		patch()
	end
end )
