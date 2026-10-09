--[[
	The "Faded" look (the original's TAB screen filter). F2 cycles the
	looks: Default (the map's colour grade), Default + Faded, Faded, Off.

	Recovered from client.dll: the options panel built two aliases that
	switched the display gamma ramp,
		tf1 (filter on):  mat_monitorgamma 2.5 - on * 0.05,  TV mode on,
		                  mat_monitorgamma_tv_exp 1.15 + on_exp * 0.05
		tf2 (filter off): mat_monitorgamma 2.3 - off * 0.05, TV mode off
	with the mod's autoexec setting the TV range to 6..265. on / on_exp /
	off are the Options panel sliders amod_filter_brightness_on (0-12,
	default 12), _on_exp (0-12, 12) and _off (0-10, 4). The filter starts
	off, so even then the game ran slightly brighter than stock (2.1).

	GMod can't rely on the hardware gamma ramp (it does nothing in windowed
	mode, and would leak into other gamemodes), so the same curve is applied
	as a screen effect. Source's ramp is
		y = x ^ (gamma / 2.2)                         then, with TV mode on,
		y = y ^ (2.2 / tv_exp),  y = (min + y * (max - min)) / 255
	The power curve is drawn as y = x + a * (x - x^2), fitted at x = 0.25,
	which tracks it well over the exponents the sliders can reach (~0.8-1.9).
	Unlike the original, the HUD isn't affected.
]]

local CV = HL2A.ConVars

local TV_MIN, TV_MAX = 6, 265

local function enabled() return CV.hl2a_screenfilter:GetBool() end

-- Slider value, previewing the Options panel's unapplied changes
local function slider( name )
	local pending = HL2A.OptionsPending
	return tonumber( pending and pending[ name ] ) or CV[ name ]:GetFloat()
end

--- Exponent of the curve for the current state, and whether TV mode is on
function HL2A.ScreenFilterCurve( on )
	if on == nil then on = enabled() end
	if on then
		local gamma = 2.5 - slider( "amod_filter_brightness_on" ) * 0.05
		local tvExp = 1.15 + slider( "amod_filter_brightness_on_exp" ) * 0.05
		return ( gamma / 2.2 ) * ( 2.2 / tvExp ), true
	end
	return ( 2.3 - slider( "amod_filter_brightness_off" ) * 0.05 ) / 2.2, false
end

local function quadCoefficient( k )
	return math.Clamp( ( 0.25 ^ k - 0.25 ) / 0.1875, -1, 1 )
end

-- Drawing ---------------------------------------------------------------------------

local rt, mat

local function setup()
	rt = GetRenderTargetEx( "hl2a_screenfilter", ScrW(), ScrH(), RT_SIZE_FULL_FRAME_BUFFER,
		MATERIAL_RT_DEPTH_NONE, 0, 0, IMAGE_FORMAT_RGB888 )
	mat = CreateMaterial( "hl2a_screenfilter", "UnlitGeneric", {
		[ "$basetexture" ] = rt:GetName(),
		[ "$ignorez" ] = 1,
	} )
end

local function drawCurve( a )
	if math.abs( a ) < 0.01 then return end
	if not rt then setup() end

	render.UpdateScreenEffectTexture()
	local screen = render.GetScreenEffectTexture()

	-- rt = x - x^2
	render.PushRenderTarget( rt )
		render.OverrideBlend( true, BLEND_ONE, BLEND_ZERO, BLENDFUNC_ADD )
		render.DrawTextureToScreen( screen )
		render.OverrideBlend( true, BLEND_DST_COLOR, BLEND_ZERO, BLENDFUNC_ADD )
		render.DrawTextureToScreen( screen )
		render.OverrideBlend( true, BLEND_ONE, BLEND_ONE, BLENDFUNC_SUBTRACT ) -- src - dst
		render.DrawTextureToScreen( screen )
		render.OverrideBlend( false )
	render.PopRenderTarget()

	-- screen +/- |a| * rt
	mat:SetVector( "$color", Vector( 1, 1, 1 ) * math.abs( a ) )
	render.SetMaterial( mat )
	render.OverrideBlend( true, BLEND_ONE, BLEND_ONE, a > 0 and BLENDFUNC_ADD or BLENDFUNC_REVERSE_SUBTRACT )
	render.DrawScreenQuad()
	render.OverrideBlend( false )
end

hook.Add( "RenderScreenspaceEffects", "hl2a.screenfilter", function()
	local k, tv = HL2A.ScreenFilterCurve()
	drawCurve( quadCoefficient( k ) )

	if tv then
		DrawColorModify( {
			[ "$pp_colour_addr" ] = 0, [ "$pp_colour_addg" ] = 0, [ "$pp_colour_addb" ] = 0,
			[ "$pp_colour_brightness" ] = TV_MIN / 255, [ "$pp_colour_contrast" ] = ( TV_MAX - TV_MIN ) / 255,
			[ "$pp_colour_colour" ] = 1,
			[ "$pp_colour_mulr" ] = 0, [ "$pp_colour_mulg" ] = 0, [ "$pp_colour_mulb" ] = 0,
		} )
	end
end )

-- Looks (F2) -------------------------------------------------------------------------
-- The map's colour grade (the original's "epic filter", sv_atmosphere.lua)
-- and this faded TV curve (the original's TAB "screen filter") are combined
-- into looks. Bit 1 = faded, bit 2 = colour grade. F2 cycles them in LOOK_ORDER,
-- starting from Default.

HL2A.LOOKS = { [ 0 ] = "Off", [ 1 ] = "Faded", [ 2 ] = "Default", [ 3 ] = "Default + Faded" }
HL2A.LOOK_ORDER = { 2, 3, 1, 0 }

--- Current look: 0 off, 1 faded, 2 default, 3 default + faded
function HL2A.Look()
	return ( enabled() and 1 or 0 ) + ( GetGlobal2Bool( "hl2a.epicfilter", true ) and 2 or 0 )
end

--- The convar values for a look, as { { name, value } }
function HL2A.LookConVars( look )
	return {
		{ "hl2a_screenfilter", bit.band( look, 1 ) ~= 0 and "1" or "0" },
		{ "amod_epic_filter", bit.band( look, 2 ) ~= 0 and "1" or "0" },
	}
end

local notice

function HL2A.SetLook( look )
	look = look % 4
	HL2A.SetConVars( HL2A.LookConVars( look ) )
	notice = { text = "Look: " .. HL2A.LOOKS[ look ], start = RealTime() }
end

function HL2A.NextLook()
	local cur = HL2A.Look()
	for i, l in ipairs( HL2A.LOOK_ORDER ) do
		if l == cur then return HL2A.SetLook( HL2A.LOOK_ORDER[ i % #HL2A.LOOK_ORDER + 1 ] ) end
	end
	HL2A.SetLook( 2 )
end

surface.CreateFont( "HL2A.LookNotice", { font = "Verdana", size = 22, weight = 600 } )

hook.Add( "HUDPaint", "hl2a.looknotice", function()
	if not notice then return end
	local age = RealTime() - notice.start
	if age > 2 then notice = nil return end
	local a = math.Clamp( ( 2 - age ) * 2, 0, 1 )
	draw.SimpleTextOutlined( notice.text, "HL2A.LookNotice", ScrW() / 2, ScrH() * 0.12, Color( 255, 220, 0, 255 * a ),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color( 0, 0, 0, 200 * a ) )
end )

-- Commands ----------------------------------------------------------------------------

local function set( on ) RunConsoleCommand( "hl2a_screenfilter", on and "1" or "0" ) end

-- Amod_ToggleFilter is the original's bind name, kept so old binds work
concommand.Add( "Amod_ToggleFilter", HL2A.NextLook, nil, "Next look: default, default + faded, faded, off (F2)" )
concommand.Add( "hl2a_next_look", HL2A.NextLook, nil, "Next look (F2)" )
concommand.Add( "hl2a_look", function( _, _, args )
	local want = ( args[ 1 ] or "" ):lower()
	for i = 0, 3 do
		if want == tostring( i ) or want == HL2A.LOOKS[ i ]:lower():gsub( "[^%a]", "" ) then return HL2A.SetLook( i ) end
	end
	MsgN( "hl2a_look: off | faded | default | defaultfaded (or 0-3)" )
end, nil, "Set the look: off, faded, default, defaultfaded" )
concommand.Add( "tf1", function() set( true ) end, nil, "Faded on (original command)" )
concommand.Add( "tf2", function() set( false ) end, nil, "Faded off (original command)" )
