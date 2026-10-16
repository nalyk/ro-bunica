--!strict
-- HUD-ul: banii (contor animat), cadranul zilei cu timer, vremea și evenimentul live, butoanele rotunde din
-- stânga (semințe, beci, horă), apărarea din dreapta-jos (papucii ca muniție, nervii, făcălețul, furia)
-- și bara de semințe. Construit pe sistemul de design (Theme, Motion, UI.button).

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Defense = require(Shared.Config.Defense)
local GameState = require(Shared.GameState)
local Economy = require(Shared.Domain.Economy)
local ClientState = require(script.Parent.ClientState)
local Motion = require(script.Parent.Motion)
local Music = require(script.Parent.Music)
local Theme = require(script.Parent.Theme)
local Typography = require(Shared.Visual.Typography)
local UI = require(script.Parent.UI)
local ShopPanel = require(script.Parent.ShopPanel)
local CellarPanel = require(script.Parent.CellarPanel)
local SlipperController = require(script.Parent.SlipperController)

local HudController = {}

local leiLabel: TextLabel
local incomeLabel: TextLabel
local moneyPill: Frame
local phaseLabel: TextLabel
local phasePill: Frame
local phaseIcon: TextLabel
local weatherLabel: TextLabel
local slipperRow: Frame
local nerviFill: Frame
local pinButton: TextButton
local rageButton: TextButton
local seedBar: Frame
local familyLabel: TextLabel
local livePill: Frame
local liveLabel: TextLabel

local shownLei = 0 -- valoarea afișată (se „derulează” spre cea reală)

local function pill(props: { [string]: any }, swatchName: string): Frame
	local swatch = Theme.swatches[swatchName]
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = swatch.base
	frame.BorderSizePixel = 0
	for key, value in props do
		(frame :: any)[key] = value
	end
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.ink
	stroke.Thickness = Theme.stroke
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(225, 225, 225))
	gradient.Parent = frame
	return frame
end

local function outlined(label: TextLabel, color: Color3, thickness: number?): TextLabel
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 2
	stroke.Parent = label
	return label
end

local function buildTop(screen: ScreenGui)
	-- banii, stânga sus (sub bara Roblox): pastilă aurie cu moneda
	-- banii stau lângă cadranul zilei, sus la centru (stânga-sus e zona chatului Roblox)
	moneyPill = pill({
		Name = "Money",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0.5, -108, 0, 10),
		Size = UDim2.fromOffset(228, 62),
		Parent = screen,
	}, "wheat")
	local coin = UI.icon("lei", { Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(4, 3) })
	if coin then
		coin.Parent = moneyPill
	end
	leiLabel = outlined(
		UI.label({
			Position = UDim2.fromOffset(if coin then 62 else 14, 2),
			Size = UDim2.new(1, if coin then -72 else -24, 0.64, 0),
			Text = "0 lei",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Theme.paper,
			Parent = moneyPill,
		}),
		Theme.swatches.wheat.dark,
		2.5
	)
	incomeLabel = UI.label({
		Position = UDim2.new(0, if coin then 64 else 16, 0.62, 0),
		Size = UDim2.new(1, -80, 0.32, 0),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.swatches.vine.dark,
		FontFace = Typography.strong,
		Parent = moneyPill,
	})

	-- cadranul zilei, sus la centru
	phasePill = pill({
		Name = "Phase",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(196, 46),
		Parent = screen,
	}, "paper")
	phaseIcon = UI.label({
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.fromOffset(6, 3),
		Text = "",
		Parent = phasePill,
	})
	phaseLabel = UI.label({
		Position = UDim2.fromOffset(48, 4),
		Size = UDim2.new(1, -58, 1, -8),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = phasePill,
	})

	weatherLabel = outlined(
		UI.label({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 62),
			Size = UDim2.fromOffset(280, 26),
			Text = "",
			TextColor3 = Theme.paper,
			Parent = screen,
		}),
		Theme.ink
	)

	livePill = pill({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 144),
		Size = UDim2.fromOffset(320, 34),
		Visible = false,
		Parent = screen,
	}, "ie")
	liveLabel = outlined(
		UI.label({
			Size = UDim2.new(1, -16, 1, -6),
			Position = UDim2.fromOffset(8, 3),
			Text = "",
			TextColor3 = Theme.paper,
			Parent = livePill,
		}),
		Theme.swatches.ie.dark
	)
