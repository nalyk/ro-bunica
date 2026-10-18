--!strict
-- Decorul ogrăzii pe lei (docs/RESEARCH_SAT_VIU.md §6): obiecte de pus pe 12 sloturi fixe ale ogrăzii. Nu
-- blochează jocul (fără coliziuni, departe de straturi și piedestale) și nu dau avantaj: doar frumusețe.
-- Sloturile sunt în coordonatele ogrăzii (−Z = spre drum); `kind`: "ground" (pe pământ), "fence" (pe gard),
-- "gate" (poarta: culoarea ei).

export type Item = { id: string, kind: "ground" | "fence" | "gate", price: number, color: Color3? }
export type Slot = { id: string, kind: "ground" | "fence" | "gate", offset: Vector3, turn: number }

local items: { Item } = {
	{ id = "muscate", kind = "ground", price = 300 },
	{ id = "trandafiri", kind = "ground", price = 450 },
	{ id = "floareaSoarelui", kind = "ground", price = 350 },
	{ id = "sperietoare", kind = "ground", price = 900 },
	{ id = "roaba", kind = "ground", price = 600 },
	{ id = "banca", kind = "ground", price = 750 },
	{ id = "felinar", kind = "ground", price = 800 },
	{ id = "butoaie", kind = "ground", price = 650 },
	{ id = "ulcioare", kind = "ground", price = 500 },
	{ id = "cocorDeLemn", kind = "ground", price = 1200 },
	{ id = "fantanaCuCumpana", kind = "ground", price = 2500 },
	{ id = "stupi", kind = "ground", price = 1400 },
	{ id = "capitaDeFan", kind = "ground", price = 700 },
	{ id = "masaCuPlacinte", kind = "ground", price = 1600 },
	{ id = "covorRosu", kind = "fence", price = 800, color = Color3.fromRGB(176, 34, 44) },
	{ id = "covorVerde", kind = "fence", price = 800, color = Color3.fromRGB(46, 120, 70) },
	{ id = "prosopBrodat", kind = "fence", price = 600, color = Color3.fromRGB(245, 240, 228) },
	{ id = "ghirlandaArdei", kind = "fence", price = 550, color = Color3.fromRGB(200, 40, 30) },
	{ id = "poartaVerde", kind = "gate", price = 1000, color = Color3.fromRGB(46, 128, 92) },
	{ id = "poartaAlbastra", kind = "gate", price = 1000, color = Color3.fromRGB(52, 98, 178) },
	{ id = "poartaGalbena", kind = "gate", price = 1000, color = Color3.fromRGB(220, 170, 50) },
	{ id = "poartaVisinie", kind = "gate", price = 1000, color = Color3.fromRGB(142, 52, 40) },
}

-- 12 sloturi: colțurile din față, prispa, fâșia din dreapta (în spatele piedestalelor), colțurile din spate,
-- gardul din față (2), gardul din stânga, poarta
local slots: { Slot } = {
	{ id = "s1", kind = "ground", offset = Vector3.new(-33, 0, -29), turn = 30 },
	{ id = "s2", kind = "ground", offset = Vector3.new(33, 0, -29), turn = -30 },
	{ id = "s3", kind = "ground", offset = Vector3.new(-14, 0, 20), turn = 0 },
	{ id = "s4", kind = "ground", offset = Vector3.new(14, 0, 20), turn = 0 },
	{ id = "s5", kind = "ground", offset = Vector3.new(36, 0, 8), turn = -90 },
	{ id = "s6", kind = "ground", offset = Vector3.new(36, 0, -8), turn = -90 },
	{ id = "s7", kind = "ground", offset = Vector3.new(-30, 0, 29), turn = 150 },
	{ id = "s8", kind = "ground", offset = Vector3.new(30, 0, 29), turn = -150 },
	{ id = "s9", kind = "fence", offset = Vector3.new(-22, 0, -34.6), turn = 0 },
	{ id = "s10", kind = "fence", offset = Vector3.new(22, 0, -34.6), turn = 0 },
	{ id = "s11", kind = "fence", offset = Vector3.new(-39.6, 0, 0), turn = 90 },
	{ id = "s12", kind = "gate", offset = Vector3.new(0, 0, -35), turn = 0 },
}

local byId: { [string]: Item } = {}
for _, item in items do
	byId[item.id] = item
end
local slotById: { [string]: Slot } = {}
for _, slot in slots do
	slotById[slot.id] = slot
end

return table.freeze({ items = items, byId = byId, slots = slots, slotById = slotById })
