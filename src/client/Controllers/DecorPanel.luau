--!strict
-- Decorul ogrăzii pe client: catalogul (cumpără pe lei) și obiectele tale (așază, scoate). „Așază” pornește
-- DecorPlacer: în ograda ta apar semne „+” pe sloturile potrivite; atingi unul și obiectul se pune acolo.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local DecorConfig = require(Shared.Config.Decor)
local Economy = require(Shared.Domain.Economy)
local ClientState = require(script.Parent.ClientState)
local UI = require(script.Parent.UI)
local DecorPlacer = require(script.Parent.DecorPlacer)

local DecorPanel = {}

local panel: Frame
local scroll: ScrollingFrame
local builtFor = ""

local function signature(): string
	local state = ClientState.state
	local parts = { tostring(state.lei and math.floor(state.lei / 100)) }
	for id, n in state.ownedDecor or {} do
		table.insert(parts, id .. n)
	end
	for slot, id in state.decor or {} do
		table.insert(parts, slot .. id)
	end
	table.sort(parts)
	return table.concat(parts, "|")
end

local function render(force: boolean?)
	local sig = signature()
	if not force and sig == builtFor then
		return
	end
	builtFor = sig
	UI.clear(scroll)
	UI.list(scroll, Enum.FillDirection.Vertical, 6)
	local state = ClientState.state
	local owned = state.ownedDecor or {}
	local placed: { [string]: string } = {}
	for slot, id in state.decor or {} do
		placed[id] = slot
	end
	local order = 0
	local function add(props: { [string]: any }, onClick: () -> ())
		order += 1
		props.LayoutOrder = order
		props.Size = props.Size or UDim2.new(1, -12, 0, 46)
		props.Parent = scroll
		UI.button(props, onClick)
	end
	-- ale tale întâi: „Așază” / „Scoate”
	for _, item in DecorConfig.items do
		if (owned[item.id] or 0) > 0 then
			local slot = placed[item.id]
			add({
				Text = ClientState.t("decor." .. item.id) .. "  ·  " .. ClientState.t(
					if slot then "decor.remove" else "decor.place"
				),
				swatch = if slot then "plum" else "vine",
			}, function()
				if slot then
					Net.get("PlaceDecor"):FireServer(nil, slot)
				else
					UI.show(panel, false)
					DecorPlacer.begin(item.id, item.kind)
				end
			end)
		end
	end
	for _, item in DecorConfig.items do
		if (owned[item.id] or 0) == 0 then
			add({
				Text = ClientState.t("decor." .. item.id)
					.. "  "
					.. Economy.formatShort(item.price)
					.. " lei",
				swatch = if (state.lei or 0) >= item.price then "wheat" else "stone",
				icon = "lei",
			}, function()
				Net.get("BuyDecor"):FireServer(item.id)
			end)
		end
	end
end

function DecorPanel.toggle()
	UI.show(panel, not panel.Visible)
	if panel.Visible then
		render(true)
	end
end

-- Pentru playtest
function DecorPanel.debugState(): { [string]: any }
	return { visible = panel.Visible, rows = #scroll:GetChildren() - 1, placing = DecorPlacer.active() }
end

function DecorPanel.start()
	panel, scroll = UI.panel(ClientState.t("decor.title"), function()
		UI.show(panel, false)
	end)
	ClientState.onChanged(function()
		if panel.Visible then
			render()
		end
	end)
end

return DecorPanel
