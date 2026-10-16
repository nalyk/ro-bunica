--!strict
-- Fereastra recompensei zilnice: cele 7 zile ale seriei, ziua de azi luminată, leii care „sar” spre bani.
-- Apare o dată pe zi, când serverul trimite recompensa (DailyService).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Daily = require(Shared.Domain.Daily)
local Economy = require(Shared.Domain.Economy)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)
local Music = require(script.Parent.Music)
local UI = require(script.Parent.UI)

local DailyPopup = {}

local panel: Frame
local scroll: ScrollingFrame

local function tile(day: number, today: number, parent: Instance)
	local isToday = day == today
	local done = day < today
	local frame = UI.frame({
		Size = UDim2.new(1 / Daily.LENGTH, -6, 0, 104), -- cele 7 zile încap pe orice lățime
		LayoutOrder = day,
		BackgroundColor3 = if isToday
			then Theme.swatches.wheat.base
			elseif done then Theme.swatches.vine.light
			else Theme.paper,
		Parent = parent,
	})
	UI.capText(
		UI.label({
			Size = UDim2.new(1, -6, 0, 22),
			Position = UDim2.fromOffset(3, 4),
			Text = ClientState.t("ui.dailyDay", { day }),
			Parent = frame,
		}),
		16
	)
	local icon = UI.icon(if day == Daily.LENGTH then "seeds" else "lei", {
		Size = UDim2.fromOffset(44, 44),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 28),
	})
	if icon then
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.Parent = icon
		icon.Size = UDim2.new(0.8, 0, 0, 44)
		icon.Parent = frame
	end
	UI.capText(
		UI.label({
			Size = UDim2.new(1, -6, 0, 22),
			Position = UDim2.new(0, 3, 1, -26),
			Text = Economy.formatShort(Daily.LEI[day]),
			TextColor3 = Theme.swatches.ie.dark,
			Parent = frame,
		}),
		16
	)
	if isToday then
		Motion.pop(frame)
	end
end

local function show(claim: { day: number, lei: number, seed: string? })
	UI.clear(scroll)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -12, 0, 110)
	row.LayoutOrder = 1
	row.Parent = scroll
	local layout = UI.list(row, Enum.FillDirection.Horizontal, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	for day = 1, Daily.LENGTH do
		tile(day, claim.day, row)
	end
	local text = ClientState.t("ui.dailyGot", { Economy.formatShort(claim.lei) })
	if claim.seed then
		text ..= " + " .. ClientState.t("creature." .. claim.seed)
	end
	UI.capText(
		UI.label({ Size = UDim2.new(1, -12, 0, 34), Text = text, LayoutOrder = 2, Parent = scroll }),
		22
	)
	UI.capText(
		UI.label({
			Size = UDim2.new(1, -12, 0, 26),
			Text = ClientState.t("ui.dailyCome"),
			TextColor3 = Theme.inkSoft,
			LayoutOrder = 3,
			Parent = scroll,
		}),
		17
	)
	local ok = UI.button({
		Size = UDim2.new(0.6, 0, 0, 54),
		Text = ClientState.t("ui.dailyThanks"),
		swatch = "vine",
		LayoutOrder = 4,
		Parent = scroll,
	}, function()
		UI.show(panel, false)
	end)
	ok.AnchorPoint = Vector2.new(0, 0)
	UI.show(panel, true)
	Music.cue("reward1", { quantize = false, volume = 0.7 })
end

function DailyPopup.toggle()
	UI.show(panel, not panel.Visible)
end

function DailyPopup.start()
	panel, scroll = UI.panel(ClientState.t("ui.daily"), function()
		UI.show(panel, false)
	end)
	local layout = scroll:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
	Net.get("Daily").OnClientEvent:Connect(show)
end

-- Pentru teste: arată fereastra cu o recompensă dată
DailyPopup.show = show

return DailyPopup
