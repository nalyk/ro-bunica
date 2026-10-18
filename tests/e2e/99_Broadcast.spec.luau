--!strict
-- Satul pe toate serverele (BroadcastService): ce vine din topicul „Sat” se acceptă doar dacă e un anunț
-- din lista albă sau un eveniment live cunoscut; mesajele proprii și cele străine se ignoră.

local HttpService = game:GetService("HttpService")

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local BroadcastService = services.BroadcastService
	local LiveEventService = services.LiveEventService

	local function encode(message: { [string]: any }): string
		return HttpService:JSONEncode(message)
	end

	describe("Satul pe toate serverele", function()
		it("anunțurile permise trec, celelalte nu", function()
			expect(
				BroadcastService.receive(encode({ k = "announce.SecretRecipe", a = { "Ion" }, j = "alt" }))
			).toBe("announced")
			expect(BroadcastService.receive(encode({ k = "announce.Steal", a = {}, j = "alt" }))).toBe(
				"ignored"
			)
			expect(BroadcastService.receive(encode({ k = "announce.Admin", a = { "x" }, j = game.JobId }))).toBe(
				"ignored"
			)
			expect(BroadcastService.receive("nu e json")).toBe("ignored")
			expect(BroadcastService.receive(42)).toBe("ignored")
		end)

		it("comanda de admin pornește un eveniment live cunoscut, pe durata cerută (în limite)", function()
			expect(BroadcastService.receive(encode({ live = "Inexistent", j = "admin" }))).toBe("ignored")
			expect(BroadcastService.receive(encode({ live = "BunicaSeSupara", s = 120, j = "admin" }))).toBe(
				"live"
			)
			expect(LiveEventService.current()).toBe("BunicaSeSupara")
			LiveEventService.stop()
		end)
	end)
end
