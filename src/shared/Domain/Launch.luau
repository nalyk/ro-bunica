--!strict
-- Datele de lansare (LaunchData) din invitații, link-uri, notificări și clipuri: unde vine jucătorul
-- și cine l-a adus. Format scurt, fără JSON: „k=yard;h=<gazda>;r=<recomandarea>” (Roblox: ≤ 200 de octeți).
-- Textul vine de la client, deci se validează strict: tip cunoscut, id-uri întregi pozitive.

local Launch = {}

Launch.MAX_BYTES = 200

export type Kind = "yard" | "clip" | "event" | "notify"
export type Data = { kind: Kind, host: number?, referrer: number? }

local KINDS: { [string]: boolean } = { yard = true, clip = true, event = true, notify = true }

function Launch.encode(data: Data): string
	local parts = { "k=" .. data.kind }
	if data.host then
		table.insert(parts, "h=" .. string.format("%d", data.host))
	end
	if data.referrer then
		table.insert(parts, "r=" .. string.format("%d", data.referrer))
	end
	return table.concat(parts, ";")
end

local function userId(text: string?): number?
	if not text or not string.match(text, "^%d+$") or #text > 15 then
		return nil
	end
	local n = tonumber(text)
	return if n and n > 0 then n else nil
end

function Launch.decode(text: unknown): Data?
	if type(text) ~= "string" or text == "" or #text > Launch.MAX_BYTES then
		return nil
	end
	local fields: { [string]: string } = {}
	-- selene: allow(manual_table_clone)
	for key, value in string.gmatch(text, "(%a)=([^;]*)") do
		fields[key :: string] = value :: string
	end
	local kind = fields.k
	if not kind or not KINDS[kind] then
		return nil
	end
	if (fields.h and not userId(fields.h)) or (fields.r and not userId(fields.r)) then
		return nil
	end
	return { kind = kind :: Kind, host = userId(fields.h), referrer = userId(fields.r) }
end

-- Cine l-a adus pe `joiner` (nimeni, dacă e chiar el)
function Launch.referrerFor(data: Data?, joiner: number): number?
	if not data or not data.referrer or data.referrer == joiner then
		return nil
	end
	return data.referrer
end

return Launch
