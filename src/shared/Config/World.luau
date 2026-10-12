--!strict
-- Geometria satului. Ogrăzile sunt de-a lungul unui drum pe axa X.

return table.freeze({
	plotCount = 8,
	plotSize = Vector3.new(80, 1, 70), -- X = lățimea la drum, Z = adâncimea
	plotGap = 10,
	roadWidth = 24,
	fenceHeight = 4,
	gateWidth = 12,
	bedGrid = table.freeze({ columns = 5, rows = 2, spacing = 7 }), -- maxim 10 straturi
	pedestalGrid = table.freeze({ columns = 5, rows = 4, spacing = 7 }), -- maxim 20 piedestale
	showcaseSlots = 3, -- creaturi pe gardul de laudă
})
