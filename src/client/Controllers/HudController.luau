--!strict
-- HUD-ul: lei, faza zilei cu timer, vremea, papucii și Nervii, butoanele și bara de semințe.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Defense = require(Shared.Config.Defense)
local GameState = require(Shared.GameState)
local Economy = require(Shared.Domain.Economy)
local ClientState = require(script.Parent.ClientState)
local UI = require(script.Parent.UI)
local ShopPanel = require(script.Parent.ShopPanel)
local CellarPanel = require(script.Parent.CellarPanel)
local SlipperController = require(script.Parent.SlipperController)

local HudController = {}

local leiLabel: TextLabel
local incomeLabel: TextLabel
local phaseLabel: TextLabel
local phasePill: Frame
local weatherLabel: TextLabel
local ammoLabel: TextLabel
local nerviFill: Frame
local pinButton: TextButton
local rageButton: TextButton
local seedBar: Frame
local familyLabel: TextLabel
local livePill: Frame
local liveLabel: TextLabel

local function buildTop(screen: ScreenGui)
	local money = UI.frame({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(260, 64),
		Parent = screen,
	})
	leiLabel = UI.label({
		Size = UDim2.new(1, -16, 0.62, 0),
		Position = UDim2.fromOffset(8, 2),
		Text = "0 lei",
		TextColor3 = UI.colors.ink,
		Parent = money,
	})
	incomeLabel = UI.label({
		Size = UDim2.new(1, -16, 0.34, 0),
		Position = UDim2.new(0, 8, 0.62, 0),
		Text = "",
		TextColor3 = UI.colors.green,
		Parent = money,
	})

	phasePill = UI.frame({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 78),
		Size = UDim2.fromOffset(200, 32),
		Parent = screen,
	})
	phaseLabel = UI.label({ Size = UDim2.fromScale(1, 1), Text = "", Parent = phasePill })

	livePill = UI.frame({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 144),
		Size = UDim2.fromOffset(300, 30),
		BackgroundColor3 = UI.colors.stitch,
		Visible = false,
		Parent = screen,
	})
	liveLabel = UI.label({
		Size = UDim2.new(1, -12, 1, -4),
		Position = UDim2.fromOffset(6, 2),
		Text = "",
		TextColor3 = UI.colors.linen,
		Parent = livePill,
	})

	weatherLabel = UI.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 114),
		Size = UDim2.fromOffset(260, 26),
		Text = "",
		TextColor3 = UI.colors.linen,
		TextStrokeTransparency = 0.3,
		Parent = screen,
	})
end

local function buildFamily(screen: ScreenGui)
	familyLabel = UI.label({
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(12, 60),
		Size = UDim2.fromOffset(260, 26),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.colors.linen,
		TextStrokeTransparency = 0.3,
		Parent = screen,
	})
end

-- Membrii familiei: jucătorii cu același FamilyId (pus de server)
local function renderFamily()
	local me = game:GetService("Players").LocalPlayer
	local id = me:GetAttribute("FamilyId")
	if id == nil then
		familyLabel.Text = ""
		return
	end
	local names = {}
	for _, player in game:GetService("Players"):GetPlayers() do
		if player ~= me and player:GetAttribute("FamilyId") == id then
			table.insert(names, player.DisplayName)
		end
	end
	familyLabel.Text = if #names > 0
		then "👪 " .. ClientState.t("ui.family", { table.concat(names, ", ") })
		else ""
end

local function buildLeft(screen: ScreenGui)
	local column = Instance.new("Frame")
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(0, 0.5)
	column.Position = UDim2.new(0, 10, 0.5, 0)
	column.Size = UDim2.fromOffset(110, 200)
	column.Parent = screen
	UI.list(column, Enum.FillDirection.Vertical, 8)
	UI.button(
		{ Size = UDim2.fromOffset(110, 56), Text = "🌱 " .. ClientState.t("ui.shop"), Parent = column },
		ShopPanel.toggle
	)
	UI.button(
		{ Size = UDim2.fromOffset(110, 56), Text = "🧺 " .. ClientState.t("ui.cellar"), Parent = column },
		CellarPanel.toggle
	)
	UI.button({
		Size = UDim2.fromOffset(110, 56),
		Text = "💃 " .. ClientState.t("ui.hora"),
		BackgroundColor3 = UI.colors.night,
		Parent = column,
	}, function()
		Net.get("Hora"):FireServer()
	end)
end

