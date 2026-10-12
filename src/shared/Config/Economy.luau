--!strict
-- Economia de bază (lei).

return table.freeze({
	startingLei = 60,
	incomeTickSeconds = 1,
	sellMultiplier = 30, -- prețul de vânzare = valoare pe secundă × asta
	offlineRate = 0.1,
	offlineCapSeconds = 8 * 3600,
	friendBoostPerFriend = 0.1,
	friendBoostMax = 0.5,

	startingBeds = 4,
	maxBeds = 10,
	startingPedestals = 6,
	maxPedestals = 20,
	startingCellar = 30,

	shop = table.freeze({
		restockSeconds = 300,
		-- câte semințe din fiecare raritate intră în stoc când raritatea „iese” la reînnoire
		stockPerRarity = table.freeze({
			Common = 8,
			Rare = 4,
			Epic = 2,
			Legendary = 1,
			Mythic = 1,
		}),
	}),
})