end

local function buildFamily(screen: ScreenGui)
	familyLabel = outlined(
		UI.label({
			Position = UDim2.fromOffset(14, 78),
			Size = UDim2.fromOffset(260, 24),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Theme.paper,
			Parent = screen,
		}),
		Theme.ink
	)
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

-- Buton rotund cu iconiță mare și eticheta dedesubt (semințe, beci, horă)
local function roundButton(
	parent: Instance,
	order: number,
	icon: string,
	emoji: string,
	text: string,
	swatch: string,
	onClick: () -> ()
)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(84, 100)
	holder.LayoutOrder = order
	holder.Parent = parent
	local hasIcon = UI.icon(icon) ~= nil
	local button = UI.button({
		Size = UDim2.fromOffset(76, 76),
		Position = UDim2.fromOffset(4, 0),
		swatch = swatch,
		icon = icon,
		Text = if hasIcon then "" else emoji,
		Parent = holder,
	}, onClick)
	local corner = button:FindFirstChildOfClass("UICorner") :: UICorner
	corner.CornerRadius = UDim.new(0.5, 0)
	local lip = button:FindFirstChild("Lip") :: Frame
	local lipCorner = lip:FindFirstChildOfClass("UICorner") :: UICorner
	lipCorner.CornerRadius = UDim.new(0.5, 0)
	outlined(
		UI.label({
			Position = UDim2.fromOffset(0, 80),
			Size = UDim2.fromOffset(84, 20),
			Text = text,
			TextColor3 = Theme.paper,
			Parent = holder,
		}),
		Theme.ink
	)
	return button
end

local function buildLeft(screen: ScreenGui)
	local column = Instance.new("Frame")
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(0, 0.5)
	column.Position = UDim2.new(0, 8, 0.5, 0)
	column.Size = UDim2.fromOffset(88, 320)
	column.Parent = screen
	UI.list(column, Enum.FillDirection.Vertical, 6)
	roundButton(column, 1, "seeds", "🌱", ClientState.t("ui.shop"), "vine", ShopPanel.toggle)
	roundButton(column, 2, "cellar", "🧺", ClientState.t("ui.cellar"), "wheat", CellarPanel.toggle)
	roundButton(column, 3, "hora", "💃", ClientState.t("ui.hora"), "plum", function()
		Net.get("Hora"):FireServer()
	end)
end

