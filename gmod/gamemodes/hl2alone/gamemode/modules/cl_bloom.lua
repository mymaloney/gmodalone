--[[
	Per-map bloom from time_info ("BloomEnabled", "BloomScale",
	"BloomScalarFactor" in the map's Night block; used by the Portal and
	background maps).

	On HDR maps the engine's own bloom is scaled through
	mat_bloom_scalefactor_scalar (restored when the map unloads). LDR maps
	have no engine bloom to scale, so a DrawBloom pass stands in.
	hl2a_bloom 0 turns both off.
]]

local KV = HL2A.KV
local TI = HL2A.TimeInfo

local bloom -- { scale, factor } for the current map, or nil
local savedScalar

local function restoreScalar()
	if savedScalar then RunConsoleCommand( "mat_bloom_scalefactor_scalar", savedScalar ) end
	savedScalar = nil
end

local function apply()
	restoreScalar()
	bloom = nil

	local block = TI.GetCurrentBlock()
	if not block or KV.Get( block, "BloomEnabled" ) ~= "1" or not HL2A.ConVars.hl2a_bloom:GetBool() then return end

	bloom = {
		scale = tonumber( KV.Get( block, "BloomScale" ) ) or 1,
		factor = tonumber( KV.Get( block, "BloomScalarFactor" ) ) or 1,
	}

	local scalar = GetConVar( "mat_bloom_scalefactor_scalar" )
	if render.GetHDREnabled() and scalar then
		savedScalar = scalar:GetString()
		RunConsoleCommand( "mat_bloom_scalefactor_scalar", tostring( bloom.factor ) )
	end
end

hook.Add( "RenderScreenspaceEffects", "hl2a.bloom", function()
	if not bloom or render.GetHDREnabled() or not HL2A.PostProcessOn() then return end
	local amount = math.Clamp( bloom.scale * bloom.factor * 0.2, 0, 2 )
	if amount <= 0 then return end
	DrawBloom( 0.65, amount, 9, 9, 1, 1, 1, 1, 1 )
end )

hook.Add( "InitPostEntity", "hl2a.bloom", apply )
hook.Add( "HL2A_TimeInfoChanged", "hl2a.bloom", apply )
hook.Add( "ShutDown", "hl2a.bloom", restoreScalar )
cvars.AddChangeCallback( "hl2a_bloom", function() timer.Simple( 0, apply ) end, "hl2a.bloom" )
cvars.AddChangeCallback( "hl2a_timeinfo_theme", function() timer.Simple( 0, apply ) end, "hl2a.bloom" )
