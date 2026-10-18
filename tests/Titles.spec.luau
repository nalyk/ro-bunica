local Titles = require(Shared.Domain.Titles)

describe("Titles", function()
	it("niciun titlu la început", function()
		expect(#Titles.earned({})).toBe(0)
	end)
	it("fiecare titlu vine la pragul lui, nu mai devreme", function()
		for _, def in Titles.list do
			local below = { [def.stat] = def.need - 1 }
			expect(table.find(Titles.earned(below), def.id)).toBeNil()
			local at = { [def.stat] = def.need }
			expect(table.find(Titles.earned(at), def.id) ~= nil).toBe(true)
		end
	end)
	it("cele șapte titluri din cercetare există", function()
		for _, id in { "hot", "papucAur", "pescar", "dansatoare", "colectionar", "gospodina", "prieten" } do
			expect(Titles.byId[id] ~= nil).toBe(true)
		end
	end)
	it("se poate alege doar un titlu câștigat", function()
		expect(Titles.canUse({ steals = 30 }, "hot")).toBe(true)
		expect(Titles.canUse({ steals = 3 }, "hot")).toBe(false)
		expect(Titles.canUse({}, "nuExista")).toBe(false)
	end)
end)
