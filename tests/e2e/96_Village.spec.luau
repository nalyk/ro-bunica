--!strict
-- Satul de vale: ogrăzile arată diferit, dar se joacă la fel; pârâul are apă; decorul nu încurcă.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Village = require(Shared.Config.Village)
local VillageLayout = require(Shared.Domain.VillageLayout)

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local PlotService = services.PlotService

	local function localOf(geometry: any, part: BasePart): Vector3
		return geometry.cframe:PointToObjectSpace(part.Position)
	end

	describe("Satul de vale", function()
		it("straturile, piedestalele și depozitul au aceleași poziții în toate ogrăzile", function()
			local first = PlotService.plots[1].geometry
			for _, plot in PlotService.plots do
				local g = plot.geometry
				for key, bed in first.beds do
					expect((localOf(g, g.beds[key]) - localOf(first, bed)).Magnitude < 0.01).toBe(true)
				end
				for key, pedestal in first.pedestals do
					expect((localOf(g, g.pedestals[key]) - localOf(first, pedestal)).Magnitude < 0.01).toBe(
						true
					)
				end
				expect((localOf(g, g.deposit) - localOf(first, first.deposit)).Magnitude < 0.01).toBe(true)
			end
		end)

		it("porțile sunt vopsite după variantă, iar decorul nu are coliziuni", function()
			for index, plot in PlotService.plots do
				local look = VillageLayout.variantFor(index, Village.variantSeed)
				local post = plot.geometry.model:FindFirstChild("GatePost") :: BasePart
				expect(post.Color == look.gateColor).toBe(true)
				for _, name in { "Bolta", "Vita", "Stup", "Lemn", "Capita" } do
					for _, child in plot.geometry.model:GetChildren() do
						if child.Name == name and child:IsA("BasePart") then
							expect(child.CanCollide).toBe(false)
						end
					end
				end
			end
		end)

		it("pârâul are apă, iar drumurile sunt construite", function()
			local layout = VillageLayout.build()
			local p = layout.river[math.floor(#layout.river / 2)]
			local region = Region3.new(p - Vector3.new(4, 4, 4), p + Vector3.new(4, 0, 4)):ExpandToGrid(4)
			local materials = Workspace.Terrain:ReadVoxels(region, 4)
			local water = 0
			for x = 1, materials.Size.X do
				for y = 1, materials.Size.Y do
					for z = 1, materials.Size.Z do
						if materials[x][y][z] == Enum.Material.Water then
							water += 1
						end
					end
				end
			end
			expect(water > 0).toBe(true)
			local roads = Workspace:FindFirstChild("Village") and Workspace.Village:FindFirstChild("Roads")
			expect(roads ~= nil and #roads:GetChildren() > 50).toBe(true)
		end)
	end)
end
