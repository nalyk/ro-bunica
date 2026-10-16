--!strict
-- GENERAT de tools/audio/atlas.py — nu edita de mână.
-- Atlasul audio: un singur asset cu regiuni numite (secunde).

export type Region = { start: number, length: number, loop: boolean?, bpm: number?, layer: string? }

return {
	assetId = 94705666578776,
	length = 176.926,
	-- fundamentala acordului pe fiecare măsură, în semitonuri față de Re
	harmony = { 0, 0, 2, 0, 0, 2, 0, 0, 0, 7, 2, 7, 0, 2, 0, 0 },
	regions = {
		["music.zi"] = { start = 0.0, length = 16.0, loop = true, bpm = 120, layer = "zi" },
		["music.noapte"] = { start = 16.35, length = 16.0, loop = true, bpm = 120, layer = "noapte" },
		["music.pericol"] = { start = 32.7, length = 16.0, loop = true, bpm = 120, layer = "pericol" },
		["music.urmarire"] = { start = 49.05, length = 16.0, loop = true, bpm = 120, layer = "urmarire" },
		["music.hora.120"] = { start = 65.4, length = 16.0, loop = true, bpm = 120, layer = "hora" },
		["music.hora.132"] = { start = 81.75, length = 14.5455, loop = true, bpm = 132, layer = "hora" },
		["music.hora.144"] = { start = 96.6455, length = 13.3333, loop = true, bpm = 144, layer = "hora" },
		["music.hora.156"] = { start = 110.3288, length = 12.3077, loop = true, bpm = 156, layer = "hora" },
		["sfx.pleosc"] = { start = 122.9865, length = 1.6, loop = false },
		["sfx.whoosh"] = { start = 124.9365, length = 0.45, loop = false },
		["sfx.miss"] = { start = 125.7365, length = 0.9, loop = false },
		["sfx.caught"] = { start = 126.9865, length = 1.8, loop = false },
		["sfx.coin"] = { start = 129.1365, length = 0.8, loop = false },
		["sfx.tap"] = { start = 130.2865, length = 0.12, loop = false },
		["sfx.confirm"] = { start = 130.7565, length = 0.9, loop = false },
		["sfx.error"] = { start = 132.0065, length = 0.6, loop = false },
		["sfx.open"] = { start = 132.9565, length = 1.0, loop = false },
		["sfx.close"] = { start = 134.3065, length = 1.0, loop = false },
		["sfx.reward1"] = { start = 135.6565, length = 3.0, loop = false },
		["sfx.reward2"] = { start = 139.0065, length = 3.0, loop = false },
		["sfx.reward3"] = { start = 142.3565, length = 3.0, loop = false },
		["sfx.harvest"] = { start = 145.7065, length = 0.7, loop = false },
		["sfx.plant"] = { start = 146.7565, length = 0.5, loop = false },
		["sfx.alarm"] = { start = 147.6065, length = 1.6, loop = false },
		["sfx.sneeze"] = { start = 149.5565, length = 1.5, loop = false },
		["sfx.clap"] = { start = 151.4065, length = 0.12, loop = false },
		["sfx.crickets"] = { start = 151.8765, length = 8.0, loop = true },
		["sfx.wind"] = { start = 160.2265, length = 8.0, loop = true },
		["sfx.rain"] = { start = 168.5765, length = 8.0, loop = true },
	} :: { [string]: Region },
}
