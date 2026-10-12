--!strict
-- Mesaje: notificări personale (jos), anunțuri pe server (sus) și alarma de hoț.

local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local ClientState = require(script.Parent.ClientState)
local UI = require(script.Parent.UI)

local NotifyController = {}

local toastColumn: Frame
local bannerColumn: Frame

local function pop(container: Frame, text: string, color: Color3, seconds: number)
	local item = UI.frame({
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = color,
		Parent = container,
	})
	UI.label({
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		Text = text,
		TextColor3 = if color == UI.colors.linen then UI.colors.ink else UI.colors.linen,
		Parent = item,
	})
	item.Size = UDim2.fromScale(1, 0)
	TweenService:Create(item, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Size = UDim2.new(1, 0, 0, 40) })
		:Play()
	task.delay(seconds, function()
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
	pop(toastColumn, text, color or UI.colors.linen, 3)
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
	bannerColumn.Position = UDim2.new(0.5, 0, 0, 146)
	bannerColumn.Size = UDim2.fromOffset(520, 200)
	bannerColumn.Parent = screen
	local bannerLayout = UI.list(bannerColumn, Enum.FillDirection.Vertical, 4)
	bannerLayout.VerticalAlignment = Enum.VerticalAlignment.Top

	Net.get("Notify").OnClientEvent:Connect(function(key, args)
		pop(toastColumn, ClientState.t(key, args), UI.colors.linen, 3)
	end)
	Net.get("Announce").OnClientEvent:Connect(function(key, args)
		pop(bannerColumn, ClientState.t(key, args), UI.colors.stitch, 5)
	end)
	Net.get("Alarm").OnClientEvent:Connect(function()
		pop(bannerColumn, "🐓 " .. ClientState.t("notify.Alarm"), UI.colors.night, 4)
	end)
end

return NotifyController