local function buildDefense(screen: ScreenGui)
	local box = UI.frame({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -10),
		Size = UDim2.fromOffset(190, 170),
		Parent = screen,
	})
	ammoLabel = UI.label({
		Size = UDim2.new(1, -12, 0, 36),
		Position = UDim2.fromOffset(6, 4),
		Text = "",
		Parent = box,
	})
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = UI.colors.stitchDark
	bar.Position = UDim2.fromOffset(10, 46)
	bar.Size = UDim2.new(1, -20, 0, 14)
	bar.Parent = box
	nerviFill = Instance.new("Frame")
	nerviFill.BackgroundColor3 = UI.colors.stitch
	nerviFill.BorderSizePixel = 0
	nerviFill.Size = UDim2.fromScale(0, 1)
	nerviFill.Parent = bar
	pinButton = UI.button({
		Position = UDim2.fromOffset(10, 68),
		Size = UDim2.new(1, -20, 0, 42),
		Text = "🥖 " .. ClientState.t("ui.rollingPin"),
		Parent = box,
	}, function()
		if (ClientState.state.nervi or 0) >= Defense.rollingPin.cost then
			SlipperController.arm(
				if SlipperController.armed() == "RollingPin" then "Slipper" else "RollingPin"
			)
		end
	end)
	rageButton = UI.button({
		Position = UDim2.fromOffset(10, 116),
		Size = UDim2.new(1, -20, 0, 44),
		Text = "😡 " .. ClientState.t("ui.rage"),
		Parent = box,
	}, function()
		if (ClientState.state.nervi or 0) >= Defense.rage.cost then
			Net.get("Rage"):FireServer()
		end
	end)
end

local function renderSeedBar()
	UI.clear(seedBar)
	local seeds = ClientState.state.seeds or {}
	local ids = {}
	for id in seeds do
		table.insert(ids, id)
	end
	table.sort(ids)
	for order, id in ids do
		local selected = ClientState.selectedSeed == id
		UI.button({
			Size = UDim2.fromOffset(120, 48),
			LayoutOrder = order,
			Text = ClientState.t("creature." .. id) .. " ×" .. seeds[id],
			BackgroundColor3 = if selected then UI.colors.gold else UI.colors.green,
			TextColor3 = if selected then UI.colors.ink else UI.colors.linen,
			Parent = seedBar,
		}, function()
			ClientState.selectedSeed = if selected then nil else id
			renderSeedBar()
		end)
	end
end

local function renderState()
	local state = ClientState.state
	leiLabel.Text = Economy.formatShort(state.lei or 0) .. " " .. ClientState.t("ui.lei")
	incomeLabel.Text = "+"
		.. ClientState.t("ui.perSecond", { Economy.formatShort(state.incomePerSecond or 0) })
	local nervi = state.nervi or 0
	nerviFill.Size = UDim2.fromScale(nervi / Defense.nervi.max, 1)
	pinButton.BackgroundColor3 = if SlipperController.armed() == "RollingPin"
		then UI.colors.gold
		elseif nervi >= Defense.rollingPin.cost then UI.colors.stitch
		else Color3.fromRGB(150, 150, 150)
	rageButton.BackgroundColor3 = if nervi >= Defense.rage.cost
		then UI.colors.stitch
		else Color3.fromRGB(150, 150, 150)
	renderSeedBar()
end

local function tickTimers()
	local now = Workspace:GetServerTimeNow()
	local phase = GameState.get(GameState.Attributes.Phase)
	local endsAt = GameState.get(GameState.Attributes.PhaseEndsAt) or now
	local isNight = phase == "Night"
	phaseLabel.Text = (
		if isNight then "🌙 " .. ClientState.t("ui.night") else "☀️ " .. ClientState.t("ui.day")
	)
		.. "  "
		.. UI.formatTime(endsAt - now)
	phasePill.BackgroundColor3 = if isNight then UI.colors.night else UI.colors.linen
	phaseLabel.TextColor3 = if isNight then UI.colors.linen else UI.colors.ink

	local weather = GameState.get(GameState.Attributes.Weather)
	if weather and weather ~= "" then
		local weatherEnds = GameState.get(GameState.Attributes.WeatherEndsAt) or now
		weatherLabel.Text = ClientState.t("weather." .. weather) .. "  " .. UI.formatTime(weatherEnds - now)
	else
		weatherLabel.Text = ""
	end

	renderFamily()
	local live = GameState.get("LiveEvent")
	if live and live ~= "" then
		local liveEnds = GameState.get("LiveEventEndsAt") or now
		liveLabel.Text = "😡 " .. ClientState.t("ui.liveEvent", { UI.formatTime(liveEnds - now) })
		livePill.Visible = true
	else
		livePill.Visible = false
	end
	local maxAmmo = ClientState.state.maxAmmo or Defense.slipper.maxAmmo
	local ammo = SlipperController.predictedAmmo()
	-- Text, nu emoji: 🩴 nu există în fontul Roblox (verificat în Studio)
	ammoLabel.Text = ClientState.t("ui.ammo", { ammo, maxAmmo })
end

function HudController.start()
	local screen = UI.screen()
	buildTop(screen)
	buildLeft(screen)
	buildFamily(screen)
	buildDefense(screen)

	seedBar = Instance.new("Frame")
	seedBar.BackgroundTransparency = 1
	seedBar.AnchorPoint = Vector2.new(0.5, 1)
	seedBar.Position = UDim2.new(0.5, 0, 1, -10)
	seedBar.Size = UDim2.new(0.6, 0, 0, 50)
	seedBar.Parent = screen
	UI.list(seedBar, Enum.FillDirection.Horizontal, 6)

	ClientState.onChanged(renderState)
	SlipperController.onArmedChanged(renderState)
	renderState()
	task.spawn(function()
		while true do
			tickTimers()
			task.wait(0.25)
		end
	end)
end

return HudController
