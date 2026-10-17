--!strict
-- Caietul Bunicii: colecția, treburile zilei și renașterea (design: docs/superpowers/specs/2026-10-17-retentie-design.md).

return table.freeze({
	collection = table.freeze({
		rewardShare = 0.5, -- prima descoperire: prețul de vânzare (Normală, cu mutația) × asta
		minReward = 50,
		-- praguri de intrări descoperite; fiecare dă +5% venit permanent
		milestones = table.freeze({ 10, 25, 50, 75, 100 }), -- plus „toate”, adăugat de Domain/Collection
		milestoneBonus = 0.05,
		secretAt = 50, -- la 50 de intrări, Rețeta Secretă prinde viață (singura cale de a o avea)
		secretId = "RetetaSecreta",
	}),
	quests = table.freeze({
		perDay = 3,
		-- tipurile de treburi și ținta lor; toate se pot face și solo
		kinds = table.freeze({
			table.freeze({ kind = "plant", goal = 3 }),
			table.freeze({ kind = "hatch", goal = 3 }),
			table.freeze({ kind = "buySeed", goal = 3 }),
			table.freeze({ kind = "steal", goal = 1 }),
			table.freeze({ kind = "defend", goal = 1 }),
			table.freeze({ kind = "sell", goal = 2 }),
			table.freeze({ kind = "hora", goal = 1 }),
			table.freeze({ kind = "mutation", goal = 1 }),
		}),
		rewardSeconds = 90, -- recompensa = venitul pe secundă × asta
		minReward = 150,
		bonusSeeds = table.freeze({
			"GogoasaNinja",
			"CeapaTurbo",
			"StrugurelFurios",
			"PepeneBoxer",
			"SarmalinaBallerina",
		}),
	}),
	rebirth = table.freeze({
		baseCost = 1e6,
		growth = 4,
		maxLevel = 10,
		incomeBonus = 0.5, -- +50% venit permanent pe nivel
		giftSeed = "Mamaligator", -- o sămânță Epică la fiecare renaștere
	}),
})
