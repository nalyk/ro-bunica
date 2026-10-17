--!strict
-- Replicile Bunicii pe evenimente. Textul e în Strings (cheile de mai jos), scris de mână pe limbi.
-- `voice` leagă o replică de înregistrarea ei (soundId și durata, pentru cât stă bula).

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
	-- Înregistrările pe limbi (docs/VOICE.md: Gemini TTS, vocea B, art/voice/<limbă>/). O limbă fără voce
	-- folosește vocea în română: Bunica e din satul moldovenesc, bula arată traducerea.
	voice = table.freeze({
		ro = table.freeze({
			["bunica.dawn.1"] = { id = "rbxassetid://110087448395287", seconds = 3.1 },
			["bunica.dawn.2"] = { id = "rbxassetid://84986867345118", seconds = 3.1 },
			["bunica.hit.1"] = { id = "rbxassetid://126075345289011", seconds = 1.4 },
			["bunica.hit.2"] = { id = "rbxassetid://73291360002563", seconds = 2.2 },
			["bunica.hit.3"] = { id = "rbxassetid://79223567313327", seconds = 3.5 },
			["bunica.hit.4"] = { id = "rbxassetid://107743842304611", seconds = 3.6 },
			["bunica.miss.1"] = { id = "rbxassetid://76129220158529", seconds = 3.2 },
			["bunica.miss.2"] = { id = "rbxassetid://131747788692650", seconds = 3.6 },
			["bunica.miss.3"] = { id = "rbxassetid://113773309876737", seconds = 3.9 },
			["bunica.rage.1"] = { id = "rbxassetid://96152237591238", seconds = 1.8 },
			["bunica.rage.2"] = { id = "rbxassetid://117594628928601", seconds = 2.0 },
			["bunica.signature"] = { id = "rbxassetid://140480987250545", seconds = 2.6 },
			["bunica.spot.1"] = { id = "rbxassetid://77941079972466", seconds = 1.5 },
			["bunica.spot.2"] = { id = "rbxassetid://89040664971073", seconds = 3.1 },
			["bunica.spot.3"] = { id = "rbxassetid://101937422386277", seconds = 3.3 },
			["bunica.wake.1"] = { id = "rbxassetid://83431844904000", seconds = 1.0 },
			["bunica.wake.2"] = { id = "rbxassetid://108889674397605", seconds = 1.8 },
			["bunica.wake.3"] = { id = "rbxassetid://121150572976201", seconds = 1.6 },
			["bunica.welcome.1"] = { id = "rbxassetid://95417816027883", seconds = 5.1 },
			["bunica.welcome.2"] = { id = "rbxassetid://124402347849380", seconds = 3.4 },
		} :: { [string]: { id: string, seconds: number } }),
	} :: { [string]: { [string]: { id: string, seconds: number } } }),
	voiceFallback = "ro",
	voiceVolume = 1.1,
	minGapSeconds = 2.5, -- între două replici ale aceleiași Bunici (lovitura are prioritate)
	bubbleSeconds = 2.6,
	missChance = 0.5, -- nu comentează chiar fiecare ratare
	celebrateSeconds = 2,
})
