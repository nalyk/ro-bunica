--!strict
-- Gamepad (consolă, controller pe PC): R2 aruncă spre ținta din centrul ecranului, L1 comută făcălețul,
-- Y = Furia Bunicii, D-pad stânga = taraba, D-pad sus = beciul, D-pad jos = hora (X rămâne pentru prompt-uri: furat, plantat), B închide panoul deschis.
-- Cât timp se joacă cu gamepad-ul: ținta din centru și glifele butoanelor (Xbox sau PlayStation, din
-- UserInputService:GetImageForKeyCode) pe butoanele din HUD; la deschiderea unui panou, selecția UI sare pe
-- primul lui buton, ca D-pad-ul să navigheze imediat.

local ContentProvider = game:GetService("ContentProvider")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local HudController = require(script.Parent.HudController)
local SlipperController = require(script.Parent.SlipperController)
local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)

local GamepadController = {}

-- `short`: textul glifei când platforma nu dă o imagine pentru buton (Studio fără controller)
type Binding = { key: Enum.KeyCode, hud: string, short: string }
local BINDINGS: { Binding } = {
	{ key = Enum.KeyCode.ButtonR2, hud = "throw", short = "R2" },
	{ key = Enum.KeyCode.ButtonL1, hud = "pin", short = "L1" },
	{ key = Enum.KeyCode.ButtonY, hud = "rage", short = "Y" },
	-- nu X: e tasta prompt-urilor (furat, plantat) pe gamepad
	{ key = Enum.KeyCode.DPadLeft, hud = "shop", short = "←" },
	{ key = Enum.KeyCode.DPadUp, hud = "cellar", short = "↑" },
	{ key = Enum.KeyCode.DPadDown, hud = "hora", short = "↓" },
	{ key = Enum.KeyCode.DPadRight, hud = "upgrades", short = "→" },
}

local active = false -- ultima intrare a fost de la gamepad
local reticle: Frame
local badges: { ImageLabel } = {}

local function isGamepad(inputType: Enum.UserInputType): boolean
	return inputType.Name:sub(1, 7) == "Gamepad"
end

-- Panoul deschis acum (taraba, beciul), dacă există
local function openPanel(): Frame?
	for _, child in UI.screen():GetChildren() do
		if child.Name == "Panel" and child:IsA("Frame") and child.Visible then
			return child
		end
	end
	return nil
end

-- Primul buton din lista panoului (rândul cu LayoutOrder minim), altfel butonul de închidere
local function firstButton(panel: Frame): GuiObject?
	local best: GuiObject? = nil
	local bestOrder = math.huge
	local scroll = panel:FindFirstChildOfClass("ScrollingFrame")
	for _, row in (if scroll then scroll:GetChildren() else {}) :: { Instance } do
		if row:IsA("GuiObject") and row.LayoutOrder < bestOrder then
			local button = row:FindFirstChildWhichIsA("TextButton", true)
			if button then
				best, bestOrder = button, row.LayoutOrder
			end
		end
	end
	return best or panel:FindFirstChildWhichIsA("TextButton")
end

local function refreshVisuals()
	local panel = openPanel()
	reticle.Visible = active and panel == nil
	for _, badge in badges do
		badge.Visible = active
	end
	local selected = GuiService.SelectedObject
	if active and panel and not (selected and selected:IsDescendantOf(panel)) then
		GuiService.SelectedObject = firstButton(panel)
	elseif (not active or not panel) and selected and selected:IsDescendantOf(UI.screen()) then
		-- fără gamepad (mouse, atingere) nu rămâne nimic selectat, nici cât panoul încă se închide animat
		GuiService.SelectedObject = nil
	end
end

function GamepadController.setActive(on: boolean)
	active = on
	refreshVisuals()
end

function GamepadController.isActive(): boolean
	return active
end

