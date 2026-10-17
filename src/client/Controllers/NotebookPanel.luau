--!strict
-- Caietul Bunicii: trei file. „Treburi” (cele 3 treburi ale zilei, cu răsplata și bonusul), „Colecție”
-- (fiecare creatură cu mutațiile ei, descoperite sau nu, plus pragurile) și „Renaștere” (Gospodăria nouă,
-- cu confirmare dublă). Totul vine din `state.notebook`, trimis de NotebookService.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Creatures = require(Shared.Config.Creatures)
local Mutations = require(Shared.Config.Mutations)
local Notebook = require(Shared.Config.Notebook)
local Collection = require(Shared.Domain.Collection)
local Quests = require(Shared.Domain.Quests)
local Rebirth = require(Shared.Domain.Rebirth)
local Economy = require(Shared.Domain.Economy)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)

local NotebookPanel = {}

type Tab = string -- "quests" | "collection" | "rebirth"
local TABS: { Tab } = { "quests", "collection", "rebirth" }
local CONFIRM_SECONDS = 4

local panel: Frame
local scroll: ScrollingFrame
local tabButtons: { [Tab]: TextButton } = {}
local current: Tab = "quests"
local confirmUntil = 0
local shown = "" -- semnătura datelor afișate: lista se reconstruiește doar când se schimbă ceva vizibil

local function notebook(): { [string]: any }
	return ClientState.state.notebook or {}
end

local function row(height: number, order: number): Frame
	return UI.frame({ Size = UDim2.new(1, -12, 0, height), LayoutOrder = order, Parent = scroll })
end

local function text(parent: Instance, props: { [string]: any }, size: number): TextLabel
	props.Parent = parent
	if props.TextXAlignment == nil then
		props.TextXAlignment = Enum.TextXAlignment.Left
	end
	return UI.capText(UI.label(props), size)
end

local function secondsToNextDay(): number
	local now = Workspace:GetServerTimeNow()
	return 86400 - now % 86400
end

-- „6 h 23 min” sau „23 min” (treburile se schimbă la miezul nopții UTC)
local function hoursMinutes(seconds: number): string
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor(seconds % 3600 / 60)
	return if hours > 0
		then string.format("%d h %02d min", hours, minutes)
		else string.format("%d min", minutes)
end

-- Fila „Treburi” ------------------------------------------------------------