local function buildDefense(screen: ScreenGui)
	local box = pill({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -14),
		Size = UDim2.fromOffset(212, 150),
		Parent = screen,
	}, "paper")
	local boxCorner = box:FindFirstChildOfClass("UICorner") :: UICorner
	boxCorner.CornerRadius = UDim.new(0, 22)
	-- muniția: un papuc desenat pentru fiecare aruncare disponibilă
	slipperRow = Instance.new("Frame")
	slipperRow.BackgroundTransparency = 1
	slipperRow.Position = UDim2.fromOffset(10, 6)
	slipperRow.Size = UDim2.new(1, -20, 0, 44)
	slipperRow.Parent = box
	UI.list(slipperRow, Enum.FillDirection.Horizontal, 6)
	-- nervii Bunicii
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = Theme.paperDeep
	bar.Position = UDim2.fromOffset(12, 56)
	bar.Size = UDim2.new(1, -24, 0, 16)
	bar.Parent = box
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0.5, 0)
	barCorner.Parent = bar
	local barStroke = Instance.new("UIStroke")
	barStroke.Color = Theme.ink
	barStroke.Thickness = 2
	barStroke.Parent = bar
	nerviFill = Instance.new("Frame")
	nerviFill.BackgroundColor3 = Theme.swatches.ie.base
	nerviFill.BorderSizePixel = 0
	nerviFill.Size = UDim2.fromScale(0, 1)
	nerviFill.Parent = bar
	barCorner:Clone().Parent = nerviFill
	pinButton = UI.button({
		Position = UDim2.fromOffset(10, 82),
		Size = UDim2.new(0.5, -14, 0, 56),
		icon = "rollingpin",
		Text = ClientState.t("ui.rollingPin"),
		swatch = "wheat",
		Parent = box,
	}, function()
		if (ClientState.state.nervi or 0) >= Defense.rollingPin.cost then
			SlipperController.arm(
				if SlipperController.armed() == "RollingPin" then "Slipper" else "RollingPin"
			)
		end
	end)
	rageButton = UI.button({
		Position = UDim2.new(0.5, 4, 0, 82),
		Size = UDim2.new(0.5, -14, 0, 56),
		icon = "rage",
		Text = ClientState.t("ui.rage"),
		swatch = "ie",
		Parent = box,
	}, function()
		if (ClientState.state.nervi or 0) >= Defense.rage.cost then
			Net.get("Rage"):FireServer()
		end
	end)
end

local function renderSlippers(ammo: number, maxAmmo: number)
	if #slipperRow:GetChildren() - 1 ~= maxAmmo then
		UI.clear(slipperRow)
		for i = 1, maxAmmo do
			local icon = UI.icon(
				"slipper",
				{ Size = UDim2.fromOffset(44, 44), LayoutOrder = i, Name = "Slipper" .. i }
			)
			local item: GuiObject = icon
				or UI.label({
					Size = UDim2.fromOffset(44, 44),
					LayoutOrder = i,
					Text = "👞",
					Name = "Slipper" .. i,
				})
			item.Parent = slipperRow
		end
	end
	for i = 1, maxAmmo do
		local item = slipperRow:FindFirstChild("Slipper" .. i) :: GuiObject?
		if item then
			local full = i <= ammo
			if item:IsA("ImageLabel") then
				item.ImageTransparency = if full then 0 else 0.7
				item.ImageColor3 = if full then Color3.new(1, 1, 1) else Color3.fromRGB(90, 90, 90)
			elseif item:IsA("TextLabel") then
				item.TextTransparency = if full then 0 else 0.7
			end
		end
	end
	-- textul accesibil (și citit de teste): „Papuci: 2/3”
	slipperRow:SetAttribute("Ammo", ammo)
	local caption = slipperRow:FindFirstChild("AmmoText") :: TextLabel?
	if not caption then
		caption = UI.label({
			Name = "AmmoText",
			Size = UDim2.fromOffset(60, 44),
			LayoutOrder = 99,
			TextColor3 = Theme.ink,
			Parent = slipperRow,
		})
	end
	local ammoText = caption :: TextLabel
	ammoText.Text = ClientState.t("ui.ammo", { ammo, maxAmmo })
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
			Size = UDim2.fromOffset(150, 50),
			LayoutOrder = order,
			Text = ClientState.t("creature." .. id) .. " ×" .. seeds[id],
			swatch = if selected then "wheat" else "vine",
			Parent = seedBar,
		}, function()
			ClientState.selectedSeed = if selected then nil else id
			renderSeedBar()
		end)
	end
end

