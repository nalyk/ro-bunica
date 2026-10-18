--!strict
-- Căsuța de coduri a tantii de la magazin: scrii codul, apeși „Folosește”.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local ClientState = require(script.Parent.ClientState)
local UI = require(script.Parent.UI)
local Theme = require(script.Parent.Theme)

local CodesPanel = {}

local panel: Frame
local box: TextBox

function CodesPanel.toggle()
	UI.show(panel, not panel.Visible)
end

function CodesPanel.start()
	local scroll
	panel, scroll = UI.panel(ClientState.t("code.title"), function()
		UI.show(panel, false)
	end)
	UI.list(scroll, Enum.FillDirection.Vertical, 8)
	UI.label({
		Size = UDim2.new(1, -12, 0, 30),
		LayoutOrder = 1,
		Text = ClientState.t("code.hint"),
		TextColor3 = Theme.inkSoft,
		Parent = scroll,
	})
	box = Instance.new("TextBox")
	box.Name = "CodeBox"
	box.LayoutOrder = 2
	box.Size = UDim2.new(1, -12, 0, 48)
	box.BackgroundColor3 = Color3.new(1, 1, 1)
	box.TextColor3 = Theme.ink
	box.PlaceholderText = "BUNICA"
	box.Text = ""
	box.ClearTextOnFocus = false
	box.TextSize = 22
	box.FontFace = UI.font
	box.Parent = scroll
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = box
	UI.button({
		Size = UDim2.new(1, -12, 0, 48),
		LayoutOrder = 3,
		Text = ClientState.t("code.use"),
		swatch = "vine",
		Parent = scroll,
	}, function()
		if box.Text ~= "" then
			Net.get("Code"):FireServer(box.Text)
			box.Text = ""
		end
	end)
end

return CodesPanel
