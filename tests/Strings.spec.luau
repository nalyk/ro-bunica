local Strings = require(Shared.Strings)
local Creatures = require(Shared.Config.Creatures)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Weather = require(Shared.Config.Weather)
local UpgradesConfig = require(Shared.Config.Upgrades)
local Notebook = require(Shared.Config.Notebook)

describe("Strings", function()
	it("alege limba după locale, cu engleza ca rezervă", function()
		expect(Strings.languageFor("ro-md")).toBe("ro")
		expect(Strings.languageFor("en-us")).toBe("en")
		expect(Strings.languageFor("ja-jp")).toBe("en")
	end)

	it("înlocuiește argumentele", function()
		expect(Strings.get("ro", "announce.Steal", { "Ana", "Plăcintonio", "Mihai" })).toBe(
			"Ana a furat Plăcintonio de la Mihai!"
		)
	end)

	it("orice conținut din config are text în ro și en", function()
		for _, language in { "ro", "en" } do
			for _, c in Creatures.list do
				expect(Strings.has(language, "creature." .. c.id)).toBe(true)
			end
			for _, m in Mutations.list do
				expect(Strings.has(language, "mutation." .. m.id)).toBe(true)
			end
			for _, q in Notebook.quests.kinds do
				expect(Strings.has(language, "quest." .. q.kind)).toBe(true)
				expect(Strings.has(language, "quest." .. q.kind .. ".desc")).toBe(true)
			end
			for _, r in Rarities.list do
				expect(Strings.has(language, "rarity." .. r.id)).toBe(true)
			end
			for _, u in UpgradesConfig.list do
				expect(Strings.has(language, "upgrade." .. u.id)).toBe(true)
				expect(Strings.has(language, "upgrade." .. u.id .. ".desc")).toBe(true)
			end
			for _, w in Weather.list do
				expect(Strings.has(language, "weather." .. w.id)).toBe(true)
			end
		end
	end)

	it("ro și en au exact aceleași chei", function()
		local ro = require(Shared.Strings.ro)
		local en = require(Shared.Strings.en)
		for key in ro do
			expect(en[key] ~= nil).toBe(true)
		end
		for key in en do
			expect(ro[key] ~= nil).toBe(true)
		end
	end)
end)
