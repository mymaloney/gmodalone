--[[
	Level transitions in multiplayer.

	The engine ignores trigger_changelevel whenever maxplayers > 1, so in
	multiplayer the campaign would stop at the first exit. Here the port runs
	the transitions itself:

	- A living player who walks into an enabled level-change trigger (or a
	  map that fires one with the ChangeLevel input) starts a gather: every
	  living player has to be within hl2a_mp_gather_radius of the exit.
	  Until they are, everyone sees "You must gather your party before
	  moving forward (2/4)" and the stragglers get a marker to the exit.
	- Once the whole party is there, a hl2a_mp_transition_delay countdown
	  runs (cancelled if anyone wanders off), then the level changes.
	- As in single player, each player's health, armour, suit, weapons and
	  ammo carry over, and they arrive where they stood relative to the
	  trigger's info_landmark. Players without a saved place (dead at the
	  time, or joined late) arrive next to whoever started the transition.

	Scripted transitions (the ChangeLevel input) wait for the party as well;
	hl2a_mp_gather_timeout lets them go ahead without stragglers after a
	while, and hl2a_mp_force_transition (host / server console) skips the
	wait. Nothing here runs in single player.
]]

local CV = HL2A.ConVars

local CARRY_FILE = "hl2alone/mp_carry.json"
local POLL = 0.1
local SF_NO_TOUCH = 2 -- trigger_changelevel spawnflag: only the ChangeLevel input fires it

local function active()
	return not game.SinglePlayer() and CV.hl2a_mp_transitions:GetBool()
end

-- Trigger keyvalues -------------------------------------------------------------------

local info = {} -- [ trigger ] = { map, landmark }

hook.Add( "EntityKeyValue", "hl2a.transitions", function( ent, key, value )
	if ent:GetClass() ~= "trigger_changelevel" then return end
	local t = info[ ent ] or {}
	info[ ent ] = t
	key = key:lower()
	if key == "map" then t.map = value:lower()
	elseif key == "landmark" then t.landmark = value end
end )

local function triggerInfo( ent )
	local t = info[ ent ] or {}
	local map = t.map or ent:GetInternalVariable( "m_szMapName" )
	local landmark = t.landmark or ent:GetInternalVariable( "m_szLandmarkName" )
	if not isstring( map ) or map == "" then return nil end
	return map:lower(), isstring( landmark ) and landmark or ""
end

local function isEnabled( ent )
	local disabled = ent:GetInternalVariable( "m_bDisabled" )
	return disabled ~= true and disabled ~= 1
end

-- Carry keys are prefixed: GMod's JSON reader turns numeric keys into (lossy) numbers
local function carryKey( ply )
	return "p" .. ( ply:IsBot() and ply:Nick() or ply:SteamID64() or ply:SteamID() )
end

local function landmarkPos( name )
	if not name or name == "" then return nil end
	for _, ent in ipairs( ents.FindByName( name ) ) do
		if ent:GetClass() == "info_landmark" then return ent:GetPos() end
	end
end

-- Carrying players over ----------------------------------------------------------------

