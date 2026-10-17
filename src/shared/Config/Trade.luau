--!strict
-- Schimburile între jucători: creaturi din beci (și lei), cu acceptare de ambele părți și numărătoare inversă.

return table.freeze({
	maxCreatures = 4, -- pe fiecare parte
	confirmSeconds = 3, -- după ce acceptă amândoi; orice schimbare de ofertă o oprește
	requestSeconds = 20, -- cât stă valabilă o cerere de schimb
	requestCooldown = 8, -- între două cereri ale aceluiași jucător
	excludedRarities = table.freeze({ Secret = true }), -- trofee: nu se schimbă
})
