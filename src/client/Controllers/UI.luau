--!strict
-- Mic kit de interfață în stilul „Satul brodat”: rame roșii cusute, colțuri rotunjite, text mare.

local Players = game:GetService("Players")

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

UI.font = Enum.Font.FredokaOne

local screen: ScreenGui? = nil

function UI.screen(): ScreenGui
	if screen then
		return screen
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "BunicaUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screen = gui
	return gui
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
	label.Font = UI.font
	label.TextColor3 = UI.colors.ink
	label.TextScaled = true
	for key, value in props do
		(label :: any)[key] = value
	end
	return label
end

function UI.button(props: { [string]: any }, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = UI.colors.stitch
	button.TextColor3 = UI.colors.linen
	button.Font = UI.font
	button.TextScaled = true
	button.AutoButtonColor = true
	for key, value in props do
		(button :: any)[key] = value
	end
	decorate(button, 10)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = button
	button.Activated:Connect(onClick)
	return button
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

-- Panou modal centrat cu titlu, buton de închidere și zonă derulabilă.
function UI.panel(title: string, onClose: () -> ()): (Frame, ScrollingFrame, TextLabel)
	local panel = UI.frame({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.7),
		Visible = false,
		Parent = UI.screen(),
	})
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(640, 520)
	constraint.Parent = panel
	local titleLabel = UI.label({
		Size = UDim2.new(1, -60, 0, 40),
		Position = UDim2.fromOffset(12, 6),
		Text = title,
		TextColor3 = UI.colors.stitch,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	UI.button({
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(1, -48, 0, 6),
		Text = "✕",
		Parent = panel,
	}, onClose)
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(10, 52)
	scroll.Size = UDim2.new(1, -20, 1, -62)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 8
	scroll.Parent = panel
	local layout = UI.list(scroll, Enum.FillDirection.Vertical, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	return panel, scroll, titleLabel
end

return UI
