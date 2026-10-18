--!strict
-- Așezarea decorului: semne „+” (butoane în lume) pe sloturile potrivite din ograda ta; atingi unul și obiectul
-- se pune acolo. „✕” anulează. Merge la fel cu degetul și cu mouse-ul.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local DecorConfig = require(Shared.Config.Decor)
local ClientState = require(script.Parent.ClientState)
local UI = require(script.Parent.UI)

local DecorPlacer = {}

local markers: { Instance } = {}
local cancelButton: TextButton? = nil
local placing: string? = nil

local function stop()
	for _, m in markers do
		m:Destroy()
	end
	table.clear(markers)
	if cancelButton then
		cancelButton:Destroy()
		cancelButton = nil
	end
	placing = nil
end

function DecorPlacer.active(): string?
	return placing
end

local function myPlot(): Model?
	local village = Workspace:FindFirstChild("Village")
	if not village then
		return nil
	end
	for _, child in village:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId then
			return child
		end
	end
	return nil
end

function DecorPlacer.begin(id: string, kind: string)
	stop()
	local plot = myPlot()
	local ground = plot and plot:FindFirstChild("Ground") :: BasePart?
	if not plot or not ground then
		return
	end
	placing = id
	local cf = ground.CFrame * CFrame.new(0, 0.5, 0)
	local used = ClientState.state.decor or {}
	for _, slot in DecorConfig.slots do
		if slot.kind == kind then
			local anchor = Instance.new("Part")
			anchor.Name = "DecorSlot_" .. slot.id
			anchor.Anchored = true
			anchor.CanCollide = false
			anchor.CanQuery = false
			anchor.Transparency = 1
			anchor.Size = Vector3.new(1, 1, 1)
			anchor.CFrame = cf * CFrame.new(slot.offset + Vector3.new(0, 2.5, 0))
			anchor.Parent = Workspace
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromOffset(56, 56)
			gui.AlwaysOnTop = true
			gui.MaxDistance = 140
			gui.Active = true
			gui.Adornee = anchor
			gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
			local button = Instance.new("TextButton")
			button.Size = UDim2.fromScale(1, 1)
			button.BackgroundColor3 = if used[slot.id]
				then Color3.fromRGB(200, 150, 60)
				else Color3.fromRGB(80, 160, 90)
			button.Text = if used[slot.id] then "⟳" else "+"
			button.TextScaled = true
			button.Font = Enum.Font.FredokaOne
			button.TextColor3 = Color3.new(1, 1, 1)
			button.Parent = gui
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = button
			button.Activated:Connect(function()
				Net.get("PlaceDecor"):FireServer(id, slot.id)
				stop()
			end)
			table.insert(markers, anchor)
			table.insert(markers, gui)
		end
	end
	cancelButton = UI.button({
		Name = "DecorCancel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -90),
		Size = UDim2.fromOffset(200, 50),
		Text = "✕ " .. ClientState.t("decor.cancel"),
		swatch = "stone",
		Parent = UI.screen(),
	}, stop)
end

return DecorPlacer
