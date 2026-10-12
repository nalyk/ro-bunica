-- Validează coerența datelor: orice greșeală de config pică aici, nu în joc.
local Config = Shared.Config
local Creatures = require(Config.Creatures)
local Rarities = require(Config.Rarities)
local Mutations = require(Config.Mutations)
local Sizes = require(Config.Sizes)
local Weather = require(Config.Weather)
local Economy = require(Config.Economy)
local World = require(Config.World)
local DataTemplate = require(Config.DataTemplate)

describe("Config", function()
	it("fiecare creatură are o raritate validă și valori pozitive", function()
		for _, creature in Creatures.list do
			expect(Rarities.byId[creature.rarity] ~= nil).toBeTruthy()
			expect(creature.income).toBeGreaterThan(0)
			expect(creature.growSeconds).toBeGreaterThan(0)
			expect(creature.look.body ~= nil).toBeTruthy()
		end
	end)

	it("id-urile creaturilor sunt unice", function()
		local seen = {}
		for _, creature in Creatures.list do
			expect(seen[creature.id]).toBeNil()
			seen[creature.id] = true
		end
	end)

	it("sămânța de start există și se vinde", function()
		local starter = Creatures.byId[Creatures.starterSeed]
		expect(starter ~= nil).toBeTruthy()
		expect(starter.seedPrice ~= nil).toBeTruthy()
	end)

	it("prețul semințelor nu scade cu raritatea", function()
		local maxPriceByOrder = {}
		for _, creature in Creatures.list do
			if creature.seedPrice then
				local order = Rarities.byId[creature.rarity].order
				maxPriceByOrder[order] = math.max(maxPriceByOrder[order] or 0, creature.seedPrice)
			end
		end
		for _, creature in Creatures.list do
			if creature.seedPrice then
				local order = Rarities.byId[creature.rarity].order
				local previousMax = maxPriceByOrder[order - 1]
				if previousMax then
					expect(creature.seedPrice).toBeGreaterThan(previousMax - 1)
				end
			end
		end
	end)

	it("fiecare raritate care se vinde are stoc definit", function()
		for _, creature in Creatures.list do
			if creature.seedPrice then
				expect(Economy.shop.stockPerRarity[creature.rarity] ~= nil).toBeTruthy()
			end
		end
	end)

	it("vremea folosește mutații existente", function()
		for _, event in Weather.list do
			expect(Mutations.byId[event.mutation] ~= nil).toBeTruthy()
		end
	end)

	it("rangurile și multiplicatorii mutațiilor cresc împreună", function()
		for index = 2, #Mutations.list do
			expect(Mutations.list[index].rank).toBeGreaterThan(Mutations.list[index - 1].rank)
			expect(Mutations.list[index].multiplier).toBeGreaterThan(Mutations.list[index - 1].multiplier)
		end
	end)

	it("mărimea implicită există", function()
		expect(Sizes.byId[Sizes.default] ~= nil).toBeTruthy()
	end)

	it("grilele lumii încap maximul de straturi și piedestale", function()
		expect(World.bedGrid.columns * World.bedGrid.rows >= Economy.maxBeds).toBeTruthy()
		expect(World.pedestalGrid.columns * World.pedestalGrid.rows >= Economy.maxPedestals).toBeTruthy()
	end)

	it("șablonul de profil pornește din valorile de economie", function()
		local profile = DataTemplate.new()
		expect(profile.lei).toBe(Economy.startingLei)
		expect(profile.bedCount).toBe(Economy.startingBeds)
		expect(profile.pedestalCount).toBe(Economy.startingPedestals)
	end)
end)
