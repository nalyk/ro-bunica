local ChainAlarm = require(Shared.Domain.ChainAlarm)
local Codes = require(Shared.Domain.Codes)

local GATES = { Vector3.new(0, 0, 0), Vector3.new(40, 0, 0), Vector3.new(200, 0, 0) }

describe("ChainAlarm", function()
	it(
		"hoțul care cară trece pe lângă ogrăzi: latră doar cele din apropiere, nu ograda prădată",
		function()
			local state = ChainAlarm.new()
			local alarmed = ChainAlarm.update(state, "hot1", Vector3.new(30, 0, 5), GATES, 1, 100)
			expect(table.find(alarmed, 2) ~= nil).toBe(true)
			expect(table.find(alarmed, 1)).toBeNil() -- ograda prădată știe deja
			expect(table.find(alarmed, 3)).toBeNil()
		end
	)
	it("fiecare ogradă e anunțată o singură dată pentru același hoț, apoi după pauză", function()
		local state = ChainAlarm.new()
		ChainAlarm.update(state, "hot1", Vector3.new(40, 0, 5), GATES, 1, 100)
		expect(#ChainAlarm.update(state, "hot1", Vector3.new(41, 0, 5), GATES, 1, 101)).toBe(0)
		expect(
			#ChainAlarm.update(state, "hot1", Vector3.new(41, 0, 5), GATES, 1, 100 + ChainAlarm.COOLDOWN + 1)
		).toBe(1)
	end)
end)

describe("Codes", function()
	local CODES = {
		{ code = "BUNICA", reward = { lei = 500 }, expires = 2000 },
		{ code = "VECHI", reward = { lei = 100 }, expires = 1000 },
	}
	it("codul bun dă răsplata o singură dată; nu contează literele mari", function()
		local used = {}
		local ok, reward = Codes.redeem(CODES, used, "bunica", 1500)
		expect(ok).toBe(true)
		expect(reward.lei).toBe(500)
		local again, reason = Codes.redeem(CODES, used, "BUNICA", 1600)
		expect(again).toBe(false)
		expect(reason).toBe("Used")
	end)
	it("codul expirat și cel necunoscut sunt refuzate", function()
		local _, expired = Codes.redeem(CODES, {}, "VECHI", 1500)
		expect(expired).toBe("Expired")
		local _, unknown = Codes.redeem(CODES, {}, "NUEXISTA", 1500)
		expect(unknown).toBe("Unknown")
	end)
end)
