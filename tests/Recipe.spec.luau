local Recipe = require(Shared.Domain.Recipe)

describe("Recipe", function()
	it("pașii unei plăcinte: aluat, umplutura comenzii, cuptor, livrare", function()
		local pie = Recipe.new()
		expect(Recipe.next(pie)).toBe("Aluat")
		expect(Recipe.apply(pie, "Aluat")).toBe(true)
		expect(Recipe.next(pie)).toBe("Umplutura")
		expect(Recipe.apply(pie, "Cuptor")).toBe(false) -- pe sărite: nu
		expect(Recipe.apply(pie, "Umplutura:Varza")).toBe(true)
		expect(pie.filling).toBe("Varza")
		expect(Recipe.apply(pie, "Cuptor")).toBe(true)
		expect(Recipe.next(pie)).toBe("Livrare")
	end)
	it("livrarea se potrivește doar comenzii cu aceeași umplutură", function()
		local pie = Recipe.new()
		for _, step in { "Aluat", "Umplutura:Branza", "Cuptor" } do
			Recipe.apply(pie, step)
		end
		expect(Recipe.complete("Branza", pie)).toBe(true)
		expect(Recipe.complete("Visine", pie)).toBe(false)
		local raw = Recipe.new()
		Recipe.apply(raw, "Aluat")
		expect(Recipe.complete("Branza", raw)).toBe(false) -- necoaptă
	end)
	it("comenzile sunt dintre cele trei plăcinte", function()
		for _, kind in { "Branza", "Varza", "Visine" } do
			expect(table.find(Recipe.ORDERS, kind) ~= nil).toBe(true)
		end
	end)
end)
