--!strict
-- Mesajele rapide pe client: butonul (pe telefon la locul lui din HudLayout.quick), grila cu cele 12 mesaje și
-- bulele de deasupra capetelor (oricui, traduse în limba ta).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local QuickChat = require(Shared.Config.QuickChat)
local HudLayout = require(Shared.Domain.HudLayout)
local ClientState = require(script.Parent.ClientState)
local Layout = require(script.Parent.Layout)
local UI = require(script.Parent.UI)
local Theme = require(script.Parent.Theme)

local QuickChatWheel = {}

local button: TextButton
local grid: Frame

local function emojiFor(id: string): string
	for _, message in QuickChat.list do
		if message.id == id then
			return message.emoji
		end
	end
	return "💬"
end

local function bubble(character: Model)
	local function show()
		local value = character:GetAttribute("Quick")
		local head = character:FindFirstChild("Head") :: BasePart?
		if typeof(value) ~= "string" or not head then
			return
		end
		local id = string.match(value, "^(%a+):") or ""
		local old = character:FindFirstChild("QuickBubble")
		if old then
			old:Destroy()
		end
		local gui = Instance.new("BillboardGui")
		gui.Name = "QuickBubble"
		gui.Size = UDim2.fromOffset(220, 46)
		gui.StudsOffset = Vector3.new(0, 4.6, 0)
		gui.MaxDistance = 90
		gui.Adornee = head
		gui.Parent = character
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Theme.paper
		label.BackgroundTransparency = 0.05
		label.TextScaled = true
		label.FontFace = UI.font
		label.TextColor3 = Theme.ink
		label.Text = emojiFor(id) .. " " .. ClientState.t("quick." .. id)
		label.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.4, 0)
		corner.Parent = label
		task.delay(QuickChat.bubbleSeconds, function()
			if gui.Parent then
				gui:Destroy()
			end
		end)
	end
	character:GetAttributeChangedSignal("Quick"):Connect(show)
end

local function applyLayout()
	local size = Layout.size()
	if Layout.isTouch() then
		local rect = HudLayout.touch(
			size.X,
			size.Y,
			Layout.jump(),
			HudLayout.TOUCH_ACTIONS,
			HudLayout.MENU_ITEMS
		).quick
		button.AnchorPoint = Vector2.zero
		button.Position = UDim2.fromOffset(rect.x, rect.y)
		button.Size = UDim2.fromOffset(rect.w, rect.h)
	else
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -12, 0.42, 0)
		button.Size = UDim2.fromOffset(60, 60)
	end
end

-- Pentru playtest
function QuickChatWheel.debugState(): { [string]: any }
	return {
		button = button.Visible,
		open = grid.Visible,
		rect = { button.AbsolutePosition.X, button.AbsolutePosition.Y, button.AbsoluteSize.X },
	}
end

function QuickChatWheel.toggle()
	grid.Visible = not grid.Visible
end

function QuickChatWheel.start()
	local root = UI.screen()
	button = UI.button(
		{ Name = "QuickChatButton", Text = "💬", swatch = "sky", Parent = root },
		QuickChatWheel.toggle
	)
	local corner = button:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0.5, 0)
	end
	grid = UI.frame({
		Name = "QuickChatGrid",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -80, 0.45, 0),
		Size = UDim2.fromOffset(330, 6 * 46 + 7 * 6),
		BackgroundColor3 = Theme.paper,
		Visible = false,
		ZIndex = 9,
		Parent = root,
	})
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(156, 44)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = grid
	for order, message in QuickChat.list do
		UI.button({
			LayoutOrder = order,
			Text = message.emoji .. " " .. ClientState.t("quick." .. message.id),
			swatch = "paper",
			ZIndex = 10,
			Parent = grid,
		}, function()
			Net.get("QuickChat"):FireServer(message.id)
			grid.Visible = false
		end)
	end
	applyLayout()
	Layout.onChanged(applyLayout)
	local function watch(player: Player)
		if player.Character then
			bubble(player.Character)
		end
		player.CharacterAdded:Connect(bubble)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
end

return QuickChatWheel