local function buildQuests()
	local data = notebook()
	local quests = data.quests or { list = {} }
	local income = (ClientState.state.incomePerSecond or 0) * (data.incomeMultiplier or 1)
	text(row(34, 0), {
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		Text = ClientState.t("ui.questsHeader", { hoursMinutes(secondsToNextDay()) }),
		TextColor3 = Theme.inkSoft,
	}, 18)
	local allClaimed = #quests.list > 0
	for index, quest in quests.list do
		allClaimed = allClaimed and quest.claimed
		local line = row(76, index)
		text(line, {
			Size = UDim2.new(0.62, -12, 0.5, 0),
			Position = UDim2.new(0, 12, 0.06, 0),
			Text = ClientState.t("quest." .. quest.kind .. ".desc", { quest.goal }),
		}, 20)
		text(line, {
			Size = UDim2.new(0.62, -12, 0.36, 0),
			Position = UDim2.new(0, 12, 0.56, 0),
			Text = ClientState.t("ui.questProgress", { quest.progress, quest.goal }),
			TextColor3 = Theme.swatches.ie.dark,
		}, 16)
		local done = quest.progress >= quest.goal
		local label = if quest.claimed
			then ClientState.t("ui.questClaimed")
			elseif done then ClientState.t(
				"ui.questClaim",
				{ Economy.formatShort(Quests.reward(income)) }
			)
			else ClientState.t("ui.questReward", { Economy.formatShort(Quests.reward(income)) })
		UI.button({
			Size = UDim2.new(0.36, -10, 0, 52),
			Position = UDim2.new(0.63, 0, 0, 12),
			Text = label,
			swatch = if quest.claimed then "wheat" elseif done then "vine" else "stone",
			icon = if done and not quest.claimed then "lei" else nil,
			Parent = line,
		}, function()
			if done and not quest.claimed then
				Net.get("Notebook"):FireServer("claimQuest", index)
			end
		end)
	end
	local bonus = row(64, 10)
	text(bonus, {
		Size = UDim2.new(0.62, -12, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		Text = ClientState.t("ui.questBonus"),
		TextColor3 = Theme.swatches.plum.dark,
	}, 18)
	UI.button({
		Size = UDim2.new(0.36, -10, 0, 48),
		Position = UDim2.new(0.63, 0, 0, 8),
		Text = if quests.bonusClaimed
			then ClientState.t("ui.questClaimed")
			else ClientState.t("ui.questBonusClaim"),
		swatch = if quests.bonusClaimed then "wheat" elseif allClaimed then "plum" else "stone",
		icon = "seeds",
		Parent = bonus,
	}, function()
		if allClaimed and not quests.bonusClaimed then
			Net.get("Notebook"):FireServer("claimBonus")
		end
	end)
end

-- Fila „Colecție” -----------------------------------------------------------

local CELL = 30

local function buildCollection()
	local data = notebook()
	local found: { [string]: boolean } = data.collection or {}
	local count = data.count or 0
	local reached = Collection.reached(count)
	text(row(30, 0), {
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		Text = ClientState.t("ui.collectionHeader", {
			count,
			data.total or Collection.TOTAL,
			math.floor(reached * Notebook.collection.milestoneBonus * 100 + 0.5),
		}),
	}, 20)
	local nextMilestone: number? = nil
	for _, value in Collection.milestones() do
		if count < value then
			nextMilestone = value
			break
		end
	end
	local hint = if count < Notebook.collection.secretAt
		then ClientState.t("ui.collectionSecret", { Notebook.collection.secretAt })
		elseif nextMilestone then ClientState.t("ui.collectionNext", { nextMilestone })
		else ClientState.t("ui.collectionDone")
	text(row(26, 1), {
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		Text = hint,
		TextColor3 = Theme.inkSoft,
	}, 16)
	-- legenda coloanelor: „fără mutație”, apoi mutațiile, fiecare în culoarea ei
	local legend = {
		string.format(
			'<font color="#%s">%s</font>',
			Theme.swatches.vine.dark:ToHex(),
			ClientState.t("ui.noMutation")
		),
	}
	for _, mutation in Mutations.list do
		table.insert(
			legend,
			string.format(
				'<font color="#%s">%s</font>',
				mutation.color:Lerp(Theme.ink, 0.25):ToHex(),
				ClientState.t("mutation." .. mutation.id)
			)
		)
	end
	text(row(26, 2), {
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		Text = table.concat(legend, "  ·  "),
		RichText = true,
	}, 15)
	-- legenda: o coloană pentru „fără mutație”, apoi câte una pentru fiecare mutație
	for order, creature in Creatures.list do
		local line = row(CELL + 12, order + 2)
		local any = found[creature.id] == true
		for _, mutation in Mutations.list do
			any = any or found[creature.id .. ":" .. mutation.id] == true
		end
		text(line, {
			Size = UDim2.new(0.4, -12, 1, 0),
			Position = UDim2.fromOffset(10, 0),
			-- numele se văd (știi ce cauți), doar Rețeta Secretă rămâne secretă până o descoperi
			Text = if any or creature.rarity ~= "Secret"
				then ClientState.t("creature." .. creature.id)
				else ClientState.t("ui.unknown"),
			TextColor3 = if any
				then (Theme.rarity[creature.rarity] or Theme.ink):Lerp(Theme.ink, 0.35)
				else Theme.inkSoft,
		}, 17)
		local cells = Instance.new("Frame")
		cells.BackgroundTransparency = 1
		cells.Position = UDim2.new(0.4, 0, 0, 6)
		cells.Size = UDim2.new(0.6, -8, 0, CELL)
		cells.Parent = line
		UI.list(cells, Enum.FillDirection.Horizontal, 4)
		local columns: { { key: string, color: Color3, name: string } } = {
			{ key = creature.id, color = Theme.swatches.vine.base, name = "" },
		}
		for _, mutation in Mutations.list do
			table.insert(columns, {
				key = creature.id .. ":" .. mutation.id,
				color = mutation.color,
				name = "mutation." .. mutation.id,
			})
		end
		for index, column in columns do
			local have = found[column.key] == true
			local cell = Instance.new("TextLabel")
			cell.LayoutOrder = index
			cell.Size = UDim2.fromOffset(CELL, CELL)
			-- nedescoperită: culoarea mutației, ștearsă, cu „?”; descoperită: plină, cu bifă
			cell.BackgroundColor3 = column.color
			cell.BackgroundTransparency = if have then 0 else 0.72
			cell.Text = if have then "✓" else "?"
			cell.TextColor3 = if have then Theme.paper else Theme.inkSoft
			cell.FontFace = UI.font
			cell.TextScaled = true
			cell.Parent = cells
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.3, 0)
			corner.Parent = cell
			local stroke = Instance.new("UIStroke")
			stroke.Color = if have then Theme.ink else Theme.inkSoft
			stroke.Thickness = if have then 2 else 1
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = cell
		end
	end
end

-- Fila „Renaștere” ----------------------------------------------------------

