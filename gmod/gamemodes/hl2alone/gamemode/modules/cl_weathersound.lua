--[[
	Weather ambience, as the original client.dll did it: while it rains (or
	snows) a weather soundscape is layered on top of the soundscape the engine
	is playing. Each soundscape in scripts/soundscapes*.txt may choose it:

		"RainSoundscape"   "<soundscape name>"    or  "RainSoundscapeKV" { <rules> }
		"RainVolume"       "<0-1>"
		(and Snow... / Thunder... the same way)

	Without those keys rain is "common.rain" (outdoors; soundscapes named
	"inside" or "citadel" get none), snow is "common.snowfall" and thunder,
	with amod_weather_thunder on, is "common.thunder". Each thunder clap
	gets a random distance that sets its flash, delay and loudness.

	It plays while the port's weather falls, or on maps with their own
	func_precipitation rain/snow. The current soundscape name comes from
	sv_soundscapes.lua. Supports the
	rules the weather soundscapes use: playlooping, playrandom (wave/rndwave,
	time/volume/pitch ranges, "position" "random") and playsoundscape.
]]

local KV = HL2A.KV

HL2A.Weather = HL2A.Weather or {}
local W = HL2A.Weather

local FADE = 1.5
local RANDOM_DISTANCE = 600

local KINDS = {
	rain = { prefix = "Rain", default = "common.rain" },
	snow = { prefix = "Snow", default = "common.snowfall" },
	thunder = { prefix = "Thunder", default = "common.thunder" },
}

-- Definitions -----------------------------------------------------------------------

local defs -- lowercased soundscape name -> rule list

local function loadDefs()
	defs = {}
	for _, rel in ipairs( HL2A.FindFiles( "scripts/soundscapes*.txt" ) ) do
		if not rel:find( "manifest", 1, true ) then
			for _, root in ipairs( KV.ParseFile( rel ) or {} ) do
				local name = root.key:lower()
				if istable( root.value ) and not defs[ name ] then defs[ name ] = root.value end -- first wins, like the engine
			end
		end
	end
	MsgN( string.format( "[HL2A] weather sounds: %d soundscapes", table.Count( defs ) ) )
end

local function range( str, default )
	if not str then return default, default end
	local a, b = str:match( "^%s*([%d%.%-]+)%s*,%s*([%d%.%-]+)" )
	if a then return tonumber( a ), tonumber( b ) end
	local v = tonumber( str ) or default
	return v, v
end

local function rand( str, default )
	local a, b = range( str, default )
	return a == b and a or math.Rand( a, b )
end

local SNDLVL = { SNDLVL_NONE = 0, SNDLVL_NORM = 75, SNDLVL_STATIC = 66, SNDLVL_TALKING = 80, SNDLVL_GUNFIRE = 140 }

local function soundLevel( str, default )
	if not str then return default end
	str = str:upper()
	return SNDLVL[ str ] or tonumber( str:match( "(%d+)DB" ) or "" ) or default
end

local function wavePath( w )
	return w and HL2A.ResolveSound( ( w:gsub( "\\", "/" ) ) )
end

-- Which weather soundscape (rules, volume) the current soundscape asks for
function W.LayerFor( kind, scapeName )
	if not defs then loadDefs() end
	local info = KINDS[ kind ]
	local scape = defs[ ( scapeName or "" ):lower() ]
	local volume = 1
	local rules

	if scape then
		volume = tonumber( KV.Get( scape, info.prefix .. "Volume" ) ) or 1
		local inline = KV.Get( scape, info.prefix .. "SoundscapeKV" )
		local named = KV.Get( scape, info.prefix .. "Soundscape" )
		if istable( inline ) then rules = inline
		elseif isstring( named ) then rules = defs[ named:lower() ] end
	end

	if not rules then
		local lower = ( scapeName or "" ):lower()
		if kind == "rain" and ( lower:find( "inside", 1, true ) or lower:find( "citadel", 1, true ) ) then return nil end
		rules = defs[ info.default ]
	end
	return rules, volume
end

-- Playing ---------------------------------------------------------------------------

local Layer = {}
Layer.__index = Layer

