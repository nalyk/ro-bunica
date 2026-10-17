--!strict
-- Satul de vale (docs/RESEARCH_SAT_VIU.md §2, așezarea L4): drumul mare pe lângă pârâu, ulița de deal paralelă,
-- legate la capete, prin centru și prin două scurtături. Pozițiile ogrăzilor sunt alese de o căutare automată
-- (oglinda Python a acestei geometrii, cu verificarea drumurilor prin ogrăzi) pentru echitatea raidurilor:
-- CV-ul expunerii 0,084, max/min 1,22.
-- Coordonatele sunt în studs; (x, z) pe plan, cu nordul (dealul) spre +Z.

return table.freeze({
	-- drumul mare: z = lowA·sin(x / lowP) − lowQ·x², pe x ∈ [−extent, extent]
	extent = 360,
	low = table.freeze({ a = 30, p = 120, q = 0.0006 }),
	-- ulița de deal: X = x·0,92 + 10, z = upBase + upA·sin(x / upP + upPhase) − upQ·x²
	up = table.freeze({ scale = 0.92, shift = 10, base = 150, a = 28, p = 90, phase = 1.1, q = 0.0004 }),
	roadWidth = 18,
	laneWidth = 12,
	gateOffset = 15, -- poarta față de axa drumului
	riverOffset = 75, -- pârâul, la sud de drumul mare
	riverWidth = 14,
	-- parametrul x al fiecărei ogrăzi pe drumul ei (căutare automată, seed 1)
	plotsLow = table.freeze({ -262.33, -108.88, 76.49, 242.75 }),
	plotsUp = table.freeze({ -237.33, -107.9, 98.16, 246.85 }),
	shortcuts = table.freeze({ -211.93, 205.89 }), -- poteci între drumul mare și ulița de deal
	hub = Vector3.new(15, 0, 75), -- centrul: fântâna, magazinul, stația (pe ulicioara din mijloc)
	-- locurile satului (x, z) și înălțimea lor (dealurile din nord)
	sites = table.freeze({
		centru = Vector3.new(15, 0, 75),
		magazin = Vector3.new(58, 0, 115),
		statie = Vector3.new(-28, 0, 80),
		discoteca = Vector3.new(-52, 0, 122),
		terenScoala = Vector3.new(124, 0, 112),
		bazar = Vector3.new(-125, 0, 109),
		bucatarie = Vector3.new(72, 0, 147),
		claie = Vector3.new(-193, 0, 86),
		livada = Vector3.new(-262, 0, 74),
		iaz = Vector3.new(235, 0, -150),
		lanPorumb = Vector3.new(-120, 0, -165),
		via = Vector3.new(150, 14, 315),
		stana = Vector3.new(-205, 16, 325),
		moara = Vector3.new(-40, 20, 335),
		biserica = Vector3.new(65, 20, 330),
		codru = Vector3.new(-330, 10, 290),
		gara = Vector3.new(0, 0, -235),
	}),
	-- aspectul ogrăzilor: aceeași valoare de joc, alt chip (porțile vopsite ca în satele Moldovei)
	gateColors = table.freeze({
		Color3.fromRGB(52, 98, 178), -- albastru
		Color3.fromRGB(46, 128, 92), -- verde
		Color3.fromRGB(112, 74, 46), -- maro, lemn vopsit
		Color3.fromRGB(46, 140, 150), -- turcoaz
	}),
	trimColors = table.freeze({
		Color3.fromRGB(70, 110, 190),
		Color3.fromRGB(240, 236, 220),
		Color3.fromRGB(96, 150, 96),
		Color3.fromRGB(150, 98, 60),
	}),
	treeSets = 4, -- seturi de decor: nuci și vișini, bolta de vie, stupii, lemnele și căpița
	variantSeed = 7,
	bridges = table.freeze({ -120, 140 }), -- podurile peste pârâu (parametrul x pe drumul mare)
	railwayZ = -235, -- linia ferată, de la vest la est
	-- înălțimea terenului: valea plană între sud și nord, dealuri în afara ei
	valley = table.freeze({ south = -260, north = 275, hillSlope = 0.22, hillMax = 32 }),
})
