--[[
	Loads the mod's VGUI localization tokens ("lang" { "Tokens" { ... } })
	into GMod's language system so "#Token" strings resolve in Derma.
]]

local KV = HL2A.KV

local FILES = {
	"resource/hl2_alonemod_english.txt",
	"resource/localization/alone_mod_english.txt",
}

function HL2A.LoadLocalization()
	local count = 0
	for _, rel in ipairs( FILES ) do
		for _, root in ipairs( KV.ParseFile( rel ) or {} ) do
			for _, kv in ipairs( KV.Get( root.value, "Tokens" ) or {} ) do
				if isstring( kv.value ) then
					language.Add( kv.key, HL2A.Spell( kv.value ) )
					count = count + 1
				end
			end
		end
	end
	MsgN( "[HL2A] loaded " .. count .. " localization tokens" )
end