local function handler(_: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	-- cu un panou deschis, D-pad-ul și butoanele navighează prin panou
	if openPanel() then
		return Enum.ContextActionResult.Pass
	end
	for _, binding in BINDINGS do
		if binding.key == input.KeyCode then
			if binding.hud == "throw" then
				-- exact punctul ținte (coordonatele GUI nu includ bara de sus; cele de viewport, da)
				local center = reticle.AbsolutePosition + reticle.AbsoluteSize / 2
				SlipperController.throwAtViewport(center + GuiService:GetGuiInset())
			else
				local action = HudController.actions[binding.hud]
				if action then
					action()
				end
			end
			return Enum.ContextActionResult.Sink
		end
	end
	return Enum.ContextActionResult.Pass
end

local function close(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	local panel = openPanel()
	if state ~= Enum.UserInputState.Begin or not panel then
		return Enum.ContextActionResult.Pass
	end
	UI.show(panel, false)
	return Enum.ContextActionResult.Sink
end

local function buildReticle()
	reticle = Instance.new("Frame")
	reticle.Name = "GamepadReticle"
	reticle.AnchorPoint = Vector2.new(0.5, 0.5)
	-- puțin deasupra centrului: camera la persoana a treia are personajul în mijloc
	reticle.Position = UDim2.fromScale(0.5, 0.4)
	reticle.Size = UDim2.fromOffset(26, 26)
	reticle.BackgroundTransparency = 1
	reticle.Visible = false
	reticle.Parent = UI.screen()
	local ring = Instance.new("UIStroke")
	ring.Color = Theme.paper
	ring.Thickness = 3
	ring.Parent = reticle
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = reticle
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(6, 6)
	dot.BackgroundColor3 = Theme.swatches.ie.base
	dot.Parent = reticle
	local dotCorner = corner:Clone()
	dotCorner.Parent = dot
end

-- Glifa butonului de gamepad în colțul de sus al butonului din HUD
local function badge(target: GuiObject, key: Enum.KeyCode, short: string)
	local image = UserInputService:GetImageForKeyCode(key)
	local label = Instance.new("ImageLabel")
	label.Name = "GamepadGlyph"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.new(1, -4, 0, 4)
	label.Size = UDim2.fromOffset(28, 28)
	label.BackgroundColor3 = Theme.ink -- glifele Roblox sunt deschise la culoare, pentru fundal închis
	label.ZIndex = target.ZIndex + 5
	label.Visible = false
	label.Parent = target
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.paper
	stroke.Thickness = 2
	stroke.Parent = label
	-- textul rămâne până se încarcă glifa platformei (Xbox, PlayStation); dacă nu se încarcă, rămâne doar textul
	local text = UI.capText(
		UI.label({
			Size = UDim2.fromScale(0.8, 0.8),
			Position = UDim2.fromScale(0.1, 0.1),
			Text = short,
			TextColor3 = Theme.paper,
			ZIndex = label.ZIndex + 1,
			Parent = label,
		}),
		18
	)
	label.Image = ""
	if image ~= "" then
		task.spawn(function()
			local loaded = false
			local probe = Instance.new("ImageLabel")
			probe.Image = image
			pcall(function()
				ContentProvider:PreloadAsync({ probe }, function(_, status)
					loaded = status == Enum.AssetFetchStatus.Success
				end)
			end)
			probe:Destroy()
			if loaded then
				label.Image = image
				text:Destroy()
			end
		end)
	end
	table.insert(badges, label)
end

function GamepadController.start()
	buildReticle()
	local keys = {}
	for _, binding in BINDINGS do
		table.insert(keys, binding.key)
		local target = HudController.buttons[binding.hud]
		if target then
			badge(target, binding.key, binding.short)
		end
	end
	ContextActionService:BindAction("BunicaGamepad", handler, false, table.unpack(keys))
	ContextActionService:BindAction("BunicaClosePanel", close, false, Enum.KeyCode.ButtonB)

	UserInputService.LastInputTypeChanged:Connect(function(inputType)
		local gamepad = isGamepad(inputType)
		-- mișcarea mouse-ului sau tastatura opresc modul gamepad; alte tipuri (focus) nu schimbă nimic
		if
			gamepad
			or inputType.Name:sub(1, 5) == "Mouse"
			or inputType == Enum.UserInputType.Keyboard
			or inputType == Enum.UserInputType.Touch
		then
			GamepadController.setActive(gamepad)
		end
	end)
	active = isGamepad(UserInputService:GetLastInputType())
	-- panourile care se deschid sau se închid (selecția, ținta)
	local function watch(child: Instance)
		if child.Name == "Panel" and child:IsA("Frame") then
			child:GetPropertyChangedSignal("Visible"):Connect(function()
				task.defer(refreshVisuals)
			end)
		end
	end
	for _, child in UI.screen():GetChildren() do
		watch(child)
	end
	UI.screen().ChildAdded:Connect(watch)
	refreshVisuals()
end

return GamepadController