local function newLayer( rules, volume, onRandom, depth )
	local self = setmetatable( { loops = {}, randoms = {}, children = {}, onRandom = onRandom }, Layer )
	depth = depth or 0
	local ply = LocalPlayer()

	for _, rule in ipairs( rules ) do
		local kind, body = rule.key:lower(), rule.value
		if istable( body ) then
			if kind == "playlooping" then
				local path = wavePath( KV.Get( body, "wave" ) )
				if path and file.Exists( "sound/" .. path, "GAME" ) then
					local snd = CreateSound( ply, path )
					snd:SetSoundLevel( 0 )
					local vol = rand( KV.Get( body, "volume" ), 1 ) * volume
					-- A volume change in the same frame the sound starts is dropped,
					-- so start quiet and fade in a moment later
					snd:PlayEx( 0.01, rand( KV.Get( body, "pitch" ), 100 ) )
					timer.Simple( 0.1, function() if snd:IsPlaying() then snd:ChangeVolume( vol, FADE ) end end )
					self.loops[ #self.loops + 1 ] = snd
				end
			elseif kind == "playrandom" then
				local waves = KV.GetAll( body, "wave" )
				local rnd = KV.Get( body, "rndwave" )
				if istable( rnd ) then table.Add( waves, KV.GetAll( rnd, "wave" ) ) end
				if #waves > 0 then
					local r = { body = body, waves = waves, volume = volume }
					r.next = CurTime() + rand( KV.Get( body, "time" ), 10 )
					self.randoms[ #self.randoms + 1 ] = r
				end
			elseif kind == "playsoundscape" and depth < 8 then
				local sub = defs[ ( KV.Get( body, "name" ) or "" ):lower() ]
				if sub then
					local vol = rand( KV.Get( body, "volume" ), 1 ) * volume
					self.children[ #self.children + 1 ] = newLayer( sub, vol, onRandom, depth + 1 )
				end
			end
		end
	end
	return self
end

function Layer:Think( now, eye )
	for _, r in ipairs( self.randoms ) do
		if now >= r.next then
			r.next = now + rand( KV.Get( r.body, "time" ), 10 )
			local path = wavePath( r.waves[ math.random( #r.waves ) ] )
			local vol = rand( KV.Get( r.body, "volume" ), 1 ) * r.volume
			local pitch = rand( KV.Get( r.body, "pitch" ), 100 )

			if self.onRandom then
				self.onRandom( path, r.volume, pitch, eye ) -- the layer plays it itself (thunder)
			elseif ( KV.Get( r.body, "position" ) or "" ):lower() == "random" then
				local dir = VectorRand()
				dir.z = math.abs( dir.z ) * 0.5
				dir:Normalize()
				sound.Play( path, eye + dir * RANDOM_DISTANCE, soundLevel( KV.Get( r.body, "soundlevel" ), 0 ), pitch, vol )
			else
				LocalPlayer():EmitSound( path, 0, pitch, vol, CHAN_STATIC )
			end
		end
	end
	for _, c in ipairs( self.children ) do c:Think( now, eye ) end
end

function Layer:Stop()
	for _, snd in ipairs( self.loops ) do
		snd:ChangeVolume( 0, FADE )
		timer.Simple( FADE, function() snd:Stop() end )
	end
	for _, c in ipairs( self.children ) do c:Stop() end
	self.loops, self.randoms, self.children = {}, {}, {}
end

-- State -----------------------------------------------------------------------------

local active = {} -- kind -> { layer, key }
local muted = false

-- Thunder: each strike gets a random distance. Close strikes flash bright
-- and clap almost at once, loud and sharp; distant ones flash dimly and
-- rumble in a few seconds later, quieter and lower.
local THUNDER = {
	flash = { 0.55, 0.07 },     -- brightness, close -> far
	flashTime = { 0.35, 0.6 },  -- seconds
	delay = { 0.05, 5 },        -- flash-to-clap seconds (sound travelling ~340 m/s)
	volume = { 1, 0.25 },       -- times ThunderVolume
	pitch = { 105, 88 },
	soundDist = { 300, 1500 },  -- where the clap comes from, for direction only
}

local flash -- { start, length, strength, flickers }

local function lerpBy( d, pair ) return Lerp( d, pair[ 1 ], pair[ 2 ] ) end

local function thunderStrike( path, volume, pitch, eye )
	local d = math.random() -- 0 = overhead, 1 = far away

	flash = {
		start = CurTime(),
		length = lerpBy( d, THUNDER.flashTime ),
		strength = lerpBy( d, THUNDER.flash ) * math.Rand( 0.85, 1.15 ),
		flickers = math.random( 2, d < 0.4 and 4 or 2 ),
	}

	local dir = VectorRand()
	dir.z = math.abs( dir.z ) * 0.5
	dir:Normalize()
	local pos = eye + dir * lerpBy( d, THUNDER.soundDist )
	local vol = math.min( lerpBy( d, THUNDER.volume ) * volume, 1 )
	local pit = lerpBy( d, THUNDER.pitch ) + ( pitch - 100 ) * 0.5

	timer.Simple( lerpBy( d, THUNDER.delay ) * math.Rand( 0.8, 1.2 ), function()
		if muted then return end
		sound.Play( path, pos, 0, pit, vol )
	end )
end

local function setLayer( kind, scapeName )
	local cur = active[ kind ]
	local rules, volume
	if scapeName then rules, volume = W.LayerFor( kind, scapeName ) end

	local key = rules and ( tostring( rules ) .. "|" .. volume ) or nil
	if cur and cur.key == key then return end

	if cur then cur.layer:Stop() end
	active[ kind ] = nil
	if rules then
		active[ kind ] = { key = key, layer = newLayer( rules, volume, kind == "thunder" and thunderStrike or nil ) }
	end
end

local function stopAll()
	for kind in pairs( KINDS ) do setLayer( kind, nil ) end
end

--- Maps fire amod_rain_stopsounds to silence the rain ambience (e.g. underground)
function W.MuteLoop()
	muted = true
	stopAll()
end

hook.Add( "Think", "hl2a.weathersound", function()
	local ply = LocalPlayer()
	if not IsValid( ply ) then return end

	-- Our weather while it's falling, else the map's own rain/snow brushes
	local kind = GetGlobal2Int( "hl2a.weather.type" )
	local on = GetGlobal2Bool( "hl2a.weather.active" )
	if kind == 0 then
		kind = GetGlobal2Int( "hl2a.weather.maptype" )
		on = kind ~= 0
	end
	on = on and not muted
	local scape = ply:GetNW2String( "hl2a.soundscape" )

	setLayer( "rain", on and kind == 1 and scape or nil )
	setLayer( "snow", on and kind == 2 and scape or nil )
	setLayer( "thunder", on and kind == 1 and GetGlobal2Bool( "hl2a.weather.thunder" ) and scape or nil )

	local now, eye = CurTime(), ply:EyePos()
	for _, a in pairs( active ) do a.layer:Think( now, eye ) end
end )

hook.Add( "ShutDown", "hl2a.weathersound", stopAll )

-- Thunder flash -----------------------------------------------------------------------

hook.Add( "RenderScreenspaceEffects", "hl2a.thunder", function()
	if not flash then return end
	local t = ( CurTime() - flash.start ) / flash.length
	if t >= 1 then flash = nil return end

	-- A few flickers, fading out
	local flicker = math.abs( math.cos( t * math.pi * flash.flickers ) )
	local bright = flicker * ( 1 - t ) ^ 1.5 * flash.strength
	DrawColorModify( {
		[ "$pp_colour_addr" ] = bright * 0.05, [ "$pp_colour_addg" ] = bright * 0.07, [ "$pp_colour_addb" ] = bright * 0.12,
		[ "$pp_colour_brightness" ] = bright, [ "$pp_colour_contrast" ] = 1, [ "$pp_colour_colour" ] = 1,
		[ "$pp_colour_mulr" ] = 0, [ "$pp_colour_mulg" ] = 0, [ "$pp_colour_mulb" ] = 0,
	} )
end )

concommand.Add( "hl2a_thunder_test", function()
	local ply = LocalPlayer()
	if not IsValid( ply ) then return end
	local waves = { "ambient/weather/thunder1.wav", "ambient/weather/thunder3.wav", "ambient/weather/thunder4.wav" }
	thunderStrike( waves[ math.random( #waves ) ], 0.8, 100, ply:EyePos() )
end, nil, "Play one random-distance thunder strike" )

concommand.Add( "hl2a_weathersound_debug", function()
	MsgN( "soundscape: '" .. LocalPlayer():GetNW2String( "hl2a.soundscape" ) .. "'  muted: " .. tostring( muted ) )
	for kind, a in pairs( active ) do
		MsgN( string.format( "  %s: %d loops, %d random, %d nested", kind, #a.layer.loops, #a.layer.randoms, #a.layer.children ) )
	end
end )
