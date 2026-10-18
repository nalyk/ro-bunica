--!strict
-- Efecte sonore din librăria licențiată ProSoundEffects (folosibile în orice experiență).
-- Vocea reală a Bunicii vine separat, din Config/BunicaLines (soundId pe replică).

local function id(n: number): string
	return "rbxassetid://" .. n
end

return table.freeze({
	slipperHit = id(9114788747), -- Head Impact 2
	rollingPinHit = id(9120871396), -- Wood Drop Wood Log 3
	throwWhoosh = id(9120710054), -- Whoosh Fast Swish By 1
	thiefScream = id(9125905538), -- Scream Pass Bys Individuals Running Yelling
	bodyFall = id(9113482032), -- Body Fall Wrestling 1
	bunicaGiggle = id(9114398138), -- Females Giggle 2
	alarm = id(9113041590), -- Acme Whistle
	bunicaSneeze = id(9119304267), -- Sneeze Three Times 2
	dogBark = id(9114370187), -- Farm Animals Dog Barking Rooster Crows 1
})
