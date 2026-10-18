--!strict
-- Recomandările (LaunchService, Domain/Referral): jucătorul nou adus de cineva primește „Musafirul” după
-- 10 minute, cel care l-a adus „Gazda satului” (direct, dacă e pe server; altfel din DataStore la intrare).

local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Launch = require(Shared.Domain.Launch)

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local Actors = (require :: any)(ServerScriptService:WaitForChild("Server"):WaitForChild("Actors"))
	local PlotService = services.PlotService
	local LaunchService = services.LaunchService

	local function bot(name: string, index: number): (any, any)
		local actor = Actors.createBot(name, PlotService.plots[index].geometry.spawnCFrame)
		return actor, PlotService.assignBot(PlotService.plots[index], actor)
	end

	describe("Recomandările", function()
		it("musafirul nou primește titlul după 10 minute, gazda de pe server pe al ei", function()
			local hostBot, host = bot("Gazda", 6)
			local guestBot, guest = bot("Musafir", 7)
			guest.profile.playSeconds = 30
			-- id-urile boților sunt negative (Launch.decode le-ar respinge): datele se dau direct
			local data: Launch.Data = { kind = "yard", host = host.userId, referrer = host.userId }
			expect(LaunchService.linkReferral(guest, data)).toBe(true)
			expect(guest.profile.referredBy).toBe(host.userId)
			-- a doua legătură nu mai merge (o singură dată)
			expect(LaunchService.linkReferral(guest, data)).toBe(false)

			LaunchService.checkReferrals() -- prea devreme
			expect(guest.profile.stats.welcomed == nil).toBe(true)
			guest.profile.playSeconds = 700
			LaunchService.checkReferrals()
			expect(guest.profile.stats.welcomed).toBe(1)
			expect(guest.profile.referralRewarded).toBe(true)
			expect(host.profile.stats.referrals).toBe(1)
			LaunchService.checkReferrals() -- o singură dată
			expect(host.profile.stats.referrals).toBe(1)
			Actors.removeBot(hostBot)
			Actors.removeBot(guestBot)
		end)

		it("un jucător vechi nu poate fi „adus”; nici de el însuși", function()
			local oldBot, old = bot("Vechi", 6)
			old.profile.playSeconds = 5000
			expect(LaunchService.linkReferral(old, Launch.decode("k=yard;h=5;r=5"))).toBe(false)
			old.profile.playSeconds = 10
			expect(LaunchService.linkReferral(old, { kind = "yard", referrer = old.userId })).toBe(false)
			Actors.removeBot(oldBot)
		end)

		it("recompensele în așteptare (gazda nu era pe server) se iau la intrare", function()
			local hostBot, host = bot("GazdaPlecata", 6)
			local store = DataStoreService:GetDataStore("Referrals")
			store:SetAsync(tostring(host.userId), 2)
			LaunchService.claimPending(host)
			expect(host.profile.stats.referrals).toBe(2)
			expect(store:GetAsync(tostring(host.userId))).toBe(0)
			Actors.removeBot(hostBot)
		end)
	end)
end
