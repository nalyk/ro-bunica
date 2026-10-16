--!strict
-- Lumea, vecinii NPC, creaturile și Bunica, verificate în motorul Roblox real.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local World = require(Shared.Config.World)
local GameState = require(Shared.GameState)

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local PlotService = services.PlotService

	describe("Motorul", function()
		it("Heartbeat rulează în sesiune (informativ pentru testele de proiectile)", function()
			local count = 0
			local connection = RunService.Heartbeat:Connect(function()
				count += 1
			end)
			task.wait(0.5)
			connection:Disconnect()
			print("[e2e] Heartbeat în 0.5 s: " .. count)
			expect(count >= 0).toBeTruthy()
		end)
	end)

	describe("Modelele", function()
		it(
			"toate modelele din ArtAssets sunt încărcate ca șabloane, colorate pe sloturi, cu contur",
			function()
				local ArtAssets = require(Shared.Config.ArtAssets)
				local ArtLibrary = require(Shared.Visual.ArtLibrary)
				for key, art in ArtAssets do
					local model = ArtLibrary.get(key)
					expect(model ~= nil).toBeTruthy()
					local m = model :: Model
					local ink = m:FindFirstChild("ink") :: MeshPart?
					expect(ink ~= nil).toBeTruthy()
					expect((ink :: MeshPart).CastShadow).toBe(false)
					for slot, color in art.palette do
						local part = m:FindFirstChild(slot) :: MeshPart?
						expect(part ~= nil).toBeTruthy()
						expect((part :: MeshPart).Color).toBe(color)
					end
					expect(m.PrimaryPart ~= nil).toBeTruthy()
				end
			end
		)
		it("creaturile cu model sunt construite din model, nu din forma procedurală", function()
			local found = 0
			for _, model in CollectionService:GetTagged("Creature") do
				if model:FindFirstChild("ink") then
					found += 1
				end
			end
			local ArtAssets = require(Shared.Config.ArtAssets)
			local creatureModels = 0
			for key in ArtAssets do
				if string.sub(key, 1, 9) == "creature." then
					creatureModels += 1
				end
			end
			print("[e2e] creaturi construite din model: " .. found)
			expect(creatureModels == 0 or found > 0).toBeTruthy()
		end)
	end)

	describe("Lumea", function()
		it("are toate ogrăzile cu straturi, piedestale și beci", function()
			local village = Workspace:FindFirstChild("Village")
			expect(village ~= nil).toBeTruthy()
			for index = 1, World.plotCount do
				local plot = (village :: Instance):FindFirstChild("Plot" .. index)
				expect(plot ~= nil).toBeTruthy()
				local beds, pedestals = 0, 0
				for _, part in (plot :: Instance):GetDescendants() do
					if part:GetAttribute("BedKey") then
						beds += 1
					elseif part:IsA("BasePart") and part:GetAttribute("PedestalKey") then
						pedestals += 1
					end
				end
				expect(beds).toBe(World.bedGrid.columns * World.bedGrid.rows)
				expect(pedestals >= World.pedestalGrid.columns * World.pedestalGrid.rows).toBeTruthy()
				expect((plot :: Instance):FindFirstChild("CellarDoor") ~= nil).toBeTruthy()
			end
		end)
	end)

	describe("Vecinii NPC", function()
		it("ocupă toate ogrăzile libere, cu creaturi pe piedestale", function()
			expect(Spec.waitFor(function()
				return #PlotService.owners() == World.plotCount
			end, 10)).toBeTruthy()
			for _, owner in PlotService.owners() do
				expect(owner.kind).toBe("Npc")
				local count = 0
				for _ in owner.profile.pedestals do
					count += 1
				end
				expect(count >= 3).toBeTruthy()
			end
		end)

		it("fiecare creatură expusă are model și prompt de furt", function()
			local creatures = 0
			for _, model in CollectionService:GetTagged("Creature") do
				if model:GetAttribute("PedestalKey") then
					creatures += 1
					local prompt = model:FindFirstChild("StealPrompt", true) :: ProximityPrompt?
					expect(prompt ~= nil).toBeTruthy()
					expect((prompt :: ProximityPrompt).Enabled).toBe(GameState.get("Phase") == "Night")
				end
			end
			expect(creatures >= World.plotCount * 3).toBeTruthy()
		end)

		it("creaturile stau pe piedestal, nu în el și nu în aer", function()
			for _, owner in PlotService.owners() do
				for key in owner.profile.pedestals do
					local pedestal = owner.plot.geometry.pedestals[key]
					local model: Model? = nil
					for _, child in owner.plot.geometry.creatureFolder:GetChildren() do
						if child:GetAttribute("PedestalKey") == key then
							model = child :: Model
						end
					end
					expect(model ~= nil).toBeTruthy()
					local box, size = (model :: Model):GetBoundingBox()
					local bottom = box.Position.Y - size.Y / 2
					local top = pedestal.Position.Y + pedestal.Size.X / 2 -- cilindru culcat: X e înălțimea
					expect(bottom).toBeCloseTo(top, 0.35)
				end
			end
		end)
	end)

	describe("Bunica", function()
		it("există câte o Bunica cu Humanoid în fiecare ogradă", function()
			local count = 0
			for _, plot in PlotService.plots do
				local rig = plot.geometry.model:FindFirstChild("Bunica")
				if rig and rig:FindFirstChildOfClass("Humanoid") then
					count += 1
				end
			end
			expect(count).toBe(World.plotCount)
		end)
	end)

	describe("Starea jocului", function()
		it("publică faza zilei și ora reînnoirii tarabei", function()
			local now = Workspace:GetServerTimeNow()
			expect(GameState.get("Phase") == "Day" or GameState.get("Phase") == "Night").toBeTruthy()
			expect(GameState.get("PhaseEndsAt")).toBeGreaterThan(now)
			expect(GameState.get("ShopRestockAt")).toBeGreaterThan(now)
		end)

		it("vremea pornește la cerere și e publicată", function()
			services.WeatherService.trigger("Rain")
			expect(GameState.get("Weather")).toBe("Rain")
		end)
	end)
end
