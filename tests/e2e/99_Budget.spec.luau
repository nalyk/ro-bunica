--!strict
-- Bugetul de randare (80% din jucători sunt pe telefon): decorul unei ogrăzi ≤ 120k triunghiuri; densitatea locală
-- (triunghiurile decorului pe o rază de 200 studs, maximul pe o grilă peste sat) ≤ 1M: ce se vede de aproape se
-- randează întreg, ce e departe trece pe LOD-ul automat al plaselor. Decorul nu are coliziuni.

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
	["world.Uluci"] = true,
	["world.Liliac"] = true,
	["world.Flori"] = true,
	["world.Lemne"] = true,
	["world.Claie"] = true,
	["world.ButucVie"] = true,
}
local RADIUS = 200
local LOCAL_MAX = 1000000
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
		it("decorul fiecărei ogrăzi ≤ 120k triunghiuri; densitatea locală ≤ 1M", function()
			local items: { { position: Vector3, tris: number } } = {}
			local function collect(root: Instance, filter: ((Instance) -> boolean)?)
				for _, child in root:GetChildren() do
					if filter and not filter(child) then
						continue
					end
					local tris = ArtLibrary.triangles(child)
					if tris > 0 then
						local position = if child:IsA("Model")
							then child:GetPivot().Position
							elseif child:IsA("BasePart") then child.Position
							else nil
						if position then
							table.insert(items, { position = position, tris = tris })
						elseif not child:IsA("Model") then
							collect(child)
						end
					end
				end
			end
			for _, plot in PlotService.plots do
				local tris = plotDecor(plot.geometry.model)
				print(string.format("[e2e] ograda %d: decor %d triunghiuri", plot.index, tris))
				expect(tris <= 120000).toBe(true)
				collect(plot.geometry.model, function(child)
					local key = child:GetAttribute("ArtKey")
					return (typeof(key) == "string" and DECOR_ART[key] == true)
						or DECOR_PARTS[child.Name] == true
				end)
			end
			local folder = Workspace:FindFirstChild("Village") :: Instance
			for _, name in { "Sites", "Scatter", "Roads" } do
				local part = folder:FindFirstChild(name)
				if part and name == "Sites" then
					for _, site in part:GetChildren() do
						collect(site) -- fiecare obiect din loc, cu poziția lui
					end
				elseif part then
					collect(part)
				end
			end
			local total, peak, at = 0, 0, Vector3.zero
			for _, item in items do
				total += item.tris
			end
			for x = -400, 400, 40 do
				for z = -280, 360, 40 do
					local here = Vector3.new(x, 0, z)
					local sum = 0
					for _, item in items do
						local d = Vector3.new(item.position.X - x, 0, item.position.Z - z).Magnitude
						if d <= RADIUS then
							sum += item.tris
						end
					end
					if sum > peak then
						peak, at = sum, here
					end
				end
			end
			print(
				string.format(
					"[e2e] decorul satului: %d triunghiuri în total; densitatea maximă %d pe %d studs, la (%d, %d)",
					total,
					peak,
					RADIUS,
					at.X,
					at.Z
				)
			)
			expect(peak <= LOCAL_MAX).toBe(true)
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
			for _, child in scatter:GetDescendants() do
				if child:IsA("BasePart") and child.Name ~= "Stalp" then
					expect(child.CanCollide).toBe(false)
				end
			end
		end)
	end)
end
