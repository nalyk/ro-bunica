local LinePicker = require(Shared.Domain.LinePicker)
local BunicaLines = require(Shared.Config.BunicaLines)
local Strings = require(Shared.Strings)
local RandomUtil = require(Shared.Domain.Random)

describe("LinePicker", function()
	it("nu repetă ultima replică", function()
		local rng = RandomUtil.seeded(3)
		local last = nil
		for _ = 1, 200 do
			local line = LinePicker.pick({ "a", "b", "c" }, last, rng)
			expect(line ~= last).toBe(true)
			last = line
		end
	end)
	it("cu o singură replică o repetă", function()
		expect(LinePicker.pick({ "a" }, "a", math.random)).toBe("a")
	end)
	it("listă goală întoarce nil", function()
		expect(LinePicker.pick({}, nil, math.random)).toBeNil()
	end)
	it("fiecare replică a Bunicii are text în ro și en", function()
		for _, lines in BunicaLines.events do
			for _, key in lines do
				expect(Strings.has("ro", key)).toBe(true)
				expect(Strings.has("en", key)).toBe(true)
			end
		end
	end)
	it("fiecare replică are voce în limba de rezervă, cu id și durată", function()
		local voices = BunicaLines.voice[BunicaLines.voiceFallback]
		for _, lines in BunicaLines.events do
			for _, key in lines do
				local voice = voices[key]
				expect(voice ~= nil).toBe(true)
				expect(string.match(voice.id, "^rbxassetid://%d+$") ~= nil).toBe(true)
				expect(voice.seconds > 0.5 and voice.seconds < 8).toBe(true)
			end
		end
	end)
end)
