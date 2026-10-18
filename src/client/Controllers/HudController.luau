--!strict
-- HUD-ul, în două așezări (Layout): desktop (PC, consolă) și tactil (telefon, tabletă).
-- Desktop: banii și ziua sus la centru, coloana de butoane rotunde în stânga, cutia de apărare dreapta-jos.
-- Tactil (geometria în Domain/HudLayout, testată): rândul de butoane sus-stânga cu meniul „Mai mult”, banii
-- și ziua sus-dreapta, apărarea lângă butonul de săritură al Roblox (Furia, făcălețul, papucii), bara de
-- semințe în banda liberă de jos; nimic interactiv în zona joystick-ului sau peste săritură.

local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Defense = require(Shared.Config.Defense)
local GameState = require(Shared.GameState)
local Economy = require(Shared.Domain.Economy)
local HudLayout = require(Shared.Domain.HudLayout)
local ClientState = require(script.Parent.ClientState)
local Layout = require(script.Parent.Layout)
local Motion = require(script.Parent.Motion)
local Music = require(script.Parent.Music)
local Theme = require(script.Parent.Theme)
local Typography = require(Shared.Visual.Typography)
local UI = require(script.Parent.UI)
local ShopPanel = require(script.Parent.ShopPanel)
local CellarPanel = require(script.Parent.CellarPanel)
local UpgradePanel = require(script.Parent.UpgradePanel)
local NotebookPanel = require(script.Parent.NotebookPanel)
local FriendsPanel = require(script.Parent.FriendsPanel)
local MinigameController = require(script.Parent.MinigameController)
local StorePanel = require(script.Parent.StorePanel)
local SlipperController = require(script.Parent.SlipperController)

local HudController = {}

-- Acțiunile HUD-ului și butoanele lor, pentru gamepad (GamepadController leagă tastele și pune glifele)
HudController.actions = {} :: { [string]: () -> () }
HudController.buttons = {} :: { [string]: GuiObject }

-- Ordinea butoanelor: în coloana de desktop și în rândul tactil (+ „Mai mult”, cu restul în meniu)
local DESKTOP_ACTIONS = { "shop", "cellar", "hora", "upgrades", "notebook", "games", "friends" }
local TOUCH_ACTIONS = { "shop", "cellar", "upgrades", "notebook", "more" }
local MENU_ITEMS = { "games", "hora", "friends", "store" }
assert(
	#TOUCH_ACTIONS == HudLayout.TOUCH_ACTIONS and #MENU_ITEMS == HudLayout.MENU_ITEMS,
	"HudLayout: numărul de butoane"
)

local leiLabel: TextLabel
local incomeLabel: TextLabel
local moneyPill: Frame
local topGroup: Frame
local topScale: UIScale
local phaseLabel: TextLabel
local phasePill: Frame
local phaseIcon: TextLabel
local weatherLabel: TextLabel
local livePill: Frame
local liveLabel: TextLabel
local column: Frame
local columnScale: UIScale
local touchRow: Frame
local menu: Frame
local holders: { [string]: Frame } = {}
local storePlus: TextButton
local defenseBox: Frame
local touchDefense: Frame
local seedBar: ScrollingFrame
local seedShown = ""
local touchMode = false

-- O „vedere” a apărării: cutia de pe desktop sau grupul tactil de lângă săritură
type DefenseView = { slipperRow: Frame, nerviFill: Frame, pin: TextButton, rage: TextButton, icon: number }
local views: { DefenseView } = {}

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

