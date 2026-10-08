--[[
	Valve KeyValues parser.

	GMod's util.KeyValuesToTable lowercases keys and collapses duplicates, but the
	Alone mod's data files depend on duplicate keys ("song", "origin", "[random]",
	"wave" ...) and on ordering. This parser keeps both.

	A parsed block is an array of { key = string, value = string | block }.
	Backslashes are NOT treated as escapes: Source data files contain raw
	Windows paths such as "items\flashlight1.wav".
]]

HL2A.KV = HL2A.KV or {}
local KV = HL2A.KV

local OPEN, CLOSE = {}, {}

local function tokenize( text )
	local tokens = {}
	local i, n = 1, #text

	while i <= n do
		local _, wsEnd = text:find( "^%s+", i )
		if wsEnd then
			i = wsEnd + 1
		else
			local c = text:sub( i, i )

			if c == "/" and text:sub( i + 1, i + 1 ) == "/" then
				local nl = text:find( "\n", i, true )
				i = nl and nl + 1 or n + 1
			elseif c == "{" then
				tokens[ #tokens + 1 ] = OPEN
				i = i + 1
			elseif c == "}" then
				tokens[ #tokens + 1 ] = CLOSE
				i = i + 1
			elseif c == "\"" then
				local close = text:find( "\"", i + 1, true ) or ( n + 1 )
				tokens[ #tokens + 1 ] = text:sub( i + 1, close - 1 )
				i = close + 1
			else
				local s, e = text:find( "^[^%s{}\"]+", i )
				local tok = text:sub( s, e )
				i = e + 1

				-- Trailing "//comment" glued to an unquoted token
				local cmt = tok:find( "//", 1, true )
				if cmt then
					tok = tok:sub( 1, cmt - 1 )
					local nl = text:find( "\n", i, true )
					i = nl and nl + 1 or n + 1
				end

				-- Unquoted [$WIN32]-style conditionals are dropped
				if tok ~= "" and not tok:match( "^%[.*%]$" ) then
					tokens[ #tokens + 1 ] = tok
				end
			end
		end
	end

	return tokens
end

local function parseBlock( tokens, pos )
	local block = {}

	while pos <= #tokens do
		local tok = tokens[ pos ]

		if tok == CLOSE then
			return block, pos + 1
		elseif tok == OPEN then
			-- Anonymous block, keep it under an empty key
			local child
			child, pos = parseBlock( tokens, pos + 1 )
			block[ #block + 1 ] = { key = "", value = child }
		else
			local nxt = tokens[ pos + 1 ]
			if nxt == OPEN then
				local child
				child, pos = parseBlock( tokens, pos + 2 )
				block[ #block + 1 ] = { key = tok, value = child }
			elseif nxt == nil or nxt == CLOSE then
				pos = pos + 1 -- dangling key without a value
			else
				block[ #block + 1 ] = { key = tok, value = nxt }
				pos = pos + 2
			end
		end
	end

	return block, pos
end

--- Converts UTF-16 (with BOM) text to UTF-8 and strips a UTF-8 BOM.
-- Several of the mod's localization files are saved as UTF-16LE.
function KV.DecodeText( raw )
	if not raw then return nil end

	local b1, b2 = raw:byte( 1, 2 )
	local le
	if b1 == 0xFF and b2 == 0xFE then le = true elseif b1 == 0xFE and b2 == 0xFF then le = false end

	if le == nil then
		if raw:sub( 1, 3 ) == "\239\187\191" then return raw:sub( 4 ) end
		return raw
	end

	local out, n = {}, 0
	local i, len = 3, #raw
	while i + 1 <= len do
		local a, b = raw:byte( i, i + 1 )
		local cp = le and ( a + b * 256 ) or ( a * 256 + b )
		i = i + 2

		if cp >= 0xD800 and cp <= 0xDBFF and i + 1 <= len then
			local c, d = raw:byte( i, i + 1 )
			local lo = le and ( c + d * 256 ) or ( c * 256 + d )
			cp = 0x10000 + ( cp - 0xD800 ) * 0x400 + ( lo - 0xDC00 )
			i = i + 2
		end

		n = n + 1
		out[ n ] = utf8.char( cp )
	end

	return table.concat( out )
end

function KV.Parse( text )
	return ( parseBlock( tokenize( KV.DecodeText( text ) or "" ), 1 ) )
end

--- Parses a file through the mod data search paths (see sh_data.lua).
function KV.ParseFile( rel )
	local text = HL2A.ReadFile( rel )
	if not text then return nil end
	return KV.Parse( text )
end

--- First value for key (case-insensitive), or nil.
function KV.Get( block, key )
	if not block then return nil end
	key = key:lower()
	for _, kv in ipairs( block ) do
		if kv.key:lower() == key then return kv.value end
	end
end

--- All values for key (case-insensitive), in file order.
function KV.GetAll( block, key )
	local out = {}
	if not block then return out end
	key = key:lower()
	for _, kv in ipairs( block ) do
		if kv.key:lower() == key then out[ #out + 1 ] = kv.value end
	end
	return out
end

--- Flattens a block into a lowercase-keyed table (last duplicate wins).
function KV.ToTable( block )
	local out = {}
	if not block then return out end
	for _, kv in ipairs( block ) do
		out[ kv.key:lower() ] = istable( kv.value ) and KV.ToTable( kv.value ) or kv.value
	end
	return out
end
