--!strict
-- Încarcă modelele din art/ (asset-urile din Config/ArtAssets) la pornirea serverului și le pregătește ca
-- șabloane: piesele (câte una per slot) primesc culoarea din paletă, conturul nu aruncă umbră, totul e
-- ancorat și fără coliziuni. Un model care nu se încarcă e sărit: jocul folosește forma procedurală.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArtAssets = require(Shared.Config.ArtAssets)
local ArtLibrary = require(Shared.Visual.ArtLibrary)

local ArtService = {}

local TIMEOUT = 25

local function prepare(key: string, art: ArtAssets.Art, loaded: Instance): Model
	local model = Instance.new("Model")
	model.Name = key
	local primary: MeshPart? = nil
	local biggest = 0
	for _, descendant in loaded:GetDescendants() do
		if descendant:IsA("MeshPart") then
			local part = descendant
			local isInk = part.Name == "ink"
			part.Color = if isInk
				then (art.ink or Color3.new(0, 0, 0))
				else (art.palette[part.Name] or part.Color)
			part.Material = Enum.Material.SmoothPlastic
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = not isInk -- conturul învelește modelul: ar arunca umbră pe el
			part.Parent = model
			local volume = part.Size.X * part.Size.Y * part.Size.Z
			if
				part.Name == "body"
				or (not isInk and volume > biggest and (primary == nil or primary.Name ~= "body"))
			then
				primary = part
				biggest = volume
			end
		end
	end
	model.PrimaryPart = primary
	model:SetAttribute("ArtKey", key)
	return model
end

-- Încarcă toate modelele în paralel; întoarce când sunt gata sau după TIMEOUT secunde.
function ArtService.init()
	local folder = ReplicatedStorage:FindFirstChild(ArtLibrary.FOLDER) :: Folder?
	if not folder then
		local created = Instance.new("Folder")
		created.Name = ArtLibrary.FOLDER
		created.Parent = ReplicatedStorage
		folder = created
	end
	local target = folder :: Folder
	local pending = 0
	for key, art in ArtAssets do
		if target:FindFirstChild(key) then
			continue
		end
		pending += 1
		task.spawn(function()
			local ok, result = pcall(InsertService.LoadAsset, InsertService, art.assetId)
			if ok then
				prepare(key, art, result).Parent = target
				result:Destroy()
			else
				warn("[ArtService] nu s-a încărcat", key, art.assetId, result)
			end
			pending -= 1
		end)
	end
	local deadline = os.clock() + TIMEOUT
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
	if pending > 0 then
		warn("[ArtService] modele neîncărcate la timp:", pending)
	end
end

return ArtService