local function snapshot( ply, landmark )
	local s = {
		health = ply:Health(), maxHealth = ply:GetMaxHealth(), armor = ply:Armor(),
		suit = ply:IsSuitEquipped(), weapons = {}, ammo = {},
	}
	for _, wep in ipairs( ply:GetWeapons() ) do
		s.weapons[ #s.weapons + 1 ] = { wep:GetClass(), wep:Clip1(), wep:Clip2() }
	end
	local activeWep = ply:GetActiveWeapon()
	if IsValid( activeWep ) then s.active = activeWep:GetClass() end
	for id, count in pairs( ply:GetAmmo() ) do
		local name = game.GetAmmoName( id )
		if name then s.ammo[ name ] = count end
	end
	if landmark then
		s.offset = ply:GetPos() - landmark
		s.angles = ply:EyeAngles()
		s.crouched = ply:Crouching()
	end
	return s
end

--- Saves every player's state for the next map. leader = the player who led the way.
function HL2A.SaveTransitionCarry( map, landmarkName, leader )
	local landmark = landmarkPos( landmarkName )
	local out = { saved = os.time(), map = map, landmark = landmarkName, players = {} }
	for _, ply in player.Iterator() do
		if ply:Alive() then
			out.players[ carryKey( ply ) ] = snapshot( ply, landmark )
		end
	end
	if IsValid( leader ) and landmark then
		out.leaderOffset = leader:GetPos() - landmark
		out.leaderAngles = leader:EyeAngles()
	end
	file.CreateDir( "hl2alone" )
	file.Write( CARRY_FILE, util.TableToJSON( out ) )
end

local carry -- loaded on the next map

local function loadCarry()
	if carry ~= nil then return carry end
	carry = false
	local data = util.JSONToTable( file.Read( CARRY_FILE, "DATA" ) or "" )
	file.Delete( CARRY_FILE )
	-- Only a transition (moments ago, to this map) carries anything over
	if data and os.time() - ( data.saved or 0 ) < 300 and data.map == HL2A.MapPath():lower() then
		carry = data
	end
	return carry
end

hook.Add( "InitPostEntity", "hl2a.transitions", loadCarry )

-- A new game from the chapter menu never carries anything
hook.Add( "HL2A.NewGame", "hl2a.transitions", function()
	file.Delete( CARRY_FILE )
	carry = false
end )

local function toVector( v )
	if isvector( v ) then return v end
	if isstring( v ) then return Vector( v:gsub( "[%[%]]", "" ) ) end
	if istable( v ) then return Vector( v.x or v[ 1 ] or 0, v.y or v[ 2 ] or 0, v.z or v[ 3 ] or 0 ) end
end

local function toAngle( a )
	if isangle( a ) then return a end
	if isstring( a ) then return Angle( a:gsub( "[{}]", "" ) ) end
	if istable( a ) then return Angle( a.p or a[ 1 ] or 0, a.y or a[ 2 ] or 0, a.r or a[ 3 ] or 0 ) end
end

-- Puts the player at pos, or the nearest free spot around it
local RING = { Vector( 0, 0, 0 ) }
for r = 40, 160, 40 do
	for i = 0, 7 do
		local a = math.rad( i * 45 )
		RING[ #RING + 1 ] = Vector( math.cos( a ) * r, math.sin( a ) * r, 0 )
	end
end

local function place( ply, pos, ang )
	local mins, maxs = ply:GetHull()
	for _, off in ipairs( RING ) do
		local p = pos + off + Vector( 0, 0, 2 )
		local tr = util.TraceHull( { start = p, endpos = p, mins = mins, maxs = maxs, mask = MASK_PLAYERSOLID, filter = ply } )
		if not tr.Hit then
			ply:SetPos( p )
			if ang then ply:SetEyeAngles( Angle( ang.p, ang.y, 0 ) ) end
			return true
		end
	end
	return false
end

local function restore( ply, s )
	if s.suit then ply:EquipSuit() else ply:RemoveSuit() end
	if s.maxHealth then ply:SetMaxHealth( s.maxHealth ) end
	if s.health and s.health > 0 then ply:SetHealth( s.health ) end
	ply:SetArmor( s.armor or 0 )
	for _, w in ipairs( s.weapons or {} ) do
		local wep = ply:HasWeapon( w[ 1 ] ) and ply:GetWeapon( w[ 1 ] ) or ply:Give( w[ 1 ], true )
		if IsValid( wep ) then
			if w[ 2 ] and w[ 2 ] >= 0 then wep:SetClip1( w[ 2 ] ) end
			if w[ 3 ] and w[ 3 ] >= 0 then wep:SetClip2( w[ 3 ] ) end
		end
	end
	for name, count in pairs( s.ammo or {} ) do ply:SetAmmo( count, name ) end
	if s.active and ply:HasWeapon( s.active ) then ply:SelectWeapon( s.active ) end
end

--- Called from GM:PlayerSpawn. Returns true if the player was carried over.
function HL2A.RestoreTransitionCarry( ply )
	if game.SinglePlayer() then return false end
	local c = loadCarry()
	if not c or ply.hl2aCarried then return false end
	ply.hl2aCarried = true

	local s = c.players and c.players[ carryKey( ply ) ]
	if s then restore( ply, s ) end

	-- Next tick, once the spawn point has been applied
	local landmark = landmarkPos( c.landmark )
	local offset = toVector( s and s.offset ) or toVector( c.leaderOffset )
	local ang = toAngle( s and s.angles ) or toAngle( c.leaderAngles )
	if landmark and offset then
		timer.Simple( 0, function()
			if IsValid( ply ) and ply:Alive() then place( ply, landmark + offset, ang ) end
		end )
	end
	return s ~= nil
end

-- Gathering at an exit -------------------------------------------------------------------

local gather -- { trigger, map, landmark, leader, started, scripted, countdownEnds }

local function setHud( g, have, need, atExit )
	SetGlobal2Bool( "hl2a.gather", g ~= nil )
	if not g then return end
	SetGlobal2Vector( "hl2a.gather.pos", ( g.mins + g.maxs ) / 2 )
	SetGlobal2Int( "hl2a.gather.have", have )
	SetGlobal2Int( "hl2a.gather.need", need )
	SetGlobal2Float( "hl2a.gather.ends", g.countdownEnds or 0 )
	SetGlobal2Bool( "hl2a.gather.atexit", atExit or g.scripted or false )
end

local function stopGather()
	gather = nil
	setHud( nil )
	for _, ply in player.Iterator() do ply:SetNW2Bool( "hl2a.gather.here", false ) end
end

-- Gap between the player's body and the box (0 when touching). Exits are
-- often small, thin brushes in a doorway, so distances are measured from
-- their edges and from the player's whole body, not its centre.
local function gap( ply, mins, maxs )
	local pmins, pmaxs = ply:WorldSpaceAABB()
	local function axis( a0, a1, b0, b1 ) return math.max( b0 - a1, a0 - b1, 0 ) end
	local dx = axis( pmins.x, pmaxs.x, mins.x, maxs.x )
	local dy = axis( pmins.y, pmaxs.y, mins.y, maxs.y )
	local dz = axis( pmins.z, pmaxs.z, mins.z, maxs.z )
	return math.sqrt( dx * dx + dy * dy + dz * dz )
end

local function reach() return CV.hl2a_mp_exit_reach:GetFloat() end

local function party()
	local out = {}
	for _, ply in player.Iterator() do
		if ply:Alive() and ply:Team() ~= TEAM_SPECTATOR and ply:GetObserverMode() == OBS_MODE_NONE then
			out[ #out + 1 ] = ply
		end
	end
	return out
end

local function goNow( g )
	MsgN( string.format( "[HL2A] multiplayer transition to %s (landmark '%s')", g.map, g.landmark ) )
	HL2A.SaveTransitionCarry( g.map, g.landmark, g.leader )
	stopGather()
	PrintMessage( HUD_PRINTCENTER, "Moving on..." )
	RunConsoleCommand( "changelevel", g.map )
end

local function startGather( trigger, leader, scripted )
	local map, landmark = triggerInfo( trigger )
	if not map then return end
	if not file.Exists( "maps/" .. map .. ".bsp", "GAME" ) then
		if not trigger.hl2aMissingWarned then
			trigger.hl2aMissingWarned = true
			MsgN( "[HL2A] level exit to missing map '" .. map .. "'" )
		end
		return
	end
	local mins, maxs = trigger:WorldSpaceAABB()
	-- Input-only exits are often out of reach (a box in the void behind an
	-- elevator): gather around the player who set the transition off instead
	if scripted and IsValid( leader ) and gap( leader, mins, maxs ) > CV.hl2a_mp_gather_radius:GetFloat() then
		mins, maxs = leader:GetPos(), leader:GetPos()
	end
	gather = { trigger = trigger, mins = mins, maxs = maxs, map = map, landmark = landmark, leader = leader, started = CurTime(), scripted = scripted }
	MsgN( string.format( "[HL2A] %s reached the exit to %s; gathering the party", IsValid( leader ) and leader:Nick() or "a script", map ) )
end

local function tick()
	if not active() then
		if gather then stopGather() end
		return
	end

	-- Someone walked into an exit?
	if not gather then
		for _, trigger in ipairs( ents.FindByClass( "trigger_changelevel" ) ) do
			if isEnabled( trigger ) and bit.band( trigger:GetSpawnFlags(), SF_NO_TOUCH ) == 0 then
				local mins, maxs = trigger:WorldSpaceAABB()
				for _, ply in ipairs( party() ) do
					if gap( ply, mins, maxs ) <= reach() then startGather( trigger, ply, false ) break end
				end
			end
			if gather then break end
		end
		if not gather then return end
	end

	local g = gather
	if not IsValid( g.trigger ) then return stopGather() end
	local mins, maxs = g.mins, g.maxs
	local radius = CV.hl2a_mp_gather_radius:GetFloat()

	local members = party()
	local have, atExit = 0, false
	for _, ply in ipairs( members ) do
		local d = gap( ply, mins, maxs )
		local here = d <= radius
		if here then have = have + 1 end
		if d <= reach() then atExit = true end
		if ply:GetNW2Bool( "hl2a.gather.here" ) ~= here then ply:SetNW2Bool( "hl2a.gather.here", here ) end
	end

	-- A walk-in gather ends once nobody is near the exit any more (or it's switched off)
	if not g.scripted and ( have == 0 or not isEnabled( g.trigger ) ) then return stopGather() end
	if not IsValid( g.leader ) or not g.leader:Alive() then
		for _, ply in ipairs( members ) do
			if g.scripted or gap( ply, mins, maxs ) <= radius then g.leader = ply break end
		end
	end

	local timeout = CV.hl2a_mp_gather_timeout:GetFloat()
	local timedOut = g.scripted and timeout > 0 and CurTime() - g.started >= timeout

	-- Everyone near, and someone actually at the exit (a scripted exit needs no one there)
	if ( have >= #members and ( atExit or g.scripted ) ) or timedOut or g.force then
		if not g.countdownEnds then
			g.countdownEnds = CurTime() + math.max( CV.hl2a_mp_transition_delay:GetFloat(), 0 )
		end
		if CurTime() >= g.countdownEnds then
			setHud( g, have, #members, atExit )
			return goNow( g )
		end
	else
		g.countdownEnds = nil
	end
	setHud( g, have, #members, atExit )
end

timer.Create( "hl2a.transitions", POLL, 0, tick )

-- Scripted transitions: the map fires ChangeLevel on the trigger (no-touch exits,
-- elevators, train rides). The engine ignores it in multiplayer.
hook.Add( "AcceptInput", "hl2a.transitions", function( ent, input, activator )
	if not active() or ent:GetClass() ~= "trigger_changelevel" or input:lower() ~= "changelevel" then return end
	if gather and gather.trigger == ent then return end
	local leader = IsValid( activator ) and activator:IsPlayer() and activator or nil
	startGather( ent, leader, true )
end )

-- Commands ------------------------------------------------------------------------------

concommand.Add( "hl2a_mp_force_transition", function( ply )
	if IsValid( ply ) and not ply:IsListenServerHost() and not ply:IsSuperAdmin() then return end
	if not gather then MsgN( "[HL2A] no level exit is waiting for the party" ) return end
	gather.force = true
	PrintMessage( HUD_PRINTTALK, "[HL2: Alone] Moving on without the stragglers." )
end, nil, "Multiplayer: change level now, without waiting for everyone to gather" )

concommand.Add( "hl2a_mp_gather_debug", function( ply )
	if IsValid( ply ) and not ply:IsListenServerHost() and not ply:IsSuperAdmin() then return end
	MsgN( string.format( "[HL2A] reach %d, gather radius %d (units from the exit's edge)", reach(), CV.hl2a_mp_gather_radius:GetFloat() ) )
	for _, t in ipairs( ents.FindByClass( "trigger_changelevel" ) ) do
		local mins, maxs = t:WorldSpaceAABB()
		local size = maxs - mins
		MsgN( string.format( "  exit to %s: %d x %d x %d units at %s%s", tostring( triggerInfo( t ) ), size.x, size.y, size.z,
			tostring( ( mins + maxs ) / 2 ), isEnabled( t ) and "" or " [disabled]" ) )
		for _, p in player.Iterator() do
			MsgN( string.format( "    %s: %d units away", p:Nick(), gap( p, mins, maxs ) ) )
		end
	end
	MsgN( gather and ( "  gathering for " .. gather.map ) or "  no gather running" )
end, nil, "Multiplayer: show each level exit's size and every player's distance from it" )

concommand.Add( "hl2a_mp_exits", function( ply )
	if IsValid( ply ) and not ply:IsListenServerHost() and not ply:IsSuperAdmin() then return end
	for _, t in ipairs( ents.FindByClass( "trigger_changelevel" ) ) do
		local map, landmark = triggerInfo( t )
		MsgN( string.format( "  %s -> %s (landmark '%s')%s%s", tostring( t ), tostring( map ), tostring( landmark ),
			isEnabled( t ) and "" or " [disabled]", bit.band( t:GetSpawnFlags(), SF_NO_TOUCH ) ~= 0 and " [input only]" or "" ) )
	end
end, nil, "List this map's level exits" )

-- Joining players learn the rule
hook.Add( "PlayerInitialSpawn", "hl2a.transitions", function( ply )
	if not active() then return end
	timer.Simple( 4, function()
		if IsValid( ply ) then
			ply:PrintMessage( HUD_PRINTTALK, "[HL2: Alone] Co-op: the level changes once the whole party has gathered at the exit." )
		end
	end )
end )
