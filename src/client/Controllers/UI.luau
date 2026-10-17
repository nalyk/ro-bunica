--!strict
-- Mic kit de interfață în stilul „Satul brodat”: rame roșii cusute, colțuri rotunjite, text mare.

local Layout = require(script.Parent.Layout)
local HudLayout = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Domain.HudLayout)
local Motion = require(script.Parent.Motion)
local Music = require(script.Parent.Music)
local Theme = require(script.Parent.Theme)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Typography = require(Shared.Visual.Typography)
local UiIcons = require(Shared.Config.UiIcons)

local UI = {}

UI.colors = table.freeze({
	stitch = Color3.fromRGB(200, 30, 40),
	stitchDark = Color3.fromRGB(30, 20, 20),
	linen = Color3.fromRGB(250, 243, 225),
	ink = Color3.fromRGB(45, 30, 25),
	gold = Color3.fromRGB(255, 200, 60),
	night = Color3.fromRGB(40, 45, 110),
	green = Color3.fromRGB(70, 160, 70),
})

UI.font = Typography.display

-- Rădăcina interfeței (Layout.root): un Frame care umple ecranul; în teste poate avea mărimea unui telefon.
function UI.screen(): Frame
	return Layout.root()
end

local function decorate(frame: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 12)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = UI.colors.stitch
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
end

function UI.frame(props: { [string]: any }): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = UI.colors.linen
	frame.BorderSizePixel = 0
	for key, value in props do
		(frame :: any)[key] = value
	end
	decorate(frame)
	return frame
end

function UI.label(props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = UI.font
	label.TextColor3 = UI.colors.ink
	label.TextScaled = true
	for key, value in props do
		(label :: any)[key] = value
	end
	return label
end

-- Text cu mărime plafonată: rândurile au aceeași mărime de literă (TextScaled singur ar mări textele scurte);
-- textele prea lungi se micșorează în continuare (telefoane).
function UI.capText(label: TextLabel, maxSize: number): TextLabel
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = maxSize
	constraint.Parent = label
	return label
end

-- Iconița `name` (art/ui/icons) ca ImageLabel, sau nil dacă nu e încă încărcată.
function UI.icon(name: string, props: { [string]: any }?): ImageLabel?
	local id = UiIcons[name]
	if not id then
		return nil
	end
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Image = "rbxassetid://" .. id
	image.ScaleType = Enum.ScaleType.Fit
	if props then
		for key, value in props do
			(image :: any)[key] = value
		end
	end
	return image
end

-- Butonul „de jucărie”: față colorată cu lumină de sus, buză 3D dedesubt, contur de cerneală,
-- iconiță opțională; la apăsare se turtește și revine elastic, cu sunet.
-- props: proprietăți ale butonului (Size, Position, Text, Parent, LayoutOrder...) plus
--   swatch = "ie" | "wheat" | "vine" | "sky" | "plum" | "paper" | "stone", icon = nume de iconiță.
function UI.button(props: { [string]: any }, onClick: () -> ()): TextButton
	local swatchName = props.swatch or (if props.BackgroundColor3 then nil else "ie")
	local swatch = swatchName and Theme.swatches[swatchName]
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.BackgroundColor3 = if swatch then swatch.base else props.BackgroundColor3
	button.TextColor3 = if swatch then swatch.text else Theme.paper
	button.FontFace = UI.font
	button.TextScaled = true
	button.Text = ""
	for key, value in props do
		if key ~= "swatch" and key ~= "icon" and key ~= "Text" then
			(button :: any)[key] = value
		end
	end
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Theme.radius)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.ink
	stroke.Thickness = Theme.stroke
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	-- lumina de sus (gradient)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(220, 220, 220))
	gradient.Parent = button
	-- buza 3D: o copie mai închisă, decalată în jos, în spatele butonului
	local lip = Instance.new("Frame")
	lip.Name = "Lip"
	lip.BackgroundColor3 = if swatch then swatch.dark else Theme.shadow
	lip.Size = UDim2.fromScale(1, 1)
	lip.Position = UDim2.fromOffset(0, Theme.lip)
	-- sub conținut: în modul Sibling, ZIndex-ul copiilor e relativ între frați (nu față de buton)
	lip.ZIndex = 0
	lip.BorderSizePixel = 0
	local lipCorner = corner:Clone()
	lipCorner.Parent = lip
	local lipStroke = stroke:Clone()
	lipStroke.Parent = lip
	lip.Parent = button
	-- conținut: iconiță + text
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 1)
	content.Parent = button
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = content
	local layout = UI.list(content, Enum.FillDirection.Horizontal, 6)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	local icon = props.icon and UI.icon(props.icon, { Size = UDim2.fromScale(1, 1), LayoutOrder = 1 })
	if icon then
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.Parent = icon
		icon.Parent = content
	end
	local text = props.Text or ""
	if text ~= "" then
		local label = UI.label({
			Name = "Label",
			Size = UDim2.fromScale(if icon then 0.7 else 1, 1),
			Text = text,
			TextColor3 = button.TextColor3,
			LayoutOrder = 2,
			Parent = content,
		})
		local labelStroke = Instance.new("UIStroke")
		labelStroke.Color = if swatch then swatch.dark else Theme.shadow
		labelStroke.Thickness = 1.5
		labelStroke.Parent = label
	end
	-- mișcarea: apăsat = turtit, eliberat = revine elastic
	button.MouseButton1Down:Connect(function()
		Motion.scale(button, 0.92, Motion.presets.snappy)
	end)
	button.MouseButton1Up:Connect(function()
		Motion.scale(button, 1, Motion.presets.bouncy)
	end)
	button.MouseLeave:Connect(function()
		Motion.scale(button, 1, Motion.presets.snappy)
	end)
	button.Activated:Connect(function()
		Music.cue("tap", { quantize = false, volume = 0.6 })
		onClick()
	end)
	return button
