--!strict
-- Garderoba Bunicii (pe lei): accesorii sudate pe Bunica din ogradă. Piesele sunt relative la capul ei
-- (`attach = "head"`) sau la rădăcină (`"root"`), cu −Z în fața ei.

export type Piece = {
	name: string,
	shape: "Block" | "Ball" | "Cylinder",
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?,
	attach: "head" | "root",
}
export type Outfit = { id: string, price: number, pieces: { Piece } }

local UP = CFrame.Angles(0, 0, math.pi / 2)

local list: { Outfit } = {
	{
		id = "sarbatoare", -- coronița de flori
		price = 2500,
		pieces = {
			{
				name = "Coronita",
				shape = "Cylinder",
				size = Vector3.new(0.4, 2.3, 2.3),
				offset = CFrame.new(0, 0.9, 0) * UP,
				color = Color3.fromRGB(80, 150, 60),
				material = Enum.Material.Grass,
				attach = "head",
			},
			{
				name = "Floare",
				shape = "Ball",
				size = Vector3.new(0.6, 0.6, 0.6),
				offset = CFrame.new(0.8, 1.05, -0.5),
				color = Color3.fromRGB(230, 50, 80),
				attach = "head",
			},
			{
				name = "Floare",
				shape = "Ball",
				size = Vector3.new(0.6, 0.6, 0.6),
				offset = CFrame.new(-0.8, 1.05, -0.5),
				color = Color3.fromRGB(250, 220, 60),
				attach = "head",
			},
		},
	},
	{
		id = "iarna", -- căciula de blană și fularul
		price = 3000,
		pieces = {
			{
				name = "Caciula",
				shape = "Cylinder",
				size = Vector3.new(1.2, 2.2, 2.2),
				offset = CFrame.new(0, 1.1, 0) * UP,
				color = Color3.fromRGB(90, 70, 55),
				material = Enum.Material.Fabric,
				attach = "head",
			},
			{
				name = "Fular",
				shape = "Cylinder",
				size = Vector3.new(0.6, 2, 2),
				offset = CFrame.new(0, -1.1, 0) * UP,
				color = Color3.fromRGB(200, 40, 50),
				material = Enum.Material.Fabric,
				attach = "head",
			},
		},
	},
	{
		id = "discoteca", -- ochelarii și eșarfa strălucitoare
		price = 4000,
		pieces = {
			{
				name = "Ochelari",
				shape = "Block",
				size = Vector3.new(1.8, 0.45, 0.2),
				offset = CFrame.new(0, 0.15, -0.95),
				color = Color3.fromRGB(30, 30, 35),
				material = Enum.Material.Glass,
				attach = "head",
			},
			{
				name = "Esarfa",
				shape = "Block",
				size = Vector3.new(2.4, 0.4, 1.6),
				offset = CFrame.new(0, -1.2, 0),
				color = Color3.fromRGB(255, 80, 200),
				material = Enum.Material.Neon,
				attach = "head",
			},
		},
	},
	{
		id = "pescar", -- pălăria cu boruri și undița
		price = 2800,
		pieces = {
			{
				name = "Palarie",
				shape = "Cylinder",
				size = Vector3.new(0.2, 3, 3),
				offset = CFrame.new(0, 0.85, 0) * UP,
				color = Color3.fromRGB(110, 120, 80),
				material = Enum.Material.Fabric,
				attach = "head",
			},
			{
				name = "Calota",
				shape = "Cylinder",
				size = Vector3.new(0.9, 1.7, 1.7),
				offset = CFrame.new(0, 1.3, 0) * UP,
				color = Color3.fromRGB(110, 120, 80),
				material = Enum.Material.Fabric,
				attach = "head",
			},
			{
				name = "Undita",
				shape = "Block",
				size = Vector3.new(0.12, 0.12, 6),
				offset = CFrame.new(1.4, 1.6, -1.5) * CFrame.Angles(math.rad(40), 0, 0),
				color = Color3.fromRGB(120, 84, 52),
				material = Enum.Material.Wood,
				attach = "root",
			},
		},
	},
	{
		id = "gradinar", -- pălăria de paie și stropitoarea
		price = 2200,
		pieces = {
			{
				name = "PalariePaie",
				shape = "Cylinder",
				size = Vector3.new(0.2, 3.2, 3.2),
				offset = CFrame.new(0, 0.85, 0) * UP,
				color = Color3.fromRGB(226, 196, 120),
				material = Enum.Material.Grass,
				attach = "head",
			},
			{
				name = "Stropitoare",
				shape = "Cylinder",
				size = Vector3.new(1.4, 1.2, 1.2),
				offset = CFrame.new(1.5, 0.2, -0.6) * UP,
				color = Color3.fromRGB(80, 150, 90),
				material = Enum.Material.Metal,
				attach = "root",
			},
		},
	},
	{
		id = "hram", -- vesta brodată și basmaua de sărbătoare
		price = 5000,
		pieces = {
			{
				name = "Vesta",
				shape = "Block",
				size = Vector3.new(2.6, 2.2, 1.6),
				offset = CFrame.new(0, 0.9, 0),
				color = Color3.fromRGB(30, 30, 40),
				material = Enum.Material.Fabric,
				attach = "root",
			},
			{
				name = "Broderie",
				shape = "Block",
				size = Vector3.new(1.8, 0.4, 0.1),
				offset = CFrame.new(0, 1.2, -0.85),
				color = Color3.fromRGB(200, 30, 40),
				material = Enum.Material.Fabric,
				attach = "root",
			},
			{
				name = "BasmaAlba",
				shape = "Ball",
				size = Vector3.new(2.1, 1.6, 2.1),
				offset = CFrame.new(0, 0.6, 0.25),
				color = Color3.fromRGB(250, 248, 240),
				material = Enum.Material.Fabric,
				attach = "head",
			},
		},
	},
}

local byId: { [string]: Outfit } = {}
for _, outfit in list do
	byId[outfit.id] = outfit
end

return table.freeze({ list = list, byId = byId })
