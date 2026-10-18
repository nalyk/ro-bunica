local Minigame = require(Shared.Domain.Minigame)
local Minigames = require(Shared.Config.Minigames)
local Raid = require(Shared.Domain.Raid)

describe("Minigame", function()
	it("clasamentul: după scor; la egalitate, cine a ajuns primul", function()
		local ranking = Minigame.rank({ [1] = 5, [2] = 9, [3] = 5 }, { [1] = 20, [2] = 30, [3] = 10 })
		expect(ranking[1]).toBe(2)
		expect(ranking[2]).toBe(3)
		expect(ranking[3]).toBe(1)
	end)

	it("toți participanții primesc ceva, podiumul mai mult; cine a plecat nu primește nimic", function()
		local def = Minigames.byId.Cocos
		local ranking = { 10, 20, 30, 40 }
		local present = { [10] = true, [20] = true, [40] = true } -- 30 a plecat
		local rewards = Minigame.rewards(def, ranking, present)
		expect(rewards[10] > rewards[20]).toBe(true)
		expect(rewards[40] >= def.rewards.participation).toBe(true)
		expect(rewards[30]).toBeNil()
		-- 40 urcă pe locul 3 al celor rămași
		expect(rewards[40]).toBe(def.rewards.participation + def.rewards.placements[3])
	end)

	it("la jocurile pe echipe, toată echipa câștigătoare ia bonusul de câștig", function()
		local def = Minigames.byId.Oina
		expect(def.teams).toBe(true)
		local scores = { [1] = 3, [2] = 3, [3] = 1, [4] = 1 }
		local ranking = Minigame.rank(scores)
		local rewards =
			Minigame.rewards(def, ranking, { [1] = true, [2] = true, [3] = true, [4] = true }, scores)
		expect(rewards[1]).toBe(def.rewards.participation + def.rewards.placements[1])
		expect(rewards[2]).toBe(def.rewards.participation + def.rewards.placements[1])
		expect(rewards[3]).toBe(def.rewards.participation)
	end)

	it("fantomele încurajează: +5% pe încurajare, cel mult +25%", function()
		expect(Minigame.cheerMultiplier(0)).toBe(1)
		expect(math.abs(Minigame.cheerMultiplier(2) - 1.1) < 1e-9).toBe(true)
		expect(math.abs(Minigame.cheerMultiplier(20) - 1.25) < 1e-9).toBe(true)
	end)

	it(
		"configul: fiecare joc are un loc din sat, jucători valizi și răsplată pentru participare",
		function()
			local Village = require(Shared.Config.Village)
			for _, def in Minigames.list do
				expect(Village.sites[def.site] ~= nil).toBe(true)
				expect(def.minPlayers >= 1 and def.maxPlayers >= def.minPlayers).toBe(true)
				expect(def.rewards.participation > 0).toBe(true)
			end
		end
	)

	it("cine e într-un mini-joc nu poate fura („Busy”)", function()
		local ok, reason = Raid.canSteal({
			phase = "Night",
			isOwnPlot = false,
			ownerPresent = true,
			thiefCarrying = false,
			thiefStunned = false,
			ownerShieldUntil = 0,
			ownerPlaySeconds = 10000,
			ownerIsNpc = false,
			now = 100,
			distance = 3,
			creatureOnPedestal = true,
			inMinigame = true,
		})
		expect(ok).toBe(false)
		expect(reason).toBe("Busy")
	end)
	it("recordul: doar un scor mai mare decât cel vechi (primul scor e mereu record)", function()
		expect(Minigame.isRecord(nil, 1)).toBe(true)
		expect(Minigame.isRecord(5, 6)).toBe(true)
		expect(Minigame.isRecord(5, 5)).toBe(false)
		expect(Minigame.isRecord(5, 0)).toBe(false)
		expect(Minigame.isRecord(nil, 0)).toBe(false)
	end)
	it(
		"fără efort nu se plătește: participarea cere o acțiune, podiumul cere scor peste 0 și cel puțin doi jucători",
		function()
			local def = Minigames.byId.Sotron
			-- singur, cu scor 0, fără nicio acțiune: nimic
			local solo = Minigame.rewards(def, { 1 }, { [1] = true }, { [1] = 0 }, {})
			expect(solo[1] or 0).toBe(0)
			-- singur, a jucat: doar participarea (fără podium, nu are cu cine concura)
			local played = Minigame.rewards(def, { 1 }, { [1] = true }, { [1] = 3 }, { [1] = true })
			expect(played[1]).toBe(def.rewards.participation)
			-- doi: câștigătorul cu scor ia podiumul; cel cu scor 0 doar participarea, dacă a jucat
			local two = Minigame.rewards(
				def,
				{ 1, 2 },
				{ [1] = true, [2] = true },
				{ [1] = 5, [2] = 0 },
				{ [1] = true, [2] = true }
			)
			expect(two[1]).toBe(def.rewards.participation + def.rewards.placements[1])
			expect(two[2]).toBe(def.rewards.participation)
		end
	)
	it("plafonul pe oră: leii din mini-jocuri nu trec de Minigame.HOURLY_CAP", function()
		expect(Minigame.capped(0, 80)).toBe(80)
		expect(Minigame.capped(Minigame.HOURLY_CAP - 30, 80)).toBe(30)
		expect(Minigame.capped(Minigame.HOURLY_CAP, 80)).toBe(0)
	end)
	it("doi au intrat, unul a plecat: cel rămas a avut adversar, deci ia podiumul", function()
		local def = Minigames.byId.Sotron
		local rewards = Minigame.rewards(
			def,
			{ 1, 2 },
			{ [1] = true },
			{ [1] = 4, [2] = 1 },
			{ [1] = true, [2] = true }
		)
		expect(rewards[1]).toBe(def.rewards.participation + def.rewards.placements[1])
	end)
end)
