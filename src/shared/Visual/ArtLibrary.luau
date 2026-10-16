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
		return template:Clone()
	end
	return nil
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
