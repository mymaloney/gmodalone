--[[
	Registers the mod's sound scripts and particle files.

	GMod won't load game_sounds_*.txt from an addon without overriding the
	stock HL2 copies for every gamemode, so the build tool keeps them in
	data_static and we register them with sound.Add() only while this
	gamemode runs.
]]

local KV = HL2A.KV

local LEVELS = {
	SNDLVL_NONE = 0, SNDLVL_IDLE = 60, SNDLVL_STATIC = 66, SNDLVL_NORM = 75,
	SNDLVL_TALKING = 80, SNDLVL_STATEMENT = 85, SNDLVL_GUNFIRE = 140,
}

local PITCHES = { PITCH_NORM = 100, PITCH_LOW = 95, PITCH_HIGH = 120 }

local function range( str, named )
	if not str then return nil end
	local parts = {}
	for p in str:gmatch( "[^,]+" ) do
		p = p:Trim()
		parts[ #parts + 1 ] = named[ p:upper() ] or tonumber( p )
	end
	if #parts == 0 then return nil end
	if #parts == 1 then return parts[ 1 ] end
	return parts
end

local function level( str )
	if not str then return 75 end
	local db = str:match( "SNDLVL_(%d+)dB" )
	return tonumber( db ) or LEVELS[ str:upper() ] or tonumber( str ) or 75
end

local function channel( str )
	if not str then return CHAN_AUTO end
	return tonumber( str ) or _G[ str:upper() ] or CHAN_AUTO
end

local function fixPath( p )
	return ( p:gsub( "\\", "/" ) )
end

local function addSoundScript( name, entry )
	local waves = {}
	for _, w in ipairs( KV.GetAll( entry, "wave" ) ) do waves[ #waves + 1 ] = fixPath( w ) end
	for _, rnd in ipairs( KV.GetAll( entry, "rndwave" ) ) do
		for _, w in ipairs( KV.GetAll( rnd, "wave" ) ) do waves[ #waves + 1 ] = fixPath( w ) end
	end
	if #waves == 0 then return false end

	local volume = range( KV.Get( entry, "volume" ), { VOL_NORM = 1 } ) or 1
	if istable( volume ) then volume = ( volume[ 1 ] + volume[ 2 ] ) / 2 end

	sound.Add( {
		name = name,
		channel = channel( KV.Get( entry, "channel" ) ),
		volume = volume,
		level = level( KV.Get( entry, "soundlevel" ) ),
		pitch = range( KV.Get( entry, "pitch" ), PITCHES ) or 100,
		sound = #waves == 1 and waves[ 1 ] or waves,
	} )
	return true
end

function HL2A.LoadSoundScripts()
	local manifest = KV.ParseFile( "scripts/game_sounds_manifest.txt" )
	local files = {}
	for _, root in ipairs( manifest or {} ) do
		for _, f in ipairs( KV.GetAll( root.value, "precache_file" ) ) do files[ #files + 1 ] = f end
	end

	local count = 0
	for _, f in ipairs( files ) do
		-- Files not shipped by the mod are stock HL2 ones GMod already has
		for _, entry in ipairs( KV.ParseFile( f ) or {} ) do
			if istable( entry.value ) and addSoundScript( entry.key, entry.value ) then
				count = count + 1
			end
		end
	end

	MsgN( "[HL2A] registered " .. count .. " sound scripts" )
end

function HL2A.LoadParticles()
	local manifest = KV.ParseFile( "particles/particles_manifest.txt" )
	for _, root in ipairs( manifest or {} ) do
		for _, f in ipairs( KV.GetAll( root.value, "file" ) ) do
			-- Mod-specific .pcf files are installed under particles/hl2alone/
			-- so they don't replace stock particles in other gamemodes.
			local path = "particles/hl2alone/" .. f:gsub( "\\", "/" ):lower():match( "[^/]+$" )
			if file.Exists( path, "GAME" ) then game.AddParticles( path ) end
		end
	end

	-- Rain splash particle lives in a stock HL2 file GMod doesn't load by default
	if not file.Exists( "particles/hl2alone/water_impact.pcf", "GAME" ) then
		game.AddParticles( "particles/water_impact.pcf" )
	end
	PrecacheParticleSystem( HL2A.ConVars.amod_rain_splash_particle_name:GetString() )
end
