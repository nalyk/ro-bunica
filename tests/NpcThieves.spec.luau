local NpcThieves = require(Shared.Domain.NpcThieves)

describe("NpcThieves", function()
	it("mai mulți hoți când serverul e gol, niciunul pe un server plin", function()
		expect(NpcThieves.attempts(0)).toBe(0)
		expect(NpcThieves.attempts(1)).toBe(3)
		expect(NpcThieves.attempts(2)).toBe(2)
		expect(NpcThieves.attempts(5)).toBe(1)
		expect(NpcThieves.attempts(6)).toBe(0)
		expect(NpcThieves.attempts(8)).toBe(0)
	end)
	it("cine e AFK nu e țintă", function()
		expect(NpcThieves.isActive(nil, 100)).toBe(false)
		expect(NpcThieves.isActive(50, 100)).toBe(true)
		expect(NpcThieves.isActive(5, 100)).toBe(false)
	end)
	it("ia cea mai valoroasă creatură până la Epic, nu Legendare și nu ce e cărat", function()
		local pedestals = {
			["1"] = { uid = "a", id = "CartofelAgent", size = "Normal" },
			["2"] = { uid = "b", id = "PepeneBoxer", size = "Normal" },
			["3"] = { uid = "c", id = "BranzoiSumo", size = "Huge" },
			["4"] = { uid = "d", id = "Mamaligator", size = "Normal" },
		}
		local function none(_uid: string): boolean
			return false
		end
		expect(NpcThieves.pickTarget(pedestals, none)).toBe("4")
		expect(NpcThieves.pickTarget(pedestals, function(uid)
			return uid == "d"
		end)).toBe("2")
		expect(NpcThieves.pickTarget({ ["1"] = { uid = "x", id = "DovleacDJ", size = "Normal" } }, none)).toBeNil()
	end)
	it("pauzele rămân în interval", function()
		expect(NpcThieves.delay({ 20, 40 }, function()
			return 0
		end)).toBe(20)
		expect(NpcThieves.delay({ 20, 40 }, function()
			return 1
		end)).toBe(40)
	end)
end)