-- Monede care zboară din mijlocul ecranului spre pastila banilor (pe o curbă), cu „clinc” la sosire
local function flyCoins(count: number)
	local screen = UI.screen()
	local target = moneyPill.AbsolutePosition + Vector2.new(32, 32)
	local viewport = screen.AbsoluteSize
	for i = 1, count do
		task.delay((i - 1) * 0.07, function()
			local coin: GuiObject = UI.icon(
				"lei",
				{ Size = UDim2.fromOffset(40, 40), AnchorPoint = Vector2.new(0.5, 0.5) }
			) or UI.label({
				Size = UDim2.fromOffset(40, 40),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Text = "🪙",
			})
			coin.ZIndex = 50
			local start =
				Vector2.new(viewport.X * 0.5 + math.random(-60, 60), viewport.Y * 0.55 + math.random(-30, 30))
			local control = Vector2.new(
				(start.X + target.X) * 0.5 + math.random(-80, 80),
				math.min(start.Y, target.Y) - 120
			)
			coin.Position = UDim2.fromOffset(start.X, start.Y)
			coin.Parent = screen
			Motion.spring(coin, 1, function(t)
				local u = math.clamp(t, 0, 1)
				local a = start:Lerp(control, u)
				local b = control:Lerp(target, u)
				local p = a:Lerp(b, u)
				coin.Position = UDim2.fromOffset(p.X, p.Y)
				if u >= 0.98 and coin.Parent then
					coin:Destroy()
				end
			end, Motion.presets.gentle, 0)
			task.delay(0.55, function()
				if coin.Parent then
					coin:Destroy()
				end
				Music.cue("coin", { volume = 0.5, pitch = (i % 3) * 2 })
				Motion.pop(moneyPill)
			end)
		end)
	end
end

local function setLei(value: number)
	shownLei = value
	leiLabel.Text = Economy.formatShort(math.floor(value + 0.5)) .. " " .. ClientState.t("ui.lei")
end

local function renderState()
	local state = ClientState.state
	local lei = state.lei or 0
	local income = state.incomePerSecond or 0
	if lei - shownLei > math.max(income * 3, 25) and shownLei > 0 then
		flyCoins(math.clamp(math.floor((lei - shownLei) / math.max(income * 3, 25)) + 3, 3, 10))
	end
	if lei > shownLei + 0.5 then
		-- banii cresc: cifra se derulează, iar pastila „sare”
		local from = shownLei
		Motion.spring(leiLabel, lei, setLei, Motion.presets.gentle, from)
		Motion.pop(moneyPill)
	else
		setLei(lei)
	end
	incomeLabel.Text = "+"
		.. ClientState.t("ui.perSecond", { Economy.formatShort(state.incomePerSecond or 0) })
	local nervi = state.nervi or 0
	nerviFill.Size = UDim2.fromScale(math.clamp(nervi / Defense.nervi.max, 0, 1), 1)
	UI.setSwatch(
		pinButton,
		if SlipperController.armed() == "RollingPin"
			then "sky"
			elseif nervi >= Defense.rollingPin.cost then "wheat"
			else "stone"
	)
	UI.setSwatch(rageButton, if nervi >= Defense.rage.cost then "ie" else "stone")
	renderSeedBar()
end

local function tickTimers()
	local now = Workspace:GetServerTimeNow()
	local phase = GameState.get(GameState.Attributes.Phase)
	local endsAt = GameState.get(GameState.Attributes.PhaseEndsAt) or now
	local isNight = phase == "Night"
	phaseIcon.Text = if isNight then "🌙" else "☀️"
	phaseLabel.Text = (if isNight then ClientState.t("ui.night") else ClientState.t("ui.day"))
		.. "  "
		.. UI.formatTime(endsAt - now)
	phasePill.BackgroundColor3 = if isNight then Theme.swatches.plum.base else Theme.paper
	phaseLabel.TextColor3 = if isNight then Theme.paper else Theme.ink

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
		if not livePill.Visible then
			livePill.Visible = true
			Motion.pop(livePill)
		end
	else
		livePill.Visible = false
	end
	local maxAmmo = ClientState.state.maxAmmo or Defense.slipper.maxAmmo
	renderSlippers(SlipperController.predictedAmmo(), maxAmmo)
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
	seedBar.Position = UDim2.new(0.5, 0, 1, -14)
	seedBar.Size = UDim2.new(0.6, 0, 0, 56)
	seedBar.Parent = screen
	UI.list(seedBar, Enum.FillDirection.Horizontal, 8)

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
