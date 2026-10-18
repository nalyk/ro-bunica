--!strict
-- Garderoba: ținutele Bunicii (cumpără pe lei, îmbracă) și titlurile câștigate (alege unul).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Outfits = require(Shared.Config.Outfits)
local Titles = require(Shared.Domain.Titles)
local Economy = require(Shared.Domain.Economy)
local ClientState = require(script.Parent.ClientState)
local UI = require(script.Parent.UI)

local WardrobePanel = {}

local panel: Frame
local scroll: ScrollingFrame

local function render()
	UI.clear(scroll)
	UI.list(scroll, Enum.FillDirection.Vertical, 6)
	local state = ClientState.state
	local owned = state.outfits or {}
	local order = 0
	local function add(props: { [string]: any }, onClick: () -> ())
		order += 1
		props.LayoutOrder = order
		props.Size = UDim2.new(1, -12, 0, 46)
		props.Parent = scroll
		UI.button(props, onClick)
	end
	for _, outfit in Outfits.list do
		local name = ClientState.t("outfit." .. outfit.id)
		if owned[outfit.id] then
			local wearing = state.outfit == outfit.id
			add({
				Text = name .. (if wearing then "  ✓" else "  · " .. ClientState.t("outfit.wear")),
				swatch = if wearing then "ie" else "vine",
			}, function()
				Net.get("WearOutfit"):FireServer(if wearing then nil else outfit.id)
			end)
		else
			add({
				Text = name .. "  " .. Economy.formatShort(outfit.price) .. " lei",
				swatch = if (state.lei or 0) >= outfit.price then "wheat" else "stone",
				icon = "lei",
			}, function()
				Net.get("BuyOutfit"):FireServer(outfit.id)
			end)
		end
	end
	local earned = state.titles or {}
	for _, def in Titles.list do
		local has = table.find(earned, def.id) ~= nil
		local chosen = state.title == def.id
		add({
			Text = "★ "
				.. ClientState.t("title." .. def.id)
				.. (if chosen then "  ✓" elseif has then "" else "  🔒"),
			swatch = if chosen then "ie" elseif has then "sky" else "stone",
		}, function()
			if has then
				Net.get("SetTitle"):FireServer(if chosen then nil else def.id)
			end
		end)
	end
end

function WardrobePanel.toggle()
	UI.show(panel, not panel.Visible)
	if panel.Visible then
		render()
	end
end

-- Pentru playtest
function WardrobePanel.debugState(): { [string]: any }
	local rows = 0
	for _, child in scroll:GetChildren() do
		if child:IsA("GuiButton") then
			rows += 1
		end
	end
	return { visible = panel.Visible, rows = rows }
end

function WardrobePanel.start()
	panel, scroll = UI.panel(ClientState.t("outfit.title"), function()
		UI.show(panel, false)
	end)
	ClientState.onChanged(function()
		if panel.Visible then
			render()
		end
	end)
end

return WardrobePanel
