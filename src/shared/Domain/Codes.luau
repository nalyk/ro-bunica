--!strict
-- Codurile de la magazin (tanti de la magazin le știe pe toate): fiecare cu o răsplată și o dată de expirare;
-- o singură folosire pe profil. Literele mari și mici nu contează.

export type Code = { code: string, reward: { lei: number?, seed: string? }, expires: number }

local Codes = {}

function Codes.redeem(list: { Code }, used: { [string]: boolean }, input: string, now: number): (boolean, any)
	local wanted = string.upper((string.gsub(input, "%s", "")))
	for _, entry in list do
		if string.upper(entry.code) == wanted then
			if used[wanted] then
				return false, "Used"
			end
			if now > entry.expires then
				return false, "Expired"
			end
			used[wanted] = true
			return true, entry.reward
		end
	end
	return false, "Unknown"
end

return Codes
