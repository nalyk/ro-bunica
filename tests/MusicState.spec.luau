local MusicState = require(Shared.Domain.MusicState)

local function input(overrides)
	local base = { phase = "Day", now = 100, alarmUntil = 0, chaseUntil = 0, dancing = false, dancers = 0 }
	for k, v in overrides or {} do
		base[k] = v
	end
	return base
end

describe("MusicState", function()
	it("ziua cântă stratul de zi, noaptea pe cel de noapte", function()
		local day = MusicState.mix(input())
		expect(day.zi).toBe(1)
		expect(day.noapte).toBe(0)
		local night = MusicState.mix(input({ phase = "Night" }))
		expect(night.noapte).toBe(1)
		expect(night.zi).toBe(0)
	end)
	it("hoțul în ogradă adaugă pericolul; urmărirea îl înlocuiește", function()
		local danger = MusicState.mix(input({ phase = "Night", alarmUntil = 120 }))
		expect(danger.pericol > 0).toBe(true)
		local chase = MusicState.mix(input({ phase = "Night", alarmUntil = 120, chaseUntil = 110 }))
		expect(chase.pericol).toBe(0)
		expect(chase.urmarire > 0).toBe(true)
	end)
	it("alarma expirată nu mai cântă", function()
		expect(MusicState.mix(input({ alarmUntil = 99 })).pericol).toBe(0)
	end)
	it("hora oprește restul și accelerează cu dansatorii", function()
		local mix, tempo = MusicState.mix(input({ dancing = true, dancers = 1 }))
		expect(mix.zi).toBe(0)
		expect(tempo).toBe(120)
		local _, faster = MusicState.mix(input({ dancing = true, dancers = 3 }))
		expect(faster).toBe(144)
		local _, capped = MusicState.mix(input({ dancing = true, dancers = 9 }))
		expect(capped).toBe(156)
	end)
end)
