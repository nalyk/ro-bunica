--!strict
-- Bugetul de randare (80% din jucători sunt pe telefon): decorul unei ogrăzi ≤ 120k triunghiuri, decorul satului
-- ≤ 1,2M; decorul nu are coliziuni și nu face umbre.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ArtLibrary = require(Shared.Visual.ArtLibrary)

local DECOR_ART = {
	["world.Casa"] = true,
	["world.Poarta"] = true,
	["world.GardLow"] = true,
	["world.Tabla"] = true,
	["world.Nuc"] = true,
	["world.Visin"] = true,
	["world.FloareaSoarelui"] = true,
}
local DECOR_PARTS = {
	Bolta = true,
	BoltaSus = true,
	Vita = true,
	Strugure = true,
	Stup = true,
	StupCapac = true,
	StupPicior = true,
	Lemn = true,
	Capita = true,
	CapitaPar = true,
}

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local PlotService = services.PlotService

	local function plotDecor(model: Model): number
		local total = 0
		for _, child in model:GetChildren() do
			local key = child:GetAttribute("ArtKey")
			if (typeof(key) == "string" and DECOR_ART[key]) or DECOR_PARTS[child.Name] then
				total += ArtLibrary.triangles(child)
			end
		end
		return total
	end

	describe("Bugetul de randare", function()
		it("decorul fiecărei ogrăzi ≤ 120k triunghiuri, al satului ≤ 1,2M", function()
			local village = 0
			for _, plot in PlotService.plots do
				local tris = plotDecor(plot.geometry.model)
				print(string.format("[e2e] ograda %d: decor %d triunghiuri", plot.index, tris))
				expect(tris <= 120000).toBe(true)
				village += tris
			end
			local folder = Workspace:FindFirstChild("Village") :: Instance
			for _, name in { "Sites", "Scatter", "Roads" } do
				local part = folder:FindFirstChild(name)
				if part then
					village += ArtLibrary.triangles(part)
				end
			end
			print(string.format("[e2e] decorul satului: %d triunghiuri", village))
			expect(village <= 1200000).toBe(true)
		end)

		it("decorul nu are coliziuni și nu face umbre", function()
			for _, plot in PlotService.plots do
				for _, child in plot.geometry.model:GetChildren() do
					if DECOR_PARTS[child.Name] and child:IsA("BasePart") then
						expect(child.CanCollide == false and child.CastShadow == false).toBe(true)
					end
				end
			end
			local scatter = (Workspace:FindFirstChild("Village") :: Instance):FindFirstChild(
					"Scatter"
				) :: Instance
			for _, child in scatter:GetChildren() do
				if child:IsA("BasePart") and child.Name ~= "Stalp" then
					expect(child.CanCollide == false and child.CastShadow == false).toBe(true)
				end
			end
		end)
	end)
end
