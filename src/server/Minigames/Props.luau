--!strict
-- Obiectele din ogradă în care se deghizează Păcală (și momelile): găleată, oală, dovleac, butuc, claie.

local Props = {}

local LOOK: { [string]: { shape: Enum.PartType, size: Vector3, color: Color3, material: Enum.Material } } = {
	Galeata = {
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(2.2, 2.4, 2.4),
		color = Color3.fromRGB(150, 156, 162),
		material = Enum.Material.Metal,
	},
	Oala = {
		shape = Enum.PartType.Ball,
		size = Vector3.new(2.6, 2.2, 2.6),
		color = Color3.fromRGB(40, 36, 34),
		material = Enum.Material.SmoothPlastic,
	},
	Dovleac = {
		shape = Enum.PartType.Ball,
		size = Vector3.new(3, 2.4, 3),
		color = Color3.fromRGB(230, 130, 30),
		material = Enum.Material.SmoothPlastic,
	},
	Butuc = {
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(2.4, 2.8, 2.8),
		color = Color3.fromRGB(120, 84, 52),
		material = Enum.Material.Wood,
	},
	Claie = {
		shape = Enum.PartType.Ball,
		size = Vector3.new(4, 4.4, 4),
		color = Color3.fromRGB(214, 182, 100),
		material = Enum.Material.Grass,
	},
}

-- Un obiect (Part) la `cf`, cu baza pe sol
function Props.make(name: string, cf: CFrame, parent: Instance): Part
	local look = LOOK[name] or LOOK.Dovleac
	local p = Instance.new("Part")
	p.Name = "Obiect_" .. name
	p.Shape = look.shape
	p.Size = look.size
	p.Color = look.color
	p.Material = look.material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	local height = if look.shape == Enum.PartType.Cylinder then look.size.X else look.size.Y
	p.CFrame = cf
		* CFrame.new(0, height / 2, 0)
		* (if look.shape == Enum.PartType.Cylinder then CFrame.Angles(0, 0, math.pi / 2) else CFrame.identity)
	p:SetAttribute("Disguise", name)
	p.Parent = parent
	return p
end

return Props