end

-- Schimbă textul unui buton făcut cu UI.button
function UI.setText(button: TextButton, text: string)
	local label = button:FindFirstChild("Label", true) :: TextLabel?
	if label then
		label.Text = text
	end
end

-- Schimbă culoarea unui buton făcut cu UI.button
function UI.setSwatch(button: TextButton, swatchName: string)
	local swatch = Theme.swatches[swatchName]
	button.BackgroundColor3 = swatch.base
	local lip = button:FindFirstChild("Lip") :: Frame?
	if lip then
		lip.BackgroundColor3 = swatch.dark
	end
	local label = button:FindFirstChild("Label", true) :: TextLabel?
	if label then
		label.TextColor3 = swatch.text
	end
end

function UI.list(parent: Instance, direction: Enum.FillDirection, padding: number): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction
	layout.Padding = UDim.new(0, padding)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = parent
	return layout
end

function UI.clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

function UI.formatTime(seconds: number): string
	local s = math.max(math.floor(seconds), 0)
	return string.format("%d:%02d", s // 60, s % 60)
end

-- Panou modal: hârtie de in, panglică roșie de ie cu titlul, buton rotund de închidere, zonă derulabilă.
-- Se arată și se ascunde cu UI.show (apariție elastică și sunete).
function UI.panel(title: string, onClose: () -> ()): (Frame, ScrollingFrame, TextLabel)
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.52)
	panel.Size = UDim2.fromScale(0.6, 0.7)
	panel.BackgroundColor3 = Theme.paper
	panel.ZIndex = 10 -- deasupra HUD-ului (același ScreenGui, ZIndex pe frați)
	panel.Visible = false
	panel.Parent = UI.screen()
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 22)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.ink
	stroke.Thickness = Theme.stroke + 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = panel
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(660, 540)
	constraint.Parent = panel
	-- pe telefon, panoul ia aproape tot ecranul (60% × 70% din 667×339 ar fi prea mic de citit)
	Layout.onChanged(function()
		local size = Layout.size()
		local compact = Layout.isTouch() and HudLayout.compact(size.X, size.Y)
		panel.Size = if compact then UDim2.fromScale(0.94, 0.9) else UDim2.fromScale(0.6, 0.7)
		panel.Position = if compact then UDim2.fromScale(0.5, 0.53) else UDim2.fromScale(0.5, 0.52)
		constraint.MaxSize = if compact then Vector2.new(math.huge, math.huge) else Vector2.new(660, 540)
	end)
	-- panglica de titlu, roșie, care iese puțin din panou
	local ribbon = Instance.new("Frame")
	ribbon.Name = "Ribbon"
	ribbon.AnchorPoint = Vector2.new(0.5, 0.5)
	ribbon.Position = UDim2.fromScale(0.5, 0)
	ribbon.Size = UDim2.new(0.62, 0, 0, 48)
	ribbon.BackgroundColor3 = Theme.swatches.ie.base
	ribbon.Parent = panel
	local ribbonCorner = Instance.new("UICorner")
	ribbonCorner.CornerRadius = UDim.new(0, 14)
	ribbonCorner.Parent = ribbon
	local ribbonStroke = stroke:Clone()
	ribbonStroke.Thickness = Theme.stroke
	ribbonStroke.Parent = ribbon
	local titleLabel = UI.label({
		Size = UDim2.new(1, -24, 1, -10),
		Position = UDim2.fromOffset(12, 5),
		Text = title,
		TextColor3 = Theme.paper,
		Parent = ribbon,
	})
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Theme.swatches.ie.dark
	titleStroke.Thickness = 2
	titleStroke.Parent = titleLabel
	local close = UI.button({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(46, 46),
		swatch = "ie",
		icon = "close",
		Text = if UI.icon("close") then "" else "✕",
		Parent = panel,
	}, onClose)
	local closeCorner = close:FindFirstChildOfClass("UICorner") :: UICorner
	closeCorner.CornerRadius = UDim.new(0.5, 0)
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(14, 38)
	scroll.Size = UDim2.new(1, -28, 1, -52)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = Theme.inkSoft
	scroll.Parent = panel
	local layout = UI.list(scroll, Enum.FillDirection.Vertical, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	return panel, scroll, titleLabel
end

-- Arată sau ascunde un panou, cu apariție elastică și sunet.
function UI.show(panel: GuiObject, visible: boolean)
	if panel.Visible == visible then
		return
	end
	if visible and panel.Name == "Panel" and panel.Parent then
		-- un singur panou deschis odată: deschiderea unuia le închide pe celelalte
		for _, other in panel.Parent:GetChildren() do
			if other ~= panel and other.Name == "Panel" and other:IsA("GuiObject") then
				other.Visible = false
			end
		end
	end
	panel.Visible = visible
	if visible then
		Motion.pop(panel)
		Music.cue("open", { quantize = false, volume = 0.7 })
	else
		Music.cue("close", { quantize = false, volume = 0.6 })
	end
end

return UI
