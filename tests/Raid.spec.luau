local Raid = require(Shared.Domain.Raid)

local function context(overrides)
	local ctx = {
		phase = "Night",
		isOwnPlot = false,
		ownerPresent = true,
		thiefCarrying = false,
		thiefStunned = false,
		ownerShieldUntil = 0,
		ownerPlaySeconds = 99999,
		ownerIsNpc = false,
		now = 1000,
		distance = 3,
		creatureOnPedestal = true,
	}
	for key, value in overrides do
		ctx[key] = value
	end
	return ctx
end

describe("Raid.canSteal", function()
	it("permite un furt valid", function()
		expect(Raid.canSteal(context({}))).toBe(true)
	end)

	local cases = {
		{ "NotNight", { phase = "Day" } },
		{ "OwnPlot", { isOwnPlot = true } },
		{ "AlreadyCarrying", { thiefCarrying = true } },
		{ "Stunned", { thiefStunned = true } },
		{ "NotDisplayed", { creatureOnPedestal = false } },
		{ "TooFar", { distance = 50 } },
		{ "Shielded", { ownerShieldUntil = 1030 } },
		{ "NewPlayer", { ownerPlaySeconds = 60 } },
	}
	for _, case in cases do
		it("refuză: " .. case[1], function()
			local ok, reason = Raid.canSteal(context(case[2]))
			expect(ok).toBe(false)
			expect(reason).toBe(case[1])
		end)
	end

	it("vecinii NPC nu au scut și nici protecție de jucător nou", function()
		expect(Raid.canSteal(context({ ownerIsNpc = true, ownerPlaySeconds = 0, ownerShieldUntil = 99999 }))).toBe(
			true
		)
	end)
end)

describe("Raid mișcare", function()
	it("acceptă mers normal și cădere", function()
		expect(Raid.isMovementPlausible(Vector3.new(0, 0, 0), Vector3.new(1.5, -30, 0), 0.1, 12, 1.6)).toBe(
			true
		)
	end)
	it("respinge teleportul", function()
		expect(Raid.isMovementPlausible(Vector3.new(0, 0, 0), Vector3.new(60, 0, 0), 0.1, 12, 1.6)).toBe(
			false
		)
	end)
	it("raritățile mari se cară mai încet", function()
		expect(Raid.carrySpeedMultiplier("Legendary")).toBeLessThan(Raid.carrySpeedMultiplier("Common"))
		expect(Raid.holdSeconds("Mythic")).toBeGreaterThan(Raid.holdSeconds("Common"))
	end)
end)
