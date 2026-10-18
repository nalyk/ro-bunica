--!strict
-- Obiectele de decor ale ogrăzii (Config/Decor), procedurale, fără coliziuni și fără umbre.

local DecorModels = {}

local function p(
	model: Model,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = model:GetPivot() * offset
	part.Parent = model
end

local B, BALL, CYL = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder
local WOOD, DARK = Color3.fromRGB(140, 96, 58), Color3.fromRGB(92, 64, 40)
local UP = CFrame.Angles(0, 0, math.pi / 2) -- cilindru vertical

local builders: { [string]: (Model) -> () } = {
	muscate = function(m)
		p(
			m,
			"Ghiveci",
			CYL,
			Vector3.new(1.2, 1.4, 1.4),
			CFrame.new(0, 0.6, 0) * UP,
			Color3.fromRGB(180, 90, 50)
		)
		for i = 0, 4 do
			p(
				m,
				"Floare",
				BALL,
				Vector3.new(0.6, 0.6, 0.6),
				CFrame.new(math.cos(i * 1.3) * 0.4, 1.5 + (i % 2) * 0.2, math.sin(i * 1.3) * 0.4),
				Color3.fromRGB(230, 40, 70)
			)
		end
	end,
	trandafiri = function(m)
		for i = -1, 1 do
			p(
				m,
				"Tufa",
				BALL,
				Vector3.new(1.8, 1.6, 1.8),
				CFrame.new(i * 1.6, 0.8, 0),
				Color3.fromRGB(70, 120, 60),
				Enum.Material.Grass
			)
			p(
				m,
				"Trandafir",
				BALL,
				Vector3.new(0.6, 0.6, 0.6),
				CFrame.new(i * 1.6 + 0.3, 1.6, -0.5),
				Color3.fromRGB(220, 50, 90)
			)
		end
	end,
	floareaSoarelui = function(m)
		for i = -1, 1 do
			p(
				m,
				"Tulpina",
				CYL,
				Vector3.new(4, 0.25, 0.25),
				CFrame.new(i * 1.2, 2, 0) * UP,
				Color3.fromRGB(90, 140, 50)
			)
			p(
				m,
				"Floare",
				CYL,
				Vector3.new(0.3, 1.6, 1.6),
				CFrame.new(i * 1.2, 4.1, -0.2) * CFrame.Angles(0, math.pi / 2, 0),
				Color3.fromRGB(240, 200, 40)
			)
		end
	end,
	sperietoare = function(m)
		p(m, "Par", B, Vector3.new(0.4, 5, 0.4), CFrame.new(0, 2.5, 0), DARK, Enum.Material.Wood)
		p(m, "Brate", B, Vector3.new(3.6, 0.3, 0.3), CFrame.new(0, 3.6, 0), DARK, Enum.Material.Wood)
		p(
			m,
			"Camasa",
			B,
			Vector3.new(2, 1.8, 0.8),
			CFrame.new(0, 3.3, 0),
			Color3.fromRGB(200, 60, 50),
			Enum.Material.Fabric
		)
		p(
			m,
			"Cap",
			BALL,
			Vector3.new(1.2, 1.2, 1.2),
			CFrame.new(0, 4.8, 0),
			Color3.fromRGB(214, 182, 100),
			Enum.Material.Grass
		)
		p(
			m,
			"Palarie",
			CYL,
			Vector3.new(0.3, 1.8, 1.8),
			CFrame.new(0, 5.4, 0) * UP,
			Color3.fromRGB(60, 50, 40)
		)
	end,
	roaba = function(m)
		p(
			m,
			"Cuva",
			B,
			Vector3.new(2, 1, 3),
			CFrame.new(0, 1, 0),
			Color3.fromRGB(80, 120, 170),
			Enum.Material.Metal
		)
		p(m, "Roata", CYL, Vector3.new(0.4, 1.2, 1.2), CFrame.new(0, 0.6, -1.8), Color3.fromRGB(40, 40, 40))
		p(m, "Manere", B, Vector3.new(1.8, 0.2, 2), CFrame.new(0, 1.2, 2.2), WOOD, Enum.Material.Wood)
	end,
	banca = function(m)
		p(m, "Sezut", B, Vector3.new(5, 0.4, 1.4), CFrame.new(0, 1.5, 0), WOOD, Enum.Material.WoodPlanks)
		p(m, "Spatar", B, Vector3.new(5, 1.2, 0.3), CFrame.new(0, 2.3, 0.6), WOOD, Enum.Material.WoodPlanks)
		for _, x in { -2.2, 2.2 } do
			p(m, "Picior", B, Vector3.new(0.4, 1.4, 1.2), CFrame.new(x, 0.7, 0), DARK)
		end
	end,
	felinar = function(m)
		p(
			m,
			"Stalp",
			B,
			Vector3.new(0.3, 5, 0.3),
			CFrame.new(0, 2.5, 0),
			Color3.fromRGB(40, 40, 44),
			Enum.Material.Metal
		)
		p(
			m,
			"Lampa",
			B,
			Vector3.new(0.9, 1.1, 0.9),
			CFrame.new(0, 5.4, 0),
			Color3.fromRGB(255, 220, 140),
			Enum.Material.Neon
		)
		local light = Instance.new("PointLight")
		light.Range = 14
		light.Brightness = 1.4
		light.Color = Color3.fromRGB(255, 210, 140)
		light.Parent = m:FindFirstChild("Lampa")
	end,
	butoaie = function(m)
		for i = 0, 1 do
			p(
				m,
				"Butoi",
				CYL,
				Vector3.new(2, 1.6, 1.6),
				CFrame.new(i * 1.8, 1, 0) * UP,
				WOOD,
				Enum.Material.Wood
			)
		end
		p(m, "Butoi", CYL, Vector3.new(2, 1.6, 1.6), CFrame.new(0.9, 2.6, 0) * UP, WOOD, Enum.Material.Wood)
	end,
	ulcioare = function(m)
		for i = 0, 2 do
			p(
				m,
				"Ulcior",
				BALL,
				Vector3.new(1, 1.3, 1),
				CFrame.new(i * 1.1, 0.65, 0),
				Color3.fromRGB(170 + i * 10, 90, 50)
			)
		end
	end,
	cocorDeLemn = function(m)
		p(m, "Stalp", B, Vector3.new(0.3, 2.4, 0.3), CFrame.new(0, 1.2, 0), DARK, Enum.Material.Wood)
		p(
			m,
			"Corp",
			B,
			Vector3.new(0.8, 0.8, 2),
			CFrame.new(0, 2.8, 0),
			Color3.fromRGB(230, 230, 220),
			Enum.Material.Wood
		)
		p(
			m,
			"Gat",
			B,
			Vector3.new(0.25, 1.6, 0.25),
			CFrame.new(0, 3.8, -0.8),
			Color3.fromRGB(230, 230, 220),
			Enum.Material.Wood
		)
		p(m, "Cioc", B, Vector3.new(0.15, 0.15, 0.9), CFrame.new(0, 4.6, -1.2), Color3.fromRGB(200, 60, 40))
	end,
	fantanaCuCumpana = function(m)
		p(
			m,
			"Ghizd",
			CYL,
			Vector3.new(2, 3, 3),
			CFrame.new(0, 1, 0) * UP,
			Color3.fromRGB(150, 150, 150),
			Enum.Material.Cobblestone
		)
		p(m, "Furca", B, Vector3.new(0.4, 6, 0.4), CFrame.new(2.4, 3, 0), DARK, Enum.Material.Wood)
		p(
			m,
			"Cumpana",
			B,
			Vector3.new(0.3, 0.3, 9),
			CFrame.new(2.4, 6, 0) * CFrame.Angles(math.rad(20), 0, 0),
			WOOD,
			Enum.Material.Wood
		)
	end,
	stupi = function(m)
		for i = 0, 1 do
			p(
				m,
				"Stup",
				B,
				Vector3.new(1.8, 1.6, 1.8),
				CFrame.new(i * 2.4, 1, 0),
				Color3.fromRGB(240, 200, 60),
				Enum.Material.WoodPlanks
			)
			p(
				m,
				"Capac",
				B,
				Vector3.new(2.1, 0.3, 2.1),
				CFrame.new(i * 2.4, 1.95, 0),
				Color3.fromRGB(176, 72, 48)
			)
		end
	end,
	capitaDeFan = function(m)
		p(
			m,
			"Capita",
			BALL,
			Vector3.new(4, 4.4, 4),
			CFrame.new(0, 2, 0),
			Color3.fromRGB(214, 182, 100),
			Enum.Material.Grass
		)
	end,
	masaCuPlacinte = function(m)
		p(m, "Masa", B, Vector3.new(4, 0.3, 2.4), CFrame.new(0, 2.2, 0), WOOD, Enum.Material.WoodPlanks)
		p(
			m,
			"Fata",
			B,
			Vector3.new(4.2, 0.05, 2.6),
			CFrame.new(0, 2.38, 0),
			Color3.fromRGB(240, 240, 235),
			Enum.Material.Fabric
		)
		for i = -1, 1 do
			p(
				m,
				"Placinta",
				CYL,
				Vector3.new(0.4, 1, 1),
				CFrame.new(i * 1.2, 2.6, 0) * UP,
				Color3.fromRGB(214, 160, 80)
			)
		end
		for _, x in { -1.8, 1.8 } do
			p(m, "Picior", B, Vector3.new(0.3, 2.1, 2), CFrame.new(x, 1.05, 0), DARK)
		end
	end,
}

-- Covoarele și prosoapele de pe gard: o pânză atârnată, în culoarea obiectului
local function fence(m: Model, color: Color3)
	p(m, "Panza", B, Vector3.new(6, 3, 0.1), CFrame.new(0, 2.6, -0.6), color, Enum.Material.Fabric)
	for i = -2, 2 do
		p(
			m,
			"Model",
			B,
			Vector3.new(0.6, 0.6, 0.05),
			CFrame.new(i * 1.2, 2.6, -0.67),
			Color3.fromRGB(250, 230, 120)
		)
	end
end

-- Construiește obiectul `id` la `cf` (baza pe sol, fața spre −Z)
function DecorModels.build(id: string, kind: string, color: Color3?, cf: CFrame, parent: Instance): Model?
	local model = Instance.new("Model")
	model.Name = "Decor_" .. id
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.Transparency = 1
	root.Size = Vector3.new(1, 1, 1)
	root.CFrame = cf
	root.Parent = model
	model.PrimaryPart = root
	if kind == "fence" then
		fence(model, color or Color3.new(1, 1, 1))
	elseif builders[id] then
		builders[id](model)
	end
	model:SetAttribute("Decor", id)
	model.Parent = parent
	return model
end

return DecorModels
