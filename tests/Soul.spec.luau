local Soul = require(Shared.Domain.Soul)
local Raid = require(Shared.Domain.Raid)
local NpcThieves = require(Shared.Domain.NpcThieves)
local Trade = require(Shared.Domain.Trade)

local function profile()
	return {
		lei = 1000,
		cellarCapacity = 30,
		pedestals = {
			["1"] = { uid = "a", id = "Mamaligator", size = "Normal" },
			["2"] = { uid = "b", id = "CartofelAgent", size = "Normal" },
		},
		cellar = {
			{ uid = "c", id = "CeapaTurbo", size = "Normal" },
			{ uid = "d", id = "PepeneBoxer", size = "Normal" },
		},
	}
end

describe("Soul", function()
	it("cel mult 3 creaturi de suflet; a patra e refuzată", function()
		local p = profile()
		expect(Soul.set(p, "a", true)).toBe(true)
		expect(Soul.set(p, "b", true)).toBe(true)
		expect(Soul.set(p, "c", true)).toBe(true)
		expect(Soul.count(p)).toBe(3)
		expect(select(2, Soul.canSet(p, "d", true))).toBe("Max")
		expect(Soul.set(p, "d", true)).toBe(false)
	end)
	it("scoaterea inimii eliberează locul; o creatură inexistentă e refuzată", function()
		local p = profile()
		Soul.set(p, "a", true)
		Soul.set(p, "b", true)
		Soul.set(p, "c", true)
		expect(Soul.set(p, "a", false)).toBe(true)
		expect(Soul.set(p, "d", true)).toBe(true)
		expect(select(2, Soul.canSet(p, "zz", true))).toBe("Missing")
	end)
	it("furtul unei creaturi de suflet e refuzat", function()
		local ok, reason = Raid.canSteal({
			phase = "Night",
			isOwnPlot = false,
			ownerPresent = true,
			thiefCarrying = false,
			thiefStunned = false,
			ownerShieldUntil = 0,
			ownerPlaySeconds = 99999,
			ownerIsNpc = false,
			now = 100,
			distance = 3,
			creatureOnPedestal = true,
			creatureIsSoul = true,
		})
		expect(ok).toBe(false)
		expect(reason).toBe("Soul")
	end)
	it("hoții vecini sar peste creaturile de suflet", function()
		local p = profile()
		Soul.set(p, "a", true)
		expect(NpcThieves.pickTarget(p.pedestals, function()
			return false
		end)).toBe("2")
	end)
	it("creaturile de suflet nu se schimbă", function()
		local p = profile()
		Soul.set(p, "c", true)
		expect(select(2, Trade.checkOffer(p, { "c" }, 0))).toBe("Soul")
	end)
end)
