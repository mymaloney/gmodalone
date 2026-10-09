--[[
	The screen filter (original key TAB). F2 / Amod_ToggleFilter now cycles
	filter presets: off, this screen filter, the epic filter, both.

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

-- Filter presets (F2) -------------------------------------------------------------------
-- The screen filter and the epic filter (colour correction, sv_atmosphere.lua)
-- are presets of one filter: F2 cycles Off -> Screen -> Epic -> Both -> Off.

HL2A.FILTER_PRESETS = { "Filters off", "Screen filter", "Epic filter", "Screen + epic filter" }

--- 0 off, 1 screen, 2 epic, 3 both
function HL2A.FilterPreset()
	return ( enabled() and 1 or 0 ) + ( GetGlobal2Bool( "hl2a.epicfilter", true ) and 2 or 0 )
end

local notice

function HL2A.SetFilterPreset( p )
	p = p % 4
	HL2A.SetConVars( {
		{ "hl2a_screenfilter", bit.band( p, 1 ) ~= 0 and "1" or "0" },
		{ "amod_epic_filter", bit.band( p, 2 ) ~= 0 and "1" or "0" },
	} )
	notice = { text = HL2A.FILTER_PRESETS[ p + 1 ], start = RealTime() }
end

surface.CreateFont( "HL2A.FilterNotice", { font = "Verdana", size = 22, weight = 600 } )

hook.Add( "HUDPaint", "hl2a.filternotice", function()
	if not notice then return end
	local age = RealTime() - notice.start
	if age > 2 then notice = nil return end
	local a = math.Clamp( ( 2 - age ) * 2, 0, 1 )
	draw.SimpleTextOutlined( notice.text, "HL2A.FilterNotice", ScrW() / 2, ScrH() * 0.12, Color( 255, 220, 0, 255 * a ),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color( 0, 0, 0, 200 * a ) )
end )

-- Commands ----------------------------------------------------------------------------

local function set( on ) RunConsoleCommand( "hl2a_screenfilter", on and "1" or "0" ) end

concommand.Add( "Amod_ToggleFilter", function() HL2A.SetFilterPreset( HL2A.FilterPreset() + 1 ) end, nil,
	"Next filter preset: off, screen filter, epic filter, both (F2)" )
concommand.Add( "hl2a_filter_preset", function( _, _, args ) HL2A.SetFilterPreset( tonumber( args[ 1 ] ) or 0 ) end, nil,
	"Set the filter preset: 0 off, 1 screen filter, 2 epic filter, 3 both" )
concommand.Add( "tf1", function() set( true ) end, nil, "Screen filter on" )
concommand.Add( "tf2", function() set( false ) end, nil, "Screen filter off" )
