--!strict
-- Localizare în 5 limbi: RO, EN, RU, ES, PT-BR (scrise de mână, vezi GDD). O cheie lipsă cade pe engleză.

local ro = require(script.ro)
local en = require(script.en)
local ru = require(script.ru)
local es = require(script.es)
local pt = require(script.pt)

local LANGUAGES: { [string]: { [string]: string } } = {
	ro = ro,
	en = en,
	ru = ru,
	es = es,
	pt = pt,
}

local Strings = {}

-- "ro-md" → "ro", "pt-br" → "pt"
function Strings.languageFor(localeId: string): string
	local code = string.lower(string.sub(localeId, 1, 2))
	return if LANGUAGES[code] then code else "en"
end

-- Textul pentru o cheie, cu argumente {1}, {2}…
function Strings.get(language: string, key: string, args: { any }?): string
	local text = (LANGUAGES[language] or en)[key] or en[key] or key
	if args then
		text = string.gsub(text, "{(%d+)}", function(index)
			local value = args[tonumber(index) :: number]
			return if value ~= nil then tostring(value) else ""
		end)
	end
	return text
end

function Strings.has(language: string, key: string): boolean
	return LANGUAGES[language] ~= nil and LANGUAGES[language][key] ~= nil
end

return Strings
