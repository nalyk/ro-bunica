--!strict
-- Recordurile mini-jocurilor: cel mai bun de pe server (pe avizierul din centru: atributele „Record_<joc>” =
-- "nume|scor", afișate traduse de SiteController) și recordul personal din profil.

local Workspace = game:GetService("Workspace")

local Records = {}

local best: { [string]: { name: string, score: number } } = {}

local function board(): BasePart?
	local village = Workspace:FindFirstChild("Village")
	local sites = village and village:FindFirstChild("Sites")
	local centre = sites and sites:FindFirstChild("centru")
	local part = centre and centre:FindFirstChild("Avizier", true)
	return if part and part:IsA("BasePart") then part else nil
end

-- Trimite un scor. Întoarce (record pe server?, record personal?).
function Records.submit(gameId: string, owner: any, score: number): (boolean, boolean)
	local personal = false
	local records = owner.profile.records
	if records and score > (records[gameId] or 0) then
		records[gameId] = score
		personal = true
	end
	local current = best[gameId]
	if current and score <= current.score then
		return false, personal
	end
	best[gameId] = { name = owner.name, score = score }
	local part = board()
	if part then
		part:SetAttribute("Record_" .. gameId, owner.name .. "|" .. tostring(score))
	end
	return true, personal
end

function Records.best(gameId: string): (string?, number?)
	local entry = best[gameId]
	if entry then
		return entry.name, entry.score
	end
	return nil, nil
end

return Records
