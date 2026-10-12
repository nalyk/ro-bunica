--!strict
-- Replicile Bunicii pe evenimente. Textul e în Strings (cheile de mai jos), scris de mână pe limbi.
-- `voice` leagă o replică de înregistrarea ei (soundId) când vocea reală e încărcată; până atunci, doar bula.

return table.freeze({
	events = table.freeze({
		Spot = { "bunica.spot.1", "bunica.spot.2", "bunica.spot.3" },
		Wake = { "bunica.wake.1", "bunica.wake.2", "bunica.wake.3" },
		Signature = { "bunica.signature" },
		Hit = { "bunica.hit.1", "bunica.hit.2", "bunica.hit.3", "bunica.hit.4" },
		Miss = { "bunica.miss.1", "bunica.miss.2", "bunica.miss.3" },
		Rage = { "bunica.rage.1", "bunica.rage.2" },
		Welcome = { "bunica.welcome.1", "bunica.welcome.2" },
		Dawn = { "bunica.dawn.1", "bunica.dawn.2" },
	}),
	voice = table.freeze({} :: { [string]: string }),
	minGapSeconds = 2.5, -- între două replici ale aceleiași Bunici (lovitura are prioritate)
	bubbleSeconds = 2.6,
	missChance = 0.5, -- nu comentează chiar fiecare ratare
	celebrateSeconds = 2,
})