local function buildRebirth()
	local data = notebook()
	local level = data.rebirths or 0
	local cost: number? = data.rebirthCost
	local lei = ClientState.state.lei or 0
	text(row(36, 0), {
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		Text = ClientState.t("ui.rebirthTitle")
			.. (if level > 0 then "  " .. string.rep("★", level) else ""),
		TextColor3 = Theme.swatches.ie.dark,
	}, 24)
	text(row(120, 1), {
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		Text = ClientState.t("ui.rebirthBody", { ClientState.t("creature." .. Notebook.rebirth.giftSeed) }),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, 17)
	text(row(30, 2), {
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		Text = ClientState.t(
			"ui.rebirthLevel",
			{ level, Rebirth.multiplier(level), Rebirth.multiplier(level + 1) }
		),
		TextColor3 = Theme.swatches.vine.dark,
	}, 18)
	local line = row(70, 3)
	local label: string
	local swatch: string
	if not cost then
		label, swatch = ClientState.t("ui.rebirthMax"), "wheat"
	elseif os.clock() < confirmUntil then
		label, swatch = ClientState.t("ui.rebirthConfirm"), "ie"
	else
		label = ClientState.t("ui.rebirthCost", { Economy.formatShort(cost) })
		swatch = if lei >= cost then "vine" else "stone"
	end
	UI.button({
		Size = UDim2.new(0.7, 0, 0, 58),
		Position = UDim2.new(0.15, 0, 0, 6),
		Text = label,
		swatch = swatch,
		icon = "lei",
		Parent = line,
	}, function()
		if not cost or lei < cost then
			return
		end
		if os.clock() < confirmUntil then
			confirmUntil = 0
			Net.get("Notebook"):FireServer("rebirth")
		else
			confirmUntil = os.clock() + CONFIRM_SECONDS
			task.delay(CONFIRM_SECONDS, function()
				if current == "rebirth" and panel.Visible then
					NotebookPanel.refresh()
				end
			end)
		end
		NotebookPanel.refresh()
	end)
end

-- Panoul -------------------------------------------------------------------

-- Ce se vede în fila curentă (leii se schimbă în fiecare secundă, dar contează doar pragurile lor)
local function signature(): string
	local data = notebook()
	local parts =
		{ current, tostring(data.count), tostring(data.rebirths), tostring(confirmUntil > os.clock()) }
	local quests = data.quests or { list = {} }
	for _, quest in quests.list do
		table.insert(parts, quest.kind .. quest.progress .. tostring(quest.claimed))
	end
	table.insert(parts, tostring(quests.bonusClaimed))
	local income = (ClientState.state.incomePerSecond or 0) * (data.incomeMultiplier or 1)
	table.insert(parts, Economy.formatShort(Quests.reward(income)))
	local cost = data.rebirthCost
	table.insert(parts, tostring(cost and (ClientState.state.lei or 0) >= cost))
	return table.concat(parts, "|")
end

function NotebookPanel.refresh()
	shown = signature()
	for tab, button in tabButtons do
		UI.setSwatch(button, if tab == current then "ie" else "paper")
	end
	local position = scroll.CanvasPosition
	UI.clear(scroll)
	if current == "quests" then
		buildQuests()
	elseif current == "collection" then
		buildCollection()
	else
		buildRebirth()
	end
	scroll.CanvasPosition = position
end

function NotebookPanel.select(tab: Tab)
	current = tab
	scroll.CanvasPosition = Vector2.zero
	NotebookPanel.refresh()
end

function NotebookPanel.toggle()
	UI.show(panel, not panel.Visible)
	if panel.Visible then
		NotebookPanel.refresh()
	end
end

function NotebookPanel.isOpen(): boolean
	return panel.Visible
end

function NotebookPanel.start()
	panel, scroll = UI.panel(ClientState.t("ui.notebookTitle"), function()
		UI.show(panel, false)
	end)
	panel.Name = "Panel"
	-- filele, sub panglica de titlu; lista coboară sub ele
	local bar = Instance.new("Frame")
	bar.Name = "Tabs"
	bar.BackgroundTransparency = 1
	bar.Position = UDim2.fromOffset(14, 34)
	bar.Size = UDim2.new(1, -28, 0, 44)
	bar.Parent = panel
	local layout = UI.list(bar, Enum.FillDirection.Horizontal, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	for order, tab in TABS do
		local button = UI.button({
			Size = UDim2.new(1 / #TABS, -8, 1, 0),
			LayoutOrder = order,
			Text = ClientState.t("ui.tab." .. tab),
			swatch = "paper",
			Parent = bar,
		}, function()
			NotebookPanel.select(tab)
		end)
		tabButtons[tab] = button
	end
	scroll.Position = UDim2.fromOffset(14, 86)
	scroll.Size = UDim2.new(1, -28, 1, -100)
	ClientState.onChanged(function()
		if panel.Visible and signature() ~= shown then
			NotebookPanel.refresh()
		end
	end)
end

return NotebookPanel
