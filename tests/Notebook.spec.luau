local Collection = require(Shared.Domain.Collection)
local Quests = require(Shared.Domain.Quests)
local Rebirth = require(Shared.Domain.Rebirth)
local Creatures = require(Shared.Config.Creatures)
local Mutations = require(Shared.Config.Mutations)

describe("Collection", function()
	it("are o intrare pentru fiecare creatură, cu și fără fiecare mutație", function()
		expect(Collection.TOTAL).toBe(#Creatures.list * (1 + #Mutations.list))
		expect(Collection.milestones()[#Collection.milestones()]).toBe(Collection.TOTAL)
	end)
	it("prima descoperire dă lei, a doua nimic", function()
		local profile = { collection = {} }
		local first = Collection.discover(profile, { id = "CartofelAgent", size = "Huge" })
		expect(first ~= nil).toBe(true)
		expect((first :: any).key).toBe("CartofelAgent")
		expect((first :: any).lei).toBe(50) -- minimul (1 leu/s × 30 × 0,5 = 15)
		expect(Collection.discover(profile, { id = "CartofelAgent", size = "Small" })).toBeNil()
		local golden =
			Collection.discover(profile, { id = "PepeneBoxer", size = "Normal", mutation = "Golden" })
		expect((golden :: any).key).toBe("PepeneBoxer:Golden")
		expect((golden :: any).lei).toBe(60 * 30 * 10 / 2)
	end)
	it("pragurile dau venit, iar la 50 de intrări vine Rețeta Secretă", function()
		local profile = { collection = {} }
		local entries = Collection.entries()
		local milestones, secrets = 0, 0
		for index = 1, 50 do
			local id, mutation = string.match(entries[index], "^([^:]+):?(.*)$")
			local found = Collection.discover(
				profile,
				{ id = id :: string, size = "Normal", mutation = if mutation ~= "" then mutation else nil }
			) :: any
			if found.milestone then
				milestones += 1
			end
			if found.secret then
				secrets += 1
			end
		end
		expect(milestones).toBe(3) -- 10, 25, 50
		expect(secrets).toBe(1)
		expect(Collection.multiplier(profile)).toBe(1.15)
	end)
end)

describe("Quests", function()
	it("3 treburi diferite pe zi, aceleași pentru aceeași zi și jucător", function()
		local a = Quests.forDay(20000, 1741390820)
		local b = Quests.forDay(20000, 1741390820)
		expect(#a).toBe(3)
		expect(a[1].kind).toBe(b[1].kind)
		expect(a[1].kind ~= a[2].kind and a[2].kind ~= a[3].kind and a[1].kind ~= a[3].kind).toBe(true)
	end)
	it("progres, recompensă o singură dată, apoi bonusul pentru toate", function()
		local profile = { quests = { day = -1, list = {}, bonusClaimed = false }, seeds = {} }
		expect(Quests.ensure(profile, 20000, 5)).toBe(true)
		expect(Quests.ensure(profile, 20000, 5)).toBe(false)
		expect(Quests.claim(profile, 1, 10)).toBeNil()
		for _, quest in profile.quests.list do
			local done = Quests.record(profile, quest.kind, quest.goal)
			expect(#done >= 1).toBe(true)
		end
		expect(Quests.claimBonus(profile)).toBeNil() -- încă nerevendicate
		expect(Quests.claim(profile, 1, 10)).toBe(900)
		expect(Quests.claim(profile, 1, 10)).toBeNil()
		expect(Quests.claim(profile, 2, 0)).toBe(150)
		expect(Quests.claim(profile, 3, 0)).toBe(150)
		local seed = Quests.claimBonus(profile)
		expect(seed ~= nil).toBe(true)
		expect(profile.seeds[seed :: string]).toBe(1)
		expect(Quests.claimBonus(profile)).toBeNil()
		expect(Quests.ensure(profile, 20001, 5)).toBe(true)
		expect(profile.quests.bonusClaimed).toBe(false)
	end)
end)

describe("Rebirth", function()
	local function profile(lei: number)
		return {
			lei = lei,
			rebirths = 0,
			seeds = { CartofelAgent = 3 },
			beds = { ["1"] = { seedId = "CartofelAgent" } },
			pedestals = {
				["1"] = { uid = "a", id = "CartofelAgent", size = "Normal" },
				["2"] = { uid = "b", id = "PepeneBoxer", size = "Normal", mutation = "Wet" },
			},
			cellar = { { uid = "c", id = "BranzoiSumo", size = "Small" } },
		}
	end
	it("prețul crește de 4 ori pe nivel și se oprește la 10", function()
		expect(Rebirth.cost(0)).toBe(1e6)
		expect(Rebirth.cost(1)).toBe(4e6)
		expect(Rebirth.cost(10)).toBeNil()
		expect(Rebirth.multiplier(2)).toBe(2)
	end)
	it("fără destui lei nu se poate", function()
		local p = profile(999999)
		expect((Rebirth.apply(p))).toBe(false)
		expect(p.rebirths).toBe(0)
	end)
	it("resetează tot, păstrează creatura de suflet și dă sămânța Epică", function()
		local p = profile(2e6)
		local ok, kept = Rebirth.apply(p)
		expect(ok).toBe(true)
		expect((kept :: any).uid).toBe("c") -- Brânzoi mic (240/s) bate Pepenele ud (120/s)
		expect(p.rebirths).toBe(1)
		expect(p.lei).toBe(60)
		expect(p.pedestals["1"].uid).toBe("c")
		expect(p.pedestals["2"]).toBeNil()
		expect(#p.cellar).toBe(0)
		expect(next(p.beds)).toBeNil()
		expect(p.seeds.CartofelAgent).toBeNil()
		expect(p.seeds.Mamaligator).toBe(1)
	end)
end)