local function buildTop(screen: Frame)
	-- banii și ziua, într-un grup care se poate micșora (UIScale) și muta (sus la centru sau sus-dreapta)
	topGroup = Instance.new("Frame")
	topGroup.Name = "Status"
	topGroup.BackgroundTransparency = 1
	topGroup.Size = UDim2.fromOffset(HudLayout.STATUS_SIZE.w, HudLayout.STATUS_SIZE.h)
	topGroup.Parent = screen
	topScale = Instance.new("UIScale")
	topScale.Parent = topGroup
	moneyPill = pill({
		Name = "Money",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(228, 62),
		Parent = topGroup,
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
	-- „+” pe pilula banilor: magazinul pe Robux
	local plus = UI.button({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 1, -6),
		Size = UDim2.fromOffset(34, 34),
		Text = "+",
		swatch = "vine",
		Parent = moneyPill,
	}, StorePanel.toggle)
	local plusCorner = plus:FindFirstChildOfClass("UICorner") :: UICorner
	plusCorner.CornerRadius = UDim.new(0.5, 0)
	HudController.actions.store = StorePanel.toggle
	HudController.buttons.store = plus
	storePlus = plus
	incomeLabel = UI.label({
		Position = UDim2.new(0, if coin then 64 else 16, 0.62, 0),
		Size = UDim2.new(1, -80, 0.32, 0),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.swatches.vine.dark,
		FontFace = Typography.strong,
		Parent = moneyPill,
	})

	phasePill = pill({
		Name = "Phase",
		Position = UDim2.fromOffset(240, 8),
		Size = UDim2.fromOffset(196, 46),
		Parent = topGroup,
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
			Text = "",
			TextColor3 = Theme.paper,
			Parent = screen,
		}),
		Theme.ink
	)

	livePill = pill({
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

-- Buton rotund cu iconiță mare și eticheta dedesubt (pe desktop); pe ecran tactil, doar cercul
local function roundButton(
	icon: string,
	emoji: string,
	text: string,
	swatch: string,
	onClick: () -> ()
): (TextButton, Frame)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(84, 100)
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
	local label = outlined(
		UI.label({
			Name = "Caption",
			Position = UDim2.fromOffset(0, 80),
			Size = UDim2.fromOffset(84, 20),
			Text = text,
			TextColor3 = Theme.paper,
			Parent = holder,
		}),
		Theme.ink
	)
	local _ = label
	return button, holder
end

-- Desktop: 84×100 cu eticheta; tactil: doar cercul, de mărimea dată
local function shapeHolder(holder: Frame, touch: boolean, size: number)
	local button = holder:FindFirstChildWhichIsA("TextButton") :: TextButton
	local caption = holder:FindFirstChild("Caption") :: TextLabel
	if touch then
		holder.Size = UDim2.fromOffset(size, size)
		button.Size = UDim2.fromOffset(size, size)
		button.Position = UDim2.fromOffset(0, 0)
		caption.Visible = false
	else
		holder.Size = UDim2.fromOffset(84, 100)
		button.Size = UDim2.fromOffset(76, 76)
		button.Position = UDim2.fromOffset(4, 0)
		caption.Visible = true
	end
end

local function hideMenu()
	if menu then
		menu.Visible = false
	end
end

local COLUMN_HEIGHT = 742 -- 7 butoane rotunde (100) cu spațiu între ele

local function buildActions(screen: Frame)
	column = Instance.new("Frame")
	column.Name = "Column"
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(0, 0.5)
	column.Position = UDim2.new(0, 8, 0.5, 0)
	column.Size = UDim2.fromOffset(88, COLUMN_HEIGHT)
	columnScale = Instance.new("UIScale")
	columnScale.Parent = column
	column.Parent = screen
	UI.list(column, Enum.FillDirection.Vertical, 6)

	touchRow = Instance.new("Frame")
	touchRow.Name = "TouchRow"
	touchRow.BackgroundTransparency = 1
	touchRow.Size = UDim2.fromScale(1, 1)
	touchRow.Visible = false
	touchRow.Parent = screen

	local function hora()
		Net.get("Hora"):FireServer()
	end
	local defs: { [string]: { icon: string, emoji: string, text: string, swatch: string, action: () -> () } } =
		{
			shop = {
				icon = "seeds",
				emoji = "🌱",
				text = "ui.shop",
				swatch = "vine",
				action = ShopPanel.toggle,
			},
			cellar = {
				icon = "cellar",
				emoji = "🧺",
				text = "ui.cellar",
				swatch = "wheat",
				action = CellarPanel.toggle,
			},
			hora = { icon = "hora", emoji = "💃", text = "ui.hora", swatch = "plum", action = hora },
			upgrades = {
				icon = "yard",
				emoji = "🔨",
				text = "ui.upgrades",
				swatch = "sky",
				action = UpgradePanel.toggle,
			},
			notebook = {
				icon = "notebook",
				emoji = "📖",
				text = "ui.notebook",
				swatch = "paper",
				action = NotebookPanel.toggle,
			},
			friends = {
				icon = "family",
				emoji = "👪",
				text = "ui.friends",
				swatch = "ie",
				action = FriendsPanel.toggle,
			},
			games = {
				icon = "",
				emoji = "🎲",
				text = "minigame.title",
				swatch = "sky",
				action = MinigameController.toggle,
			},
		}
	for order, id in DESKTOP_ACTIONS do
		local def = defs[id]
		local function run()
			hideMenu()
			def.action()
		end
		local button, holder = roundButton(def.icon, def.emoji, ClientState.t(def.text), def.swatch, run)
		holder.LayoutOrder = order
		holder.Parent = column
		holders[id] = holder
		HudController.actions[id] = def.action
		HudController.buttons[id] = button
	end

	-- „Mai mult” (doar pe ecran tactil) și meniul lui: Mini-jocuri, Horă, Prieteni, Magazin, cu etichete
	local _, moreHolder = roundButton("", "•••", ClientState.t("ui.more"), "stone", function()
		menu.Visible = not menu.Visible
		if menu.Visible then
			Motion.pop(menu)
		end
	end)
	moreHolder.Parent = touchRow
	holders.more = moreHolder
	menu = UI.frame({
		Name = "MoreMenu",
		BackgroundColor3 = Theme.paper,
		Visible = false,
		ZIndex = 9,
		Parent = screen,
	})
	local menuLayout = UI.list(menu, Enum.FillDirection.Vertical, 6)
	menuLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	menuLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	local menuDefs: { [string]: { icon: string, text: string, swatch: string, action: () -> () } } = {
		hora = { icon = "hora", text = "ui.hora", swatch = "plum", action = hora },
		friends = { icon = "family", text = "ui.friends", swatch = "ie", action = FriendsPanel.toggle },
		store = { icon = "lei", text = "ui.store", swatch = "wheat", action = StorePanel.toggle },
		games = { icon = "", text = "minigame.title", swatch = "sky", action = MinigameController.toggle },
	}
	for order, id in MENU_ITEMS do
		local def = menuDefs[id]
		UI.button({
			Name = "Menu_" .. id,
			LayoutOrder = order,
			Size = UDim2.new(1, -12, 0, 46),
			Text = ClientState.t(def.text),
			icon = def.icon,
			swatch = def.swatch,
			Parent = menu,
		}, function()
			hideMenu()
			def.action()
		end)
	end
	-- o atingere în afara meniului îl închide
	UserInputService.InputBegan:Connect(function(input)
		if not menu.Visible then
			return
		end
		if
			input.UserInputType ~= Enum.UserInputType.Touch
			and input.UserInputType ~= Enum.UserInputType.MouseButton1
		then
			return
		end
		local point = Vector2.new(input.Position.X, input.Position.Y)
		for _, area in { menu, moreHolder } :: { GuiObject } do
			local from, size = area.AbsolutePosition, area.AbsoluteSize
			if
				point.X >= from.X
				and point.X <= from.X + size.X
				and point.Y >= from.Y
				and point.Y <= from.Y + size.Y
			then
				return
			end
		end
		task.defer(hideMenu)
	end)
	-- compatibilitate: gamepad-ul și testele cheamă prietenii prin „invite”
	HudController.actions.invite = FriendsPanel.invite
end

local function nerviBar(parent: Frame, position: UDim2, size: UDim2, caption: string?): Frame
	local bar = Instance.new("Frame")
	bar.Name = "Nervi"
	bar.BackgroundColor3 = Theme.paperDeep
	bar.Position = position
	bar.Size = size
	bar.Parent = parent
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0.5, 0)
	barCorner.Parent = bar
	local barStroke = Instance.new("UIStroke")
	barStroke.Color = Theme.ink
	barStroke.Thickness = 2
	barStroke.Parent = bar
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Theme.swatches.ie.base
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = bar
	barCorner:Clone().Parent = fill
	if caption then
		UI.capText(
			UI.label({
				Name = "Caption",
				Size = UDim2.fromScale(1, 1),
				Text = caption,
				TextColor3 = Theme.ink,
				ZIndex = 2,
				Parent = bar,
			}),
			14
		)
	end
	return fill
end

local function togglePin()
	if (ClientState.state.nervi or 0) >= Defense.rollingPin.cost then
		SlipperController.arm(if SlipperController.armed() == "RollingPin" then "Slipper" else "RollingPin")
	end
end

local function rage()
	if (ClientState.state.nervi or 0) >= Defense.rage.cost then
		Net.get("Rage"):FireServer()
	end
end

local function roundify(button: TextButton)
	local corner = button:FindFirstChildOfClass("UICorner") :: UICorner
	corner.CornerRadius = UDim.new(0.5, 0)
	local lip = button:FindFirstChild("Lip") :: Frame
	(lip:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius = UDim.new(0.5, 0)
end

local function buildDefense(screen: Frame)
	-- desktop: cutia cu papucii, nervii (cu etichetă), făcălețul și furia
	defenseBox = pill({
		Name = "DefenseBox",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -14),
		Size = UDim2.fromOffset(HudLayout.defenseBoxWidth(Defense.slipper.maxAmmo), 154),
		Parent = screen,
	}, "paper")
	local boxCorner = defenseBox:FindFirstChildOfClass("UICorner") :: UICorner
	boxCorner.CornerRadius = UDim.new(0, 22)
	local slipperRow = Instance.new("Frame")
	slipperRow.Name = "Slippers"
	slipperRow.BackgroundTransparency = 1
	slipperRow.Position = UDim2.fromOffset(10, 6)
	slipperRow.Size = UDim2.new(1, -20, 0, 44)
	slipperRow.Parent = defenseBox
	UI.list(slipperRow, Enum.FillDirection.Horizontal, 6)
	local fill =
		nerviBar(defenseBox, UDim2.fromOffset(12, 54), UDim2.new(1, -24, 0, 22), ClientState.t("ui.nervi"))
	local pin = UI.button({
		Position = UDim2.fromOffset(10, 86),
		Size = UDim2.new(0.5, -14, 0, 56),
		icon = "rollingpin",
		Text = ClientState.t("ui.rollingPin"),
		swatch = "wheat",
		Parent = defenseBox,
	}, togglePin)
	local rageButton = UI.button({
		Position = UDim2.new(0.5, 4, 0, 86),
		Size = UDim2.new(0.5, -14, 0, 56),
		icon = "rage",
		Text = ClientState.t("ui.rage"),
		swatch = "ie",
		Parent = defenseBox,
	}, rage)
	table.insert(
		views,
		{ slipperRow = slipperRow, nerviFill = fill, pin = pin, rage = rageButton, icon = 44 }
	)
	HudController.actions.pin = togglePin
	HudController.actions.rage = rage
	HudController.buttons.pin = pin
	HudController.buttons.rage = rageButton
	HudController.buttons.throw = defenseBox -- nu rândul de papuci: renderSlippers îl golește

	-- tactil: butoane rotunde lângă săritură și pastila muniției deasupra ei
	touchDefense = Instance.new("Frame")
	touchDefense.Name = "TouchDefense"
	touchDefense.BackgroundTransparency = 1
	touchDefense.Size = UDim2.fromScale(1, 1)
	touchDefense.Visible = false
	touchDefense.Parent = screen
	local touchPin = UI.button(
		{ Name = "TouchPin", icon = "rollingpin", swatch = "wheat", Parent = touchDefense },
		togglePin
	)
	local touchRage =
		UI.button({ Name = "TouchRage", icon = "rage", swatch = "ie", Parent = touchDefense }, rage)
	roundify(touchPin)
	roundify(touchRage)
	local ammo = pill({ Name = "Ammo", Parent = touchDefense }, "paper")
	local ammoCorner = ammo:FindFirstChildOfClass("UICorner") :: UICorner
	ammoCorner.CornerRadius = UDim.new(0, 14)
	local touchSlippers = Instance.new("Frame")
	touchSlippers.Name = "Slippers"
	touchSlippers.BackgroundTransparency = 1
	touchSlippers.Position = UDim2.fromOffset(8, 3)
	touchSlippers.Size = UDim2.new(1, -16, 0.5, 0)
	touchSlippers.Parent = ammo
	UI.list(touchSlippers, Enum.FillDirection.Horizontal, 3)
	local touchFill =
		nerviBar(ammo, UDim2.new(0, 10, 0.56, 0), UDim2.new(1, -20, 0.36, 0), ClientState.t("ui.nervi"))
	table.insert(
		views,
		{ slipperRow = touchSlippers, nerviFill = touchFill, pin = touchPin, rage = touchRage, icon = 22 }
	)
end

local function renderSlippers(view: DefenseView, ammo: number, maxAmmo: number)
	local row = view.slipperRow
	if row:GetAttribute("Max") ~= maxAmmo or row:GetAttribute("Icon") ~= view.icon then
		row:SetAttribute("Max", maxAmmo)
		row:SetAttribute("Icon", view.icon)
		UI.clear(row)
		-- pe desktop, cu mulți papuci, iconițele se strâng ca să încapă în cutie
		local size = if view.icon >= 44 and maxAmmo > 3 then 36 else view.icon
		for i = 1, maxAmmo do
			local icon = UI.icon(
				"slipper",
				{ Size = UDim2.fromOffset(size, size), LayoutOrder = i, Name = "Slipper" .. i }
			)
			local item: GuiObject = icon
				or UI.label({
					Size = UDim2.fromOffset(size, size),
					LayoutOrder = i,
					Text = "👞",
					Name = "Slipper" .. i,
				})
			item.Parent = row
		end
		if row.Parent == defenseBox then
			defenseBox.Size = UDim2.fromOffset(HudLayout.defenseBoxWidth(maxAmmo), 154)
		end
	end
	for i = 1, maxAmmo do
		local item = row:FindFirstChild("Slipper" .. i) :: GuiObject?
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
	-- textul accesibil (și citit de teste): „Papuci: 2/3” pe desktop, „2/3” pe ecranul tactil
	row:SetAttribute("Ammo", ammo)
	local caption = row:FindFirstChild("AmmoText") :: TextLabel?
	if not caption then
		caption = UI.label({
			Name = "AmmoText",
			Size = UDim2.fromOffset(if view.icon >= 44 then 60 else 34, view.icon),
			LayoutOrder = 99,
			TextColor3 = Theme.ink,
			Parent = row,
		})
	end
	local ammoText = caption :: TextLabel
	ammoText.Text = if view.icon >= 44
		then ClientState.t("ui.ammo", { ammo, maxAmmo })
		else string.format("%d/%d", ammo, maxAmmo)
end

local function renderSeedBar()
	local seeds = ClientState.state.seeds or {}
	local ids = {}
	for id in seeds do
		table.insert(ids, id)
	end
	table.sort(ids)
	local parts =
		{ tostring(touchMode), tostring(ClientState.selectedSeed), tostring(seedBar.AbsoluteSize.Y) }
	for _, id in ids do
		table.insert(parts, id .. seeds[id])
	end
	local signature = table.concat(parts, ",")
	if signature == seedShown then
		return
	end
	seedShown = signature
	UI.clear(seedBar)
	local height = if touchMode then math.max(seedBar.AbsoluteSize.Y - 6, 36) else 50
	local width = if touchMode then 128 else 150
	for order, id in ids do
		local selected = ClientState.selectedSeed == id
		UI.button({
			Size = UDim2.fromOffset(width, height),
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
	for _, view in views do
		view.nerviFill.Size = UDim2.fromScale(math.clamp(nervi / Defense.nervi.max, 0, 1), 1)
		UI.setSwatch(
			view.pin,
			if SlipperController.armed() == "RollingPin"
				then "sky"
				elseif nervi >= Defense.rollingPin.cost then "wheat"
				else "stone"
		)
		UI.setSwatch(view.rage, if nervi >= Defense.rage.cost then "ie" else "stone")
	end
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
	for _, view in views do
		renderSlippers(view, SlipperController.predictedAmmo(), maxAmmo)
	end
end

local function place(object: GuiObject, rect: HudLayout.Rect)
	object.AnchorPoint = Vector2.zero
	object.Position = UDim2.fromOffset(rect.x, rect.y)
	object.Size = UDim2.fromOffset(rect.w, rect.h)
end

-- Așezarea curentă (pentru teste): modul și dreptunghiurile tactile, dacă e cazul
HudController.layout = nil :: HudLayout.TouchLayout?

local function applyLayout()
	local size = Layout.size()
	touchMode = Layout.isTouch()
	hideMenu()
	if touchMode then
		local layout = HudLayout.touch(size.X, size.Y, Layout.jump(), #TOUCH_ACTIONS, #MENU_ITEMS)
		HudController.layout = layout
		topGroup.AnchorPoint = Vector2.zero
		topGroup.Position = UDim2.fromOffset(layout.status.x, layout.status.y)
		topScale.Scale = layout.statusScale
		place(weatherLabel, layout.info)
		weatherLabel.TextXAlignment = Enum.TextXAlignment.Right
		place(livePill, {
			x = layout.info.x,
			y = layout.info.y + layout.info.h + 4,
			w = layout.info.w,
			h = layout.info.h + 6,
		})
		storePlus.Visible = false -- prea mic pentru deget la scara stării; magazinul e în meniul „Mai mult”
		-- micșorată, cifra venitului ar ieși sub 11 px: pe ecran tactil îi dăm mai mult loc în pastilă
		leiLabel.Size = UDim2.new(1, -72, 0.56, 0)
		incomeLabel.Position = UDim2.new(0, 64, 0.54, 0)
		incomeLabel.Size = UDim2.new(1, -80, 0.42, 0)
		column.Visible = false
		touchRow.Visible = true
		for index, id in TOUCH_ACTIONS do
			local holder = holders[id]
			local rect = layout.actions[index]
			holder.Parent = touchRow
			shapeHolder(holder, true, rect.w)
			holder.Position = UDim2.fromOffset(rect.x, rect.y)
		end
		place(menu, layout.menu)
		for _, child in menu:GetChildren() do
			if child:IsA("TextButton") then
				child.Size = UDim2.new(1, -12, 0, layout.actions[1].h)
			end
		end
		defenseBox.Visible = false
		touchDefense.Visible = true
		place(touchDefense:FindFirstChild("TouchRage") :: GuiObject, layout.rage)
		place(touchDefense:FindFirstChild("TouchPin") :: GuiObject, layout.pin)
		place(touchDefense:FindFirstChild("Ammo") :: GuiObject, layout.ammo)
		place(seedBar, layout.seeds)
	else
		HudController.layout = nil
		topGroup.AnchorPoint = Vector2.new(0.5, 0)
		topGroup.Position = UDim2.new(0.5, 0, 0, 10)
		topScale.Scale = 1
		weatherLabel.AnchorPoint = Vector2.new(0.5, 0)
		weatherLabel.Position = UDim2.new(0.5, 0, 0, 78)
		weatherLabel.Size = UDim2.fromOffset(280, 26)
		weatherLabel.TextXAlignment = Enum.TextXAlignment.Center
		livePill.AnchorPoint = Vector2.new(0.5, 0)
		livePill.Position = UDim2.new(0.5, 0, 0, 144)
		livePill.Size = UDim2.fromOffset(320, 34)
		storePlus.Visible = true
		leiLabel.Size = UDim2.new(1, -72, 0.64, 0)
		incomeLabel.Position = UDim2.new(0, 64, 0.62, 0)
		incomeLabel.Size = UDim2.new(1, -80, 0.32, 0)
		column.Visible = true
		touchRow.Visible = false
		for order, id in DESKTOP_ACTIONS do
			local holder = holders[id]
			holder.Parent = column
			holder.LayoutOrder = order
			shapeHolder(holder, false, 76)
		end
		-- pe ecrane joase coloana se micșorează ca să încapă între bani și cutia de apărare
		columnScale.Scale = math.clamp((size.Y - 150) / COLUMN_HEIGHT, 0.5, 1)
		defenseBox.Visible = true
		touchDefense.Visible = false
		seedBar.AnchorPoint = Vector2.new(0.5, 1)
		seedBar.Position = UDim2.new(0.5, 0, 1, -14)
		seedBar.Size = UDim2.new(0.5, 0, 0, 56)
	end
	seedShown = ""
	renderSeedBar()
end

-- Pentru playtest: dreptunghiurile reale (în coordonatele Root) ale tuturor butoanelor vizibile ale HUD-ului
function HudController.audit(): { { name: string, x: number, y: number, w: number, h: number } }
	local root = UI.screen()
	local origin = root.AbsolutePosition
	local list = {}
	for _, descendant in root:GetDescendants() do
		-- butoanele din bara de semințe se derulează (ScrollingFrame): contează banda, nu fiecare buton
		local isSeedBar = descendant == seedBar
		if
			(
				isSeedBar
				or descendant:IsA("GuiButton")
					and not descendant:FindFirstAncestorOfClass("ScrollingFrame")
			)
			and (descendant :: GuiObject).Visible
			and not descendant:FindFirstAncestor("Panel")
			and not descendant:FindFirstAncestor("MoreMenu")
			and not descendant:FindFirstAncestor("TradeRequest")
		then
			local visible = true
			local parent = descendant.Parent
			while parent and parent ~= root do
				if parent:IsA("GuiObject") and not parent.Visible then
					visible = false
					break
				end
				parent = parent.Parent
			end
			local object = descendant :: GuiObject
			if visible and object.AbsoluteSize.X > 0 then
				local at = object.AbsolutePosition - origin
				table.insert(list, {
					name = descendant:GetFullName(),
					x = at.X,
					y = at.Y,
					w = object.AbsoluteSize.X,
					h = object.AbsoluteSize.Y,
				})
			end
		end
	end
	return list
end

-- Pentru playtest: deschide sau închide meniul „Mai mult”
function HudController.toggleMenu()
	menu.Visible = not menu.Visible
end

function HudController.start()
	local screen = UI.screen()
	buildTop(screen)
	buildActions(screen)
	buildDefense(screen)

	seedBar = Instance.new("ScrollingFrame")
	seedBar.Name = "SeedBar"
	seedBar.BackgroundTransparency = 1
	seedBar.BorderSizePixel = 0
	seedBar.ScrollingDirection = Enum.ScrollingDirection.X
	seedBar.AutomaticCanvasSize = Enum.AutomaticSize.X
	seedBar.CanvasSize = UDim2.new()
	seedBar.ScrollBarThickness = 4
	seedBar.ScrollBarImageColor3 = Theme.inkSoft
	seedBar.Parent = screen
	local seedLayout = UI.list(seedBar, Enum.FillDirection.Horizontal, 8)
	seedLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	seedLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	Layout.onChanged(applyLayout)
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
