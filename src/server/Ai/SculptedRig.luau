--!strict
-- Rig-uri pentru personajele sculptate (art/: concept Codex → TRELLIS.2 → tăiate cu tools/split_character.py).
-- Șablonul are piesele (Body, Head, LeftArm, RightArm și, la cei care merg, LeftLeg, RightLeg) plus markeri
-- „Pivot_<Articulație>” în pozițiile articulațiilor. Construim un rig propriu: HumanoidRootPart (invizibil),
-- piesele legate prin Motor6D numite ca la R15 (Root, Neck, LeftShoulder, RightShoulder, LeftHip, RightHip),
-- deci pozele și mersul procedural de pe client merg pe orice personaj sculptat.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ArtLibrary = require(Shared.Visual.ArtLibrary)

local SculptedRig = {}

-- Rădăcina stă la ROOT_HEIGHT deasupra tălpilor; Humanoid-ul o ține acolo prin HipHeight
SculptedRig.ROOT_HEIGHT = 2.5
local ROOT_SIZE = Vector3.new(2, 2, 1)

local JOINTS: { { string } } = {
	-- { motor, piesa-părinte, piesa-copil }
	{ "Neck", "Body", "Head" },
	{ "LeftShoulder", "Body", "LeftArm" },
	{ "RightShoulder", "Body", "RightArm" },
	{ "LeftHip", "Body", "LeftLeg" },
	{ "RightHip", "Body", "RightLeg" },
}

export type Built = {
	rig: Model,
	humanoid: Humanoid,
	root: BasePart,
	head: BasePart,
}

-- `key`: șablonul din ArtLibrary (de exemplu „char.Bunica”). `base`: tălpile, cu fața personajului spre
-- base.LookVector. `rootAt`: alt cadru pentru rădăcină (implicit deasupra tălpilor, orientat ca `base`).
-- Întoarce nil dacă șablonul lipsește sau e incomplet (apelantul folosește rig-ul R15).
function SculptedRig.build(key: string, name: string, base: CFrame, rootAt: CFrame?): Built?
	local template = ArtLibrary.get(key)
	if not template then
		return nil
	end
	local rig = Instance.new("Model")
	rig.Name = name
	rig:SetAttribute("Sculpted", true)
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = ROOT_SIZE
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.CFrame = rootAt or base * CFrame.new(0, SculptedRig.ROOT_HEIGHT, 0)
	root.Parent = rig
	rig.PrimaryPart = root

	-- modelul e exportat cu fața spre -Z în spațiul lui; base.LookVector e tot -Z, deci se pune direct
	local pieces: { [string]: BasePart } = {}
	local pivots: { [string]: Vector3 } = {}
	for _, child in template:GetChildren() do
		if child:IsA("BasePart") then
			local world = base * child.CFrame
			if string.sub(child.Name, 1, 6) == "Pivot_" then
				pivots[string.sub(child.Name, 7)] = world.Position
			else
				child.CFrame = world
				child.Anchored = false
				child.Massless = true
				child.CanCollide = false
				child.CanQuery = false
				child.CanTouch = false
				child.Parent = rig
				pieces[child.Name] = child
			end
		end
	end
	template:Destroy()
	local body, head = pieces.Body, pieces.Head
	if not body or not head then
		rig:Destroy()
		return nil
	end

	local function motor(motorName: string, part0: BasePart, part1: BasePart, pivot: Vector3)
		local at = CFrame.new(pivot) * base.Rotation
		local m = Instance.new("Motor6D")
		m.Name = motorName
		m.Part0 = part0
		m.Part1 = part1
		m.C0 = part0.CFrame:ToObjectSpace(at)
		m.C1 = part1.CFrame:ToObjectSpace(at)
		m.Parent = part1
	end
	motor("Root", root, body, root.Position)
	for _, joint in JOINTS do
		local parent, child = pieces[joint[2]], pieces[joint[3]]
		if parent and child then
			motor(joint[1], parent, child, pivots[joint[1]] or child.Position)
		end
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = SculptedRig.ROOT_HEIGHT - ROOT_SIZE.Y / 2
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = rig
	return { rig = rig, humanoid = humanoid, root = root :: BasePart, head = head }
end

return SculptedRig
