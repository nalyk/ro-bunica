--!strict
-- Biblioteca de modele: șabloanele încărcate de server (ArtService) stau în ReplicatedStorage.ArtTemplates,
-- ca serverul și clientul (vitrine, previzualizări în UI) să le cloneze. Fără șablon → nil (forma procedurală).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtLibrary = {}

ArtLibrary.FOLDER = "ArtTemplates"

function ArtLibrary.folder(): Folder?
	return ReplicatedStorage:FindFirstChild(ArtLibrary.FOLDER) :: Folder?
end

function ArtLibrary.has(key: string): boolean
	local folder = ArtLibrary.folder()
	return folder ~= nil and folder:FindFirstChild(key) ~= nil
end

-- O copie a șablonului `key` (de exemplu „creature.CartofelAgent”), sau nil dacă nu există.
function ArtLibrary.get(key: string): Model?
	local folder = ArtLibrary.folder()
	local template = folder and folder:FindFirstChild(key)
	if template and template:IsA("Model") then
		local copy = template:Clone()
		copy:SetAttribute("ArtKey", key) -- pentru bugetul de triunghiuri (ArtLibrary.triangles)
		return copy
	end
	return nil
end

-- Triunghiurile din modelele sculptate de sub `root` (din metadatele Config/ArtAssets) plus o estimare
-- pentru piesele procedurale: bugetul de randare (Task 10, tests/e2e/99_Budget).
local PART_TRIS = { [Enum.PartType.Block] = 12, [Enum.PartType.Cylinder] = 64, [Enum.PartType.Ball] = 192 }
function ArtLibrary.triangles(root: Instance): number
	local ArtAssets = require(script.Parent.Parent.Config.ArtAssets)
	local total = 0
	local function visit(node: Instance)
		local key = node:GetAttribute("ArtKey")
		if typeof(key) == "string" then
			local art = ArtAssets[key]
			total += if art then art.tris else 0
			return -- piesele modelului sunt deja numărate
		end
		if node:IsA("Part") then
			total += PART_TRIS[node.Shape] or 12
		elseif node:IsA("WedgePart") then
			total += 8
		end
		for _, child in node:GetChildren() do
			visit(child)
		end
	end
	visit(root)
	return total
end

-- Sloturile colorabile ale unui model (fără contur): pentru mutații și efecte
function ArtLibrary.slots(model: Model): { MeshPart }
	local parts = {}
	for _, child in model:GetDescendants() do
		if child:IsA("MeshPart") and child.Name ~= "ink" then
			table.insert(parts, child)
		end
	end
	return parts
end

return ArtLibrary
