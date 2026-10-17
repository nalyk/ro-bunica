--!strict
-- Răzbunarea pe client: după un furt, hoțul (dacă e jucător) și creatura furată sunt conturate cu roșu, vizibile
-- prin pereți, până în zori sau până o recuperezi. Fără text: conturul și săgeata spun tot.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Theme = require(script.Parent.Theme)

local RevengeController = {}

type Target = { thief: number, name: string, uid: string }

local target: Target? = nil
local highlights: { Highlight } = {}

local function clearHighlights()
	for _, highlight in highlights do
		highlight:Destroy()
	end
	table.clear(highlights)
end

local function outline(model: Instance)
	local highlight = Instance.new("Highlight")
	highlight.Name = "RevengeHighlight"
	highlight.FillTransparency = 0.75
	highlight.FillColor = Theme.swatches.ie.base
	highlight.OutlineColor = Theme.swatches.ie.light
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = model
	highlight.Parent = model
	table.insert(highlights, highlight)
end

-- Caută hoțul și creatura (pot apărea mai târziu: hoțul o depune pe piedestalul lui)
local function refresh()
	clearHighlights()
	local current = target
	if not current then
		return
	end
	local thiefPlayer = Players:GetPlayerByUserId(current.thief)
	if thiefPlayer and thiefPlayer.Character then
		outline(thiefPlayer.Character)
	end
	local village = Workspace:FindFirstChild("Village")
	for _, descendant in (village and village:GetDescendants() or {}) :: { Instance } do
		if descendant:IsA("Model") and descendant:GetAttribute("Uid") == current.uid then
			outline(descendant)
			break
		end
	end
end

-- Pentru playtest: ținta curentă
function RevengeController.target(): Target?
	return target
end

function RevengeController.start()
	Net.get("Revenge").OnClientEvent:Connect(function(data: Target?)
		target = data
		refresh()
	end)
	task.spawn(function()
		while true do
			task.wait(1.5)
			if target then
				refresh()
			end
		end
	end)
end

return RevengeController
