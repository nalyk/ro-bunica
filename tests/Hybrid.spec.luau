local Hybrid = require(Shared.Domain.Hybrid)
local Creatures = require(Shared.Config.Creatures)

local VOWELS = "aeiouăâîAEIOUĂÂÎ"

local function maxConsonantRun(name: string): number
	local run, best = 0, 0
	for _, code in utf8.codes(string.gsub(name, "-", "")) do
		local ch = utf8.char(code)
		if string.find(VOWELS, ch, 1, true) then
			run = 0
		else
			run += 1
			best = math.max(best, run)
		end
	end
	return best
end

describe("Hybrid", function()
	it("numele sunt deterministe și pronunțabile (fără 3 consoane la rând)", function()
		for _, a in Creatures.list do
			for _, b in Creatures.list do
				if a.id ~= b.id then
					for seed = 1, 3 do
						local name = Hybrid.name(a.id, b.id, seed)
						expect(name).toBe(Hybrid.name(a.id, b.id, seed))
						expect(maxConsonantRun(name) <= 2).toBe(true)
						expect(string.find(name, "-", 1, true) ~= nil).toBe(true)
					end
				end
			end
		end
	end)
	it("venitul hibridului: (A + B) × 0,75", function()
		expect(Hybrid.income(100, 60)).toBe(120)
	end)
	it("șansa: 2–8% doar când ambele sunt cel puțin rare", function()
		local common, rare, legendary
		for _, c in Creatures.list do
			if c.rarity == "Common" then
				common = c.id
			elseif c.rarity == "Rare" then
				rare = c.id
			elseif c.rarity == "Legendary" then
				legendary = c.id
			end
		end
		expect(Hybrid.chance(common, rare)).toBe(0)
		local low = Hybrid.chance(rare, rare)
		local high = Hybrid.chance(legendary, legendary)
		expect(low >= 0.02 and low <= 0.08).toBe(true)
		expect(high >= low and high <= 0.08).toBe(true)
	end)
	it("cheia de colecție nu depinde de ordine", function()
		expect(Hybrid.key("CeapaTurbo", "Mamaligator")).toBe(Hybrid.key("Mamaligator", "CeapaTurbo"))
	end)
end)
