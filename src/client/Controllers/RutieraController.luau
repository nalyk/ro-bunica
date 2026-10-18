--!strict
-- Rutiera pe client: în microbuz apare „Unde cobori?” (centrul, acasă, ograda fiecărui vecin, „Cobor aici”);
-- deasupra microbuzului, stația următoare; prompt-ul de urcare, tradus.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local ClientState = require(script.Parent.ClientState)
local UI = require(script.Parent.UI)

local RutieraController = {}

local localPlayer = Players.LocalPlayer
local panel: Frame
local scroll: ScrollingFrame
local riding = false
local destination: string? = nil

-- Numele omenesc al unei stații: „Centrul satului”, „Acasă”, „La Ion”
local function stopLabel(name: string): string
	if name == "centru" then
		return ClientState.t("rutiera.centru")
	end
	local index = tonumber(string.match(name, "^plot(%d+)$"))
	local village = Workspace:FindFirstChild("Village")
	local plot = index and village and village:FindFirstChild("Plot" .. index)
	if not plot then
		return name
	end
	local owner = plot:GetAttribute("OwnerUserId")
	if owner == localPlayer.UserId then
		return ClientState.t("rutiera.home")
	end
	local player = typeof(owner) == "number" and Players:GetPlayerByUserId(owner)
	if player then
		return ClientState.t("rutiera.plot", { player.DisplayName })
	end
	local sign = plot:FindFirstChild("Sign", true)
	local label = sign and sign:FindFirstChildWhichIsA("TextLabel", true)
	return ClientState.t(
		"rutiera.plot",
		{ if label and label.Text ~= "" then label.Text else "#" .. tostring(index) }
	)
end

RutieraController.stopLabel = stopLabel

local function render()
	UI.clear(scroll)
	UI.list(scroll, Enum.FillDirection.Vertical, 6)
	local order = 0
	local function add(text: string, swatch: string, onClick: () -> ())
		order += 1
		UI.button({
			Size = UDim2.new(1, -12, 0, 46),
			LayoutOrder = order,
			Text = text,
			swatch = swatch,
			Parent = scroll,
		}, onClick)
	end
	add(ClientState.t("rutiera.now"), "plum", function()
		Net.get("Rutiera"):FireServer("alight")
	end)
	local names = { "centru" }
	for index = 1, 8 do
		table.insert(names, "plot" .. index)
	end
	-- acasă primul, apoi centrul, apoi vecinii
	table.sort(names, function(a, b)
		local ha, hb =
			stopLabel(a) == ClientState.t("rutiera.home"), stopLabel(b) == ClientState.t("rutiera.home")
		if ha ~= hb then
			return ha
		end
		if (a == "centru") ~= (b == "centru") then
			return a == "centru"
		end
		return a < b
	end)
	for _, name in names do
		add(
			stopLabel(name) .. (if destination == name then "  ✓" else ""),
			if destination == name then "ie" else "sky",
			function()
				Net.get("Rutiera"):FireServer("destination", name)
			end
		)
	end
end

-- Pentru playtest
function RutieraController.debugState(): { [string]: any }
	return { riding = riding, destination = destination, visible = panel and panel.Visible }
end

local function decorate(vehicle: Instance)
	local body = vehicle:WaitForChild("Caroserie", 10) :: BasePart?
	if not body then
		return
	end
	local prompt = body:FindFirstChild("UrcaPrompt") :: ProximityPrompt?
	if prompt then
		prompt.ActionText = ClientState.t("rutiera.board")
		prompt.ObjectText = ClientState.t("rutiera.title")
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(220, 40)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	billboard.MaxDistance = 120
	billboard.Adornee = body
	billboard.Parent = vehicle
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard
	local function refresh()
		local next = vehicle:GetAttribute("RutieraNext")
		label.Text = if typeof(next) == "string"
			then ClientState.t("rutiera.next", { stopLabel(next) })
			else ""
	end
	vehicle:GetAttributeChangedSignal("RutieraNext"):Connect(refresh)
	refresh()
end

function RutieraController.start()
	panel, scroll = UI.panel(ClientState.t("rutiera.where"), function()
		UI.show(panel, false)
	end)
	Net.get("Rutiera").OnClientEvent:Connect(function(state: { riding: boolean, destination: string? })
		riding = state.riding
		destination = state.destination
		if riding then
			render()
		end
		UI.show(panel, riding)
	end)
	task.spawn(function()
		decorate(Workspace:WaitForChild("Rutiera"))
	end)
end

return RutieraController
