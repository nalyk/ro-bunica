local Tuning = require(Shared.Domain.Tuning)

local function fakeConfigs()
	return {
		Defense = { slipper = { maxAmmo = 3, regenSeconds = 2.5 }, bunicaNpc = { throwIntervalSeconds = 3 } },
		Raid = { victimShieldSeconds = 60, maxStealsPerVictimPerNight = 2 },
	}
end

describe("Tuning", function()
	it("fiecare cheie are cale, minim și maxim, iar valoarea implicită din config e în limite", function()
		local real = {
			Defense = require(Shared.Config.Defense),
			Raid = require(Shared.Config.Raid),
			DayNight = require(Shared.Config.DayNight),
			Economy = require(Shared.Config.Economy),
		}
		for key, spec in Tuning.SPEC do
			expect(spec.min < spec.max).toBe(true)
			expect(string.match(key, "^[%a_]+$") ~= nil).toBe(true)
			local node: any = real
			for _, part in string.split(spec.path, ".") do
				node = node[part]
			end
			expect(type(node)).toBe("number")
			expect(node >= spec.min and node <= spec.max).toBe(true)
		end
	end)

	it("tabelele reglabile nu sunt înghețate (altfel valorile live nu s-ar putea scrie)", function()
		expect(table.isfrozen(require(Shared.Config.Raid))).toBe(false)
		expect(table.isfrozen(require(Shared.Config.DayNight))).toBe(false)
		expect(table.isfrozen(require(Shared.Config.Economy))).toBe(false)
		expect(table.isfrozen(require(Shared.Config.Defense).slipper)).toBe(false)
		expect(table.isfrozen(require(Shared.Config.Defense).bunicaNpc)).toBe(false)
	end)

	it("validează: tip, limite, întregi; cheile necunoscute sunt respinse", function()
		local ok, rejected = Tuning.validate({
			raid_victimShieldSeconds = 90,
			raid_maxStealsPerVictimPerNight = 2.5,
			slipper_maxAmmo = 99,
			bunica_throwIntervalSeconds = "rapid",
			hack_lei = 1000000,
		})
		expect(ok.raid_victimShieldSeconds).toBe(90)
		expect(ok.raid_maxStealsPerVictimPerNight).toBe(nil)
		expect(ok.slipper_maxAmmo).toBe(nil)
		expect(ok.bunica_throwIntervalSeconds).toBe(nil)
		expect(ok.hack_lei).toBe(nil)
		expect(#rejected).toBe(4)
	end)

	it("aplică doar valorile de server, în tabelele config, pe calea dată", function()
		local configs = fakeConfigs()
		Tuning.apply(configs, { raid_victimShieldSeconds = 90, bunica_throwIntervalSeconds = 4 })
		expect(configs.Raid.victimShieldSeconds).toBe(90)
		expect(configs.Defense.bunicaNpc.throwIntervalSeconds).toBe(4)
	end)

	it("valorile pe jucător nu ating config-ul comun", function()
		local configs = fakeConfigs()
		Tuning.apply(configs, { slipper_maxAmmo = 4 })
		expect(configs.Defense.slipper.maxAmmo).toBe(3)
		expect(Tuning.SPEC.slipper_maxAmmo.scope).toBe("player")
	end)

	it("pe jucător: valoarea validată sau cea implicită", function()
		expect(Tuning.playerValue({ slipper_maxAmmo = 4 }, "slipper_maxAmmo", 3)).toBe(4)
		expect(Tuning.playerValue({}, "slipper_maxAmmo", 3)).toBe(3)
		expect(Tuning.playerValue({ slipper_maxAmmo = 40 }, "slipper_maxAmmo", 3)).toBe(3)
	end)
end)
