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

	The same player also plays the mod's own soundscapes (those in
	scripts/soundscapes_amod_*.txt). The engine only loads soundscape files
	from scripts/, which the Workshop doesn't allow, so the addon ships them
	in data_static and they're played here instead, whenever the engine
	doesn't have its own copy. Sounds tied to a soundscape "position" play
	without direction.
]]

local CV = HL2A.ConVars
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
local luaPlayed -- lowercased soundscape name -> true: the engine can't play it, we do

local function loadDefs()
	defs, luaPlayed = {}, {}
	for _, rel in ipairs( HL2A.FindFiles( "scripts/soundscapes*.txt" ) ) do
		if not rel:find( "manifest", 1, true ) then
			local base = rel:match( "([^/]+)$" ):gsub( "%.txt%.txt$", ".txt" )
			local ours = base:StartWith( "soundscapes_amod_" ) and not file.Exists( "scripts/" .. base, "GAME" )
			for _, root in ipairs( KV.ParseFile( rel ) or {} ) do
				local name = root.key:lower()
				if istable( root.value ) and not defs[ name ] then -- first wins, like the engine
					defs[ name ] = root.value
					if ours then luaPlayed[ name ] = true end
				end
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
	local self = setmetatable( { loops = {}, loopVols = {}, gain = 1, randoms = {}, children = {}, onRandom = onRandom }, Layer )
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
					local pitch = rand( KV.Get( body, "pitch" ), 100 )
					-- A volume change in the same frame the sound starts is dropped,
					-- so start quiet and fade in a moment later; Layer:Think keeps
					-- checking, since one issued while the map is still loading can
					-- be lost too (the loop then stayed at 1% for the whole map)
					snd:PlayEx( 0.01, pitch )
					timer.Simple( 0.1, function() if snd:IsPlaying() then snd:ChangeVolume( vol * self.gain, FADE ) end end )
					self.loops[ #self.loops + 1 ] = snd
					self.loopVols[ #self.loops ] = vol
					self.loopPitch = self.loopPitch or {}
					self.loopPitch[ #self.loops ] = pitch
					self.checkAt = CurTime() + FADE + 1
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

-- Loops that stopped or never reached their volume (lost while loading) are put right
local function healLoops( self, now )
	if not self.checkAt or now < self.checkAt then return end
	self.checkAt = now + 1
	for i, snd in ipairs( self.loops ) do
		local want = self.loopVols[ i ] * self.gain
		if not snd:IsPlaying() then
			snd:PlayEx( 0.01, self.loopPitch and self.loopPitch[ i ] or 100 )
			timer.Simple( 0.1, function() if snd:IsPlaying() then snd:ChangeVolume( self.loopVols[ i ] * self.gain, FADE ) end end )
			self.checkAt = now + FADE + 1
		elseif math.abs( snd:GetVolume() - want ) > 0.03 then
			snd:ChangeVolume( want, 0.5 )
		end
	end
end

function Layer:Think( now, eye )
	healLoops( self, now )
	for _, r in ipairs( self.randoms ) do
		if now >= r.next then
			r.next = now + rand( KV.Get( r.body, "time" ), 10 )
			local path = wavePath( r.waves[ math.random( #r.waves ) ] )
			local vol = rand( KV.Get( r.body, "volume" ), 1 ) * r.volume * self.gain
			local pitch = rand( KV.Get( r.body, "pitch" ), 100 )

			if self.onRandom then
				self.onRandom( path, r.volume * self.gain, pitch, eye ) -- the layer plays it itself (thunder)
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

--- Scales the whole layer (how exposed to the sky the player is), fading loops
function Layer:SetGain( g )
	if math.abs( g - self.gain ) < 0.02 then return end
	self.gain = g
	if self.checkAt then self.checkAt = math.max( self.checkAt, CurTime() + 1 ) end -- let the fade finish
	for i, snd in ipairs( self.loops ) do
		if snd:IsPlaying() then snd:ChangeVolume( self.loopVols[ i ] * g, 0.5 ) end
	end
	for _, c in ipairs( self.children ) do c:SetGain( g ) end
end

function Layer:Stop()
	for _, snd in ipairs( self.loops ) do
		snd:ChangeVolume( 0, FADE )
		timer.Simple( FADE, function() snd:Stop() end )
	end
	for _, c in ipairs( self.children ) do c:Stop() end
	self.loops, self.loopVols, self.randoms, self.children = {}, {}, {}, {}
	self.checkAt = nil
end

-- For the Soundscape editor (cl_soundscapeeditor.lua): play any rules, and
-- swap in edited soundscapes so nested playsoundscape rules find them
function W.NewLayer( rules, volume )
	if not defs then loadDefs() end
	return newLayer( rules, volume or 1 )
end

function W.SetDef( name, rules )
	if not defs then loadDefs() end
	defs[ name:lower() ] = rules
end

-- State -----------------------------------------------------------------------------

-- Sky exposure ----------------------------------------------------------------------
-- Rain is chosen per soundscape, and many interiors' soundscapes aren't named
-- as such, so the weather beds also follow how much open sky the player can
-- see: straight up counts most, plus eight directions angled upwards (so a
-- doorway lets some rain in). Indoors it drops to a faint murmur.

local EXPOSURE_RAIN_INDOORS = 0.08   -- rain/snow gain with no sky in sight
local EXPOSURE_THUNDER_INDOORS = 0.4 -- thunder carries through walls
local EXPOSURE_RATE = 1.2            -- how fast it follows (per second)
local SKY_TRACE = 3000

local exposure, exposureTarget, nextTrace = 1, 1, 0

local function skyDirs()
	local out = { { Vector( 0, 0, 1 ), 3 } }
	for i = 0, 7 do
		local a = math.rad( i * 45 )
		out[ #out + 1 ] = { Vector( math.cos( a ) * 0.7, math.sin( a ) * 0.7, 0.7 ), 1 }
	end
	return out
end
local SKY_DIRS = skyDirs()

local function measureExposure( eye )
	local seen, total = 0, 0
	for _, d in ipairs( SKY_DIRS ) do
		local tr = util.TraceLine( { start = eye, endpos = eye + d[ 1 ] * SKY_TRACE, mask = MASK_SOLID_BRUSHONLY } )
		if tr.HitSky or not tr.Hit then seen = seen + d[ 2 ] end
		total = total + d[ 2 ]
	end
	return math.min( seen / total * 1.5, 1 ) -- half the sky visible already sounds "outside"
end

function W.Exposure() return exposure end

local active = {} -- kind -> { layer, key }
local muted = false
local base -- { layer, name }: the current soundscape, when we play it (see top)

local function setBase( name )
	if not defs then loadDefs() end
	name = name and name:lower() or nil
	if name and not luaPlayed[ name ] then name = nil end
	if W.Previewing then name = nil end -- the soundscape editor is playing something
	if ( base and base.name ) == name then return end
	if base then base.layer:Stop() end
	base = name and { name = name, layer = newLayer( defs[ name ], 1 ) } or nil
end

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

-- Lightning bolts ------------------------------------------------------------------------
-- Closer strikes may show a bolt in the sky in the clap's direction, drawn
-- right after the 2D skybox so buildings, the 3D skybox and interiors hide
-- it. The mod's materials/lightning/* images are used when present, else a
-- generated bolt.

local BOLT_CHANCE = 0.8     -- for strikes closer than BOLT_MAX_DIST
local BOLT_MAX_DIST = 0.7
local BOLT_RADIUS = 100     -- drawing distance around a camera at the origin
local beamMat = Material( "sprites/lgtning" )

local boltMats
local function lightningMaterials()
	if boltMats then return boltMats end
	boltMats = {}
	for _, f in ipairs( file.Find( "materials/lightning/*.vmt", "GAME" ) ) do
		local m = Material( "lightning/" .. f:gsub( "%.vmt$", "" ) )
		if not m:IsError() then boltMats[ #boltMats + 1 ] = m end
	end
	return boltMats
end

-- A jagged line from high in the sky to the horizon, with a few forks, as
-- { x = sideways, e = elevation (radians) } points
local function makeBoltShape( top )
	local lines, main = {}, {}
	local x, steps = 0, 14
	for i = 0, steps do
		local e = top * ( 1 - i / steps ) - 0.02
		main[ #main + 1 ] = { x = x, e = e }
		x = x + math.Rand( -4, 4 )
		if i > 2 and i < steps - 2 and math.random() < 0.18 then
			local fork, fx, fe = {}, x, e
			for _ = 1, math.random( 3, 5 ) do
				fork[ #fork + 1 ] = { x = fx, e = fe }
				fx, fe = fx + math.Rand( -6, 6 ), fe - top / steps * math.Rand( 0.6, 1.2 )
			end
			lines[ #lines + 1 ] = { pts = fork, width = 0.5 }
		end
	end
	table.insert( lines, 1, { pts = main, width = 1 } )
	return lines
end

local bolt -- { start, length, flickers, yaw, scale, mat, shape }

local function startBolt( d, dir )
	if not CV.hl2a_lightning_bolts:GetBool() or d > BOLT_MAX_DIST or math.random() > BOLT_CHANCE then return end
	local mats = lightningMaterials()
	bolt = {
		start = CurTime(), length = flash.length, flickers = flash.flickers,
		yaw = dir:Angle().y + 0, scale = Lerp( d / BOLT_MAX_DIST, 1, 0.45 ),
		mat = #mats > 0 and mats[ math.random( #mats ) ] or nil,
	}
	if not bolt.mat then bolt.shape = makeBoltShape( math.rad( Lerp( d, 40, 15 ) ) ) end
end

hook.Add( "PostDraw2DSkyBox", "hl2a.lightning", function()
	if not bolt then return end
	local t = ( CurTime() - bolt.start ) / bolt.length
	if t >= 1 then bolt = nil return end
	local alpha = math.abs( math.cos( t * math.pi * bolt.flickers ) ) * ( 1 - t ) ^ 0.7 * bolt.scale

	local fwd = Angle( 0, bolt.yaw, 0 ):Forward()
	local right = Angle( 0, bolt.yaw, 0 ):Right()
	local function point( x, e )
		return ( fwd * math.cos( e ) + vector_up * math.sin( e ) ) * BOLT_RADIUS + right * x * bolt.scale
	end

	local vs = render.GetViewSetup and render.GetViewSetup()
	cam.Start3D( vector_origin, EyeAngles(), vs and vs.fov or nil )
	render.OverrideDepthEnable( true, false )

	if bolt.mat then
		-- An image of a bolt standing on the horizon
		local h = BOLT_RADIUS * 0.8 * bolt.scale
		local base = point( 0, -0.02 )
		local up = vector_up * h
		local half = right * h * 0.25
		bolt.mat:SetFloat( "$alpha", alpha )
		render.SetMaterial( bolt.mat )
		render.DrawQuad( base + up - half, base + up + half, base + half, base - half )
	else
		render.SetMaterial( beamMat )
		local col = Color( 220, 225, 255, 255 * alpha )
		for _, line in ipairs( bolt.shape ) do
			for i = 2, #line.pts do
				local a, b = line.pts[ i - 1 ], line.pts[ i ]
				local p1, p2 = point( a.x, a.e ), point( b.x, b.e )
				render.DrawBeam( p1, p2, 3 * line.width * bolt.scale, 0, 1, Color( 150, 160, 255, 90 * alpha ) ) -- glow
				render.DrawBeam( p1, p2, 0.8 * line.width * bolt.scale, 0, 1, col )
			end
		end
	end

	render.OverrideDepthEnable( false )
	cam.End3D()
end )

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
	startBolt( d, dir )
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
	-- Rain and snow beds play as full-volume 2D loops, louder than the engine
	-- mixed them; hl2a_weathersound_volume scales them (thunder keeps its own)
	if rules and kind ~= "thunder" then volume = volume * math.Clamp( CV.hl2a_weathersound_volume:GetFloat(), 0, 1 ) end

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

local function stopEverything()
	stopAll()
	setBase( nil )
end

--- Maps fire amod_rain_stopsounds, but the original DLLs never implemented it
-- (the string isn't in them): it did nothing, so it does nothing here.
-- Muting on it silenced the rain for the rest of the map. Indoors is handled
-- by the sky exposure above.
function W.MuteLoop() end

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
	setBase( scape ~= "" and scape or nil )

	setLayer( "rain", on and kind == 1 and scape or nil )
	setLayer( "snow", on and kind == 2 and scape or nil )
	setLayer( "thunder", on and kind == 1 and GetGlobal2Bool( "hl2a.weather.thunder" ) and scape or nil )

	local now, eye = CurTime(), ply:EyePos()
	if now >= nextTrace then
		nextTrace = now + 0.2
		exposureTarget = measureExposure( eye )
	end
	exposure = math.Approach( exposure, exposureTarget, FrameTime() * EXPOSURE_RATE )
	for kind, a in pairs( active ) do
		local floor = kind == "thunder" and EXPOSURE_THUNDER_INDOORS or EXPOSURE_RAIN_INDOORS
		a.layer:SetGain( Lerp( exposure, floor, 1 ) )
		a.layer:Think( now, eye )
	end
	if base then base.layer:Think( now, eye ) end
end )

hook.Add( "ShutDown", "hl2a.weathersound", stopEverything )

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
	MsgN( "soundscape: '" .. LocalPlayer():GetNW2String( "hl2a.soundscape" ) .. "'  muted: " .. tostring( muted )
		.. string.format( "  sky exposure: %.2f", exposure ) )
	MsgN( "  played by Lua: " .. ( base and string.format( "%s (%d loops, %d random)", base.name, #base.layer.loops, #base.layer.randoms ) or "no (engine or none)" ) )
	for kind, a in pairs( active ) do
		MsgN( string.format( "  %s: %d loops, %d random, %d nested, gain %.2f", kind, #a.layer.loops, #a.layer.randoms, #a.layer.children, a.layer.gain ) )
	end
end )
