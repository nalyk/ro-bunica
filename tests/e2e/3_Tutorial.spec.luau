--!strict
-- Primul minut: hoțul scriptat, prins de proprietar (cu ajutor la ochit) sau de Bunica (plasa de siguranță).

local ServerScriptService = game:GetService("ServerScriptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Inventory = require(Shared.Domain.Inventory)
local ArtLibrary = require(Shared.Visual.ArtLibrary)

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local Actors = (require :: any)(ServerScriptService:WaitForChild("Server"):WaitForChild("Actors"))
	local PlotService = services.PlotService
	local CreatureService = services.CreatureService
	local SlipperService = services.SlipperService
	local TutorialService = services.TutorialService
	local DayNightService = services.DayNightService
	local BunicaService = services.BunicaService

	local function ownerWithCreature(index: number, name: string): (any, any)
		local plot = PlotService.plots[index]
		local bot = Actors.createBot(name, plot.geometry.spawnCFrame)
		local owner = PlotService.assignBot(plot, bot)
		local record = Inventory.newRecord(owner.profile, bot.id, "CartofelAgent", "Normal", nil)
		Inventory.place(owner.profile, record)
		CreatureService.render(owner)
		return bot, owner
	end

	DayNightService.forcePhase("Day") -- hoțul din tutorial vine ziua
	BunicaService.setEnabled(false)

	describe("Primul minut", function()
		it("proprietarul aruncă pe lângă, ajutorul la ochit îl duce în hoț", function()
			local owner, ownerState = ownerWithCreature(3, "NouBot")
			task.spawn(TutorialService.run, ownerState, 0)
			expect(Spec.waitFor(function()
				return TutorialService.isWaitingForThrow(ownerState)
			end, 40)).toBe(true)
			local thief = TutorialService.thiefOf(ownerState)
			local thiefRoot = Actors.root(thief) :: BasePart
			-- Hoțomanul sculptat: rig propriu cu picioare, pe sol. Mersul nu se vede aici (sesiunile Luau din
			-- Open Cloud nu rulează fizica; nici boții R15 nu se mișcă), îl verifică playtest-ul din Studio.
			if ArtLibrary.has("char.Hotoman") then
				local rig = Actors.characterOf(thief) :: Model
				expect(rig:GetAttribute("Sculpted")).toBe(true)
				expect(rig:GetAttribute("Walks")).toBe(true)
				for _, piece in { "Body", "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
					expect(rig:FindFirstChild(piece) ~= nil).toBe(true)
				end
				-- tălpile pe pământ: partea de jos a modelului la nivelul solului ogrăzii (±1 stud)
				local box, size = rig:GetBoundingBox()
				local ground = ownerState.plot.geometry.cframe.Position.Y
				expect(math.abs(box.Position.Y - size.Y / 2 - ground) < 1).toBe(true)
			end
			-- Proprietarul stă la 18 studs și ochește la 10 studs pe lângă hoț
			local character = Actors.characterOf(owner) :: Model
			character:PivotTo(CFrame.new(thiefRoot.Position + Vector3.new(18, 0, 0)))
			local sloppyAim = thiefRoot.Position + Vector3.new(0, 0, 10)
			expect(SlipperService.throwAs(owner, sloppyAim, "Slipper")).toBe(true)
			expect(Spec.waitFor(function()
				return ownerState.profile.tutorialThiefDone
			end, 6)).toBe(true)
			expect(TutorialService.isActive(ownerState)).toBe(false)
			-- Creatura e la locul ei, cu model vizibil
			local key = next(ownerState.profile.pedestals)
			expect(key ~= nil).toBe(true)
			expect(CreatureService.modelAt(ownerState, key) ~= nil).toBe(true)
			Actors.removeBot(owner)
		end)

		it("dacă proprietarul nu aruncă, Bunica îl prinde sigur", function()
			local owner, ownerState = ownerWithCreature(4, "PasivBot")
			task.spawn(TutorialService.run, ownerState, 0)
			expect(Spec.waitFor(function()
				return TutorialService.isWaitingForThrow(ownerState)
			end, 40)).toBe(true)
			expect(Spec.waitFor(function()
				return ownerState.profile.tutorialThiefDone
			end, 25)).toBe(true)
			Actors.removeBot(owner)
		end)
	end)

	DayNightService.forcePhase(nil)
end
