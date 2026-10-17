--!strict
-- Geometria unei ogrăzi. Așezarea ogrăzilor în sat: Config/Village și Domain/VillageLayout.

return table.freeze({
	plotCount = 8,
	plotSize = Vector3.new(80, 1, 70), -- X = lățimea la drum, Z = adâncimea
	fenceHeight = 4,
	gateWidth = 12,
	bedGrid = table.freeze({ columns = 5, rows = 2, spacing = 7 }), -- maxim 10 straturi
	pedestalGrid = table.freeze({ columns = 5, rows = 4, spacing = 7 }), -- maxim 20 piedestale
	showcaseSlots = 3, -- creaturi pe gardul de laudă
})
