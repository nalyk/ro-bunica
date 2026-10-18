--!strict
-- Viața satului (AmbientLifeController, doar pe client, fără coliziuni): gâștele pe ulicioara centrului, găinile
-- în ogrăzi, câinii la porți (latră în lanț la un străin noaptea), sătenii pe drumuri, berzele, rufele.

return table.freeze({
	updateHz = 20, -- animațiile se actualizează de 20 de ori pe secundă
	nearDistance = 260, -- dincolo de atât, animalele stau pe loc (nu se calculează)
	geese = table.freeze({ count = 6, speed = 3.2, spacing = 2.6 }),
	hensPerYard = 3,
	hens = table.freeze({
		area = table.freeze({ min = Vector2.new(-28, 4), max = Vector2.new(-8, 22) }),
		speed = 2.4,
	}),
	dog = table.freeze({
		spot = Vector3.new(9, 0, -29), -- în ogradă, lângă poartă (coordonate locale)
		barkDistance = 26, -- un străin la atâția studs de poartă, noaptea
		chainDelay = 0.7, -- câinii vecini se iau după el, unul câte unul
		barkCooldown = 4,
	}),
	villagers = table.freeze({
		{ route = "drumulMare", from = -0.85, to = -0.2, speed = 4.2, shirt = Color3.fromRGB(70, 110, 190) },
		{ route = "ulitaDeDeal", from = 0.15, to = 0.8, speed = 3.6, shirt = Color3.fromRGB(190, 70, 70) },
		{
			route = "ulicioaraCentrului",
			from = 0.0,
			to = 1.0,
			speed = 3.0,
			shirt = Color3.fromRGB(240, 236, 220),
		},
	}),
	laundry = table.freeze({ from = Vector3.new(-26, 0, 13), to = Vector3.new(-12, 0, 13), items = 5 }),
	stork = table.freeze({ circleRadius = 140, circleHeight = 70, circleSeconds = 90 }),
})
