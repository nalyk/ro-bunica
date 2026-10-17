--!strict
-- Mesaje: notificări personale (jos), anunțuri pe server (sus) și alarma de hoț.
-- Pe ecran tactil (Domain/HudLayout): personalele în banda liberă dintre joystick și apărare, anunțurile
-- sub rândul de sus, mai scunde.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local ClientState = require(script.Parent.ClientState)
local Motion = require(script.Parent.Motion)
local Music = require(script.Parent.Music)
local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)
local Layout = require(script.Parent.Layout)
local HudLayout = require(Shared.Domain.HudLayout)

local NotifyController = {}

local toastColumn: Frame
local bannerColumn: Frame

-- Un mesaj: pastilă rotunjită cu contur de cerneală, iconiță opțională în stânga, apariție elastică.
-- swatch: "paper" (personal), "ie" (anunț pentru tot serverul), "plum" (noaptea/hoțul)
local function pop(container: Frame, text: string, swatchName: string, seconds: number, icon: string?)
	local swatch = Theme.swatches[swatchName]
	local item = Instance.new("Frame")
	item.Size = UDim2.new(1, 0, 0, (container:GetAttribute("ItemHeight") :: number?) or 44)
	item.BackgroundColor3 = swatch.base
	item.Parent = container
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = item
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.ink
	stroke.Thickness = Theme.stroke
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = item
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(225, 225, 225))
	gradient.Parent = item
	local image = icon
		and UI.icon(icon, { Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(-6, -4) })
	if image then
		image.Parent = item
	end
	local label = UI.label({
		Size = UDim2.new(1, if image then -64 else -24, 1, -10),
		Position = UDim2.fromOffset(if image then 52 else 12, 5),
		Text = text,
		TextColor3 = swatch.text,
		Parent = item,
	})
	local fixedSize = container:GetAttribute("TextSize") :: number?
	if fixedSize then
		-- ecran tactil: textul are mărime fixă și se rupe pe rânduri, iar mesajul crește în înălțime
		label.TextScaled = false
		label.TextSize = fixedSize
		label.TextWrapped = true
		label.Size = UDim2.new(1, if image then -64 else -24, 0, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		item.AutomaticSize = Enum.AutomaticSize.Y
		local padding = Instance.new("UIPadding")
		padding.PaddingBottom = UDim.new(0, 6)
		padding.Parent = item
		corner.CornerRadius = UDim.new(0, 16)
	end
	if swatchName ~= "paper" then
		local textStroke = Instance.new("UIStroke")
		textStroke.Color = swatch.dark
		textStroke.Thickness = 2
		textStroke.Parent = label
	end
	Motion.pop(item)
	task.delay(seconds, function()
		Motion.scale(item, 0.6, Motion.presets.snappy)
		task.wait(0.12)
		item:Destroy()
	end)
	-- Maximum 4 mesaje vizibile
	local items = {}
	for _, child in container:GetChildren() do
		if child:IsA("Frame") then
			table.insert(items, child)
		end
	end
	if #items > 4 then
		items[1]:Destroy()
	end
end

function NotifyController.toast(text: string, color: Color3?)
	local _ = color
	pop(toastColumn, text, "paper", 3)
end

function NotifyController.start()
	local screen = UI.screen()
	toastColumn = Instance.new("Frame")
	toastColumn.BackgroundTransparency = 1
	toastColumn.AnchorPoint = Vector2.new(0.5, 1)
	toastColumn.Position = UDim2.new(0.5, 0, 1, -70)
	toastColumn.Size = UDim2.fromOffset(420, 200)
	toastColumn.Parent = screen
	local toastLayout = UI.list(toastColumn, Enum.FillDirection.Vertical, 4)
	toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom

	bannerColumn = Instance.new("Frame")
	bannerColumn.BackgroundTransparency = 1
	bannerColumn.AnchorPoint = Vector2.new(0.5, 0)
	bannerColumn.Position = UDim2.new(0.5, 0, 0, 182) -- sub pastila evenimentului săptămânal
	bannerColumn.Size = UDim2.fromOffset(520, 200)
	bannerColumn.Parent = screen

	Layout.onChanged(function()
		local size = Layout.size()
		if Layout.isTouch() then
			local layout =
				HudLayout.touch(size.X, size.Y, Layout.jump(), HudLayout.TOUCH_ACTIONS, HudLayout.MENU_ITEMS)
			for column, rect in
				{ [toastColumn] = layout.toasts, [bannerColumn] = layout.banners } :: { [Frame]: any }
			do
				column.AnchorPoint = Vector2.zero
				column.Position = UDim2.fromOffset(rect.x, rect.y)
				column.Size = UDim2.fromOffset(rect.w, rect.h)
				column:SetAttribute("ItemHeight", if layout.compact then 32 else 40)
				column:SetAttribute("TextSize", if layout.compact then 15 else 18)
			end
		else
			toastColumn.AnchorPoint = Vector2.new(0.5, 1)
			toastColumn.Position = UDim2.new(0.5, 0, 1, -70)
			toastColumn.Size = UDim2.fromOffset(420, 200)
			bannerColumn.AnchorPoint = Vector2.new(0.5, 0)
			bannerColumn.Position = UDim2.new(0.5, 0, 0, 182)
			bannerColumn.Size = UDim2.fromOffset(520, 200)
			-- și pe desktop: text de mărime fixă, rupt pe rânduri (altfel mesajele lungi ies tăiate)
			for _, column in { toastColumn, bannerColumn } do
				column:SetAttribute("ItemHeight", 44)
				column:SetAttribute("TextSize", 20)
			end
		end
	end)
	local bannerLayout = UI.list(bannerColumn, Enum.FillDirection.Vertical, 4)
	bannerLayout.VerticalAlignment = Enum.VerticalAlignment.Top

	Net.get("Notify").OnClientEvent:Connect(function(key, args)
		pop(toastColumn, ClientState.t(key, args), "paper", 3)
	end)
	Net.get("Announce").OnClientEvent:Connect(function(key, args)
		pop(bannerColumn, ClientState.t(key, args), "ie", 5)
	end)
	Net.get("Alarm").OnClientEvent:Connect(function()
		Music.alarm(25)
		Music.cue("alarm")
		pop(bannerColumn, ClientState.t("notify.Alarm"), "plum", 4, "alarm")
	end)
end

return NotifyController
