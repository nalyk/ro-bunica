--!strict
-- Papucul, făcălețul, Furia Bunicii și Bunica NPC.

return table.freeze({
	slipper = table.freeze({
		maxAmmo = 3,
		regenSeconds = 2.5,
		speed = 90, -- studs/s
		gravity = 40, -- coborâre ușoară, traiectorie vizibilă
		hitRadius = 2.5,
		maxRange = 120,
		maxLifetime = 2,
		stunSeconds = 1.2,
		knockbackSpeed = 70,
	}),
	rollingPin = table.freeze({
		cost = 50, -- Nervi
		speed = 75,
		gravity = 50,
		hitRadius = 8, -- lovește în zonă
		maxRange = 100,
		maxLifetime = 2,
		stunSeconds = 2,
		knockbackSpeed = 110,
	}),
	rage = table.freeze({
		cost = 100,
		durationSeconds = 8,
		bunicaSpeed = 26,
		hitRadius = 4,
		stunSeconds = 2,
		knockbackSpeed = 120,
	}),
	nervi = table.freeze({
		max = 100,
		perHit = 25,
	}),
	bunicaNpc = table.freeze({
		sightRange = 35,
		suspicionPerSecond = 0.35, -- de la 0 la 1
		suspicionDecayPerSecond = 0.2,
		windupSeconds = 0.6, -- avertismentul vizibil înainte de aruncare
		throwIntervalSeconds = 3,
		throwSpeed = 45, -- lent: se poate evita
		aimErrorStuds = 3,
		ownerNearbyRange = 40, -- dacă proprietarul e aproape, Bunica doar reacționează
	}),
	-- Toleranța pentru verificarea de viteză pe server (hoț care cară o creatură)
	speedCheckTolerance = 1.6,
})
