-- No InitPostEntity hook may return a value: GMod stops at the first one that does
-- (sv_transitions' returned false and silently skipped soundscapes, weather, sandbox ...)
SINGLEPLAYER = false
SetCV( "hl2a_checkpoints", 1 )
HL2A.FixHintText = function( v ) return v end
for _, f in ipairs( { "modules/sv_transitions.lua", "modules/sv_checkpoints.lua", "modules/sv_soundscapes.lua",
	"modules/sv_settings.lua", "modules/sv_mapcommands.lua", "modules/sh_stormfox.lua" } ) do GM_LOAD( f ) end
for id, fn in pairs( HOOKS.InitPostEntity ) do
	local r = fn()
	assert( r == nil, "InitPostEntity hook '" .. tostring( id ) .. "' returned " .. tostring( r ) )
end
