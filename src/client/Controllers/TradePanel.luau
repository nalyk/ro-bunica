--!strict
-- Schimburile: cererea (din panoul Prieteni, `TradePanel.request`), cererea primită (Da / Nu) și fereastra
-- de schimb. În fereastră alegi până la 4 creaturi din beci și, dacă vrei, lei;
-- vezi ce dă celălalt și valoarea ambelor oferte. „Accept” de ambele părți pornește numărătoarea de 3 s;
-- orice schimbare de ofertă o oprește. Închiderea ferestrei anulează schimbul. Serverul decide totul.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Creatures = require(Shared.Config.Creatures)
local TradeConfig = require(Shared.Config.Trade)
local Economy = require(Shared.Domain.Economy)
local Trade = require(Shared.Domain.Trade)
local ClientState = require(script.Parent.ClientState)
local NotifyController = require(script.Parent.NotifyController)
local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)

local TradePanel = {}

local window: Frame
local mineList: ScrollingFrame
local theirsList: ScrollingFrame
local leiBox: TextBox
local mineValue: TextLabel
local theirsTitle: TextLabel
local theirsValue: TextLabel
local acceptButton: TextButton
local statusLabel: TextLabel
local requestBox: Frame
local requestLabel: TextLabel

local trading = false
local view: { [string]: any }? = nil
local selected: { string } = {} -- creaturile mele din ofertă (ce știe serverul)
local requestFrom: number? = nil
local requestUntil = 0
local closingByServer = false
local shown = "" -- ce e desenat acum în fereastră (se redesenează doar când se schimbă)

-- Semnătura a ce se vede: beciul meu, ambele oferte și acceptările (leii mei nu contează aici)
local function signature(): string
	local parts = {}
	for _, record in ClientState.state.cellar or {} do
		table.insert(parts, record.uid)
	end
	if view then
		for _, side in { view.mine or {}, view.theirs or {} } do
			table.insert(parts, "|")
			for _, record in side.records or {} do
				table.insert(parts, record.uid)
			end
			table.insert(parts, tostring(side.lei) .. tostring(side.accepted) .. tostring(side.value))
		end
		table.insert(parts, tostring(view.partner))
	end
	return table.concat(parts, ",")
end

local function describe(record: { id: string, size: string, mutation: string? }): string
	return ClientState.creatureName(record.id, record.size, record.mutation)
end

local function sendOffer(uids: { string })
	local lei = tonumber(leiBox.Text) or 0
	Net.get("Trade"):FireServer("offer", uids, math.max(math.floor(lei), 0))
end

-- Un rând de creatură: numele, valoarea; `onClick` pentru rândurile mele (alege sau scoate din ofertă)
local function creatureRow(
	parent: ScrollingFrame,
	record: any,
	order: number,
	chosen: boolean,
	onClick: (() -> ())?
)
	local creature = Creatures.byId[record.id]
	local color = Theme.rarity[creature and creature.rarity or "Common"] or Theme.ink
	local frame = UI.frame({
		Size = UDim2.new(1, -10, 0, 52),
		LayoutOrder = order,
		BackgroundColor3 = if chosen then Theme.swatches.vine.light else Theme.paper,
		Parent = parent,
	})
	UI.capText(
		UI.label({
			Size = UDim2.new(1, -16, 0.55, 0),
			Position = UDim2.fromOffset(8, 3),
			Text = describe(record),
			TextColor3 = color:Lerp(Theme.ink, 0.4),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		}),
		17
	)
	UI.capText(
		UI.label({
			Size = UDim2.new(1, -16, 0.38, 0),
			Position = UDim2.new(0, 8, 0.58, 0),
			Text = ClientState.t("ui.tradeWorth", { Economy.formatShort(Economy.sellPrice(record)) }),
			TextColor3 = Theme.inkSoft,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		}),
		14
	)
	if onClick then
		local hit = Instance.new("TextButton")
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.Size = UDim2.fromScale(1, 1)
		hit.Parent = frame
		hit.Activated:Connect(onClick)
	end
end

local function renderWindow()
	if not view or signature() == shown then
		return
	end
	shown = signature()
	local minePosition, theirsPosition = mineList.CanvasPosition, theirsList.CanvasPosition
	local mine = view.mine or {}
	local theirs = view.theirs or {}
	selected = {}
	for _, record in mine.records or {} do
		table.insert(selected, record.uid)
	end
	-- coloana mea: tot beciul, cu cele alese evidențiate
	UI.clear(mineList)
	for order, record in ClientState.state.cellar or {} do
		local chosen = table.find(selected, record.uid) ~= nil
		local creature = Creatures.byId[record.id]
		if creature and creature.rarity ~= "Secret" then
			creatureRow(mineList, record, if chosen then order else order + 1000, chosen, function()
				local next = table.clone(selected)
				local index = table.find(next, record.uid)
				if index then
					table.remove(next, index)
				elseif #next < TradeConfig.maxCreatures then
					table.insert(next, record.uid)
				else
					NotifyController.toast(ClientState.t("notify.TradeTooMany"), "hint")
					return
				end
				sendOffer(next)
			end)
		end
	end
	if not leiBox:IsFocused() then
		leiBox.Text = if (mine.lei or 0) > 0 then tostring(mine.lei) else ""
	end
	mineValue.Text = ClientState.t("ui.tradeValue", { Economy.formatShort(mine.value or 0) })
	-- coloana lui
	theirsTitle.Text = ClientState.t("ui.tradeTheirs", { view.partner or "?" })
	UI.clear(theirsList)
	for order, record in theirs.records or {} do
		creatureRow(theirsList, record, order, true, nil)
	end
	if (theirs.lei or 0) > 0 then
		local frame = UI.frame({ Size = UDim2.new(1, -10, 0, 40), LayoutOrder = 99, Parent = theirsList })
		UI.capText(
			UI.label({
				Size = UDim2.new(1, -16, 1, 0),
				Position = UDim2.fromOffset(8, 0),
				Text = "+ " .. Economy.formatShort(theirs.lei) .. " " .. ClientState.t("ui.lei"),
				TextColor3 = Theme.swatches.wheat.dark,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = frame,
			}),
			18
		)
	end
	theirsValue.Text = ClientState.t("ui.tradeValue", { Economy.formatShort(theirs.value or 0) })
	-- avertizare anti-păcăleală: dai mult mai mult decât primești
	local warn = Trade.lopsided(mine.value or 0, theirs.value or 0)
		and (mine.value or 0) > (theirs.value or 0)
	mineValue.Text = if warn
		then ClientState.t("ui.tradeLopsided", { Economy.formatShort(mine.value or 0) })
		else mineValue.Text
	mineValue.TextColor3 = if warn then Theme.swatches.ie.dark else Theme.inkSoft
	mineList.CanvasPosition, theirsList.CanvasPosition = minePosition, theirsPosition
	-- butonul și starea
	if mine.accepted then
		UI.setText(acceptButton, ClientState.t("ui.tradeWaiting"))
		UI.setSwatch(acceptButton, "wheat")
	else
		UI.setText(acceptButton, ClientState.t("ui.tradeAccept"))
		UI.setSwatch(acceptButton, "vine")
	end
end

local function tickStatus()
	if not view then
		return
	end
	local mine = view.mine or {}
	local theirs = view.theirs or {}
	local text: string
	if view.confirmAt then
		local left = math.max(math.ceil(view.confirmAt - Workspace:GetServerTimeNow()), 0)
		text = ClientState.t("ui.tradeCountdown", { left })
	elseif theirs.accepted then
		text = ClientState.t("ui.tradeTheyAccepted", { view.partner or "?" })
	elseif mine.accepted then
		text = ClientState.t("ui.tradeYouAccepted")
	else
		text = ClientState.t("ui.tradeHint")
	end
	statusLabel.Text = text
end

local function column(parent: Frame, x: number): (TextLabel, ScrollingFrame, TextLabel)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.new(x, 14, 0, 40)
	holder.Size = UDim2.new(0.5, -21, 1, -150)
	holder.Parent = parent
	local title = UI.capText(
		UI.label({
			Size = UDim2.new(1, 0, 0, 28),
			Text = "",
			TextColor3 = Theme.swatches.ie.dark,
			Parent = holder,
		}),
		19
	)
	local list = Instance.new("ScrollingFrame")
	list.BackgroundColor3 = Theme.paperDeep
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(0, 30)
	list.Size = UDim2.new(1, 0, 1, -62)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = Theme.inkSoft
	list.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = list
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 5)
	padding.PaddingLeft = UDim.new(0, 5)
	padding.Parent = list
	UI.list(list, Enum.FillDirection.Vertical, 5)
	local value = UI.capText(
		UI.label({
			Position = UDim2.new(0, 0, 1, -30),
			Size = UDim2.new(1, 0, 0, 28),
			Text = "",
			TextColor3 = Theme.inkSoft,
			Parent = holder,
		}),
		17
	)
	return title, list, value
end

local function buildWindow()
	window = UI.panel(ClientState.t("ui.trade"), function()
		Net.get("Trade"):FireServer("cancel")
		UI.show(window, false)
	end)
	local defaultScroll = window:FindFirstChildOfClass("ScrollingFrame")
	if defaultScroll then
		defaultScroll:Destroy()
	end
	local mineTitle
	mineTitle, mineList, mineValue = column(window, 0)
	mineTitle.Text = ClientState.t("ui.tradeMine")
	theirsTitle, theirsList, theirsValue = column(window, 0.5)
	-- leii oferiți, sub coloana mea
	leiBox = Instance.new("TextBox")
	leiBox.AnchorPoint = Vector2.new(0, 1)
	leiBox.Position = UDim2.new(0, 14, 1, -66)
	leiBox.Size = UDim2.new(0.5, -21, 0, 40)
	leiBox.BackgroundColor3 = Theme.paper
	leiBox.PlaceholderText = ClientState.t("ui.tradeLei")
	leiBox.PlaceholderColor3 = Theme.inkSoft
	leiBox.Text = ""
	leiBox.TextColor3 = Theme.ink
	leiBox.FontFace = UI.font
	leiBox.TextScaled = true
	leiBox.ClearTextOnFocus = false
	leiBox.Parent = window
	local boxCorner = Instance.new("UICorner")
	boxCorner.CornerRadius = UDim.new(0, 10)
	boxCorner.Parent = leiBox
	local boxStroke = Instance.new("UIStroke")
	boxStroke.Color = Theme.ink
	boxStroke.Thickness = 2
	boxStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	boxStroke.Parent = leiBox
	leiBox:GetPropertyChangedSignal("Text"):Connect(function()
		local digits = string.gsub(leiBox.Text, "%D", "")
		if digits ~= leiBox.Text then
			leiBox.Text = digits
		end
	end)
	leiBox.FocusLost:Connect(function()
		sendOffer(selected)
	end)
	acceptButton = UI.button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -66),
		Size = UDim2.new(0.5, -21, 0, 46),
		Text = ClientState.t("ui.tradeAccept"),
		swatch = "vine",
		icon = "check",
		Parent = window,
	}, function()
		Net.get("Trade"):FireServer("accept")
	end)
	statusLabel = UI.capText(
		UI.label({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -14),
			Size = UDim2.new(1, -28, 0, 40),
			Text = "",
			TextColor3 = Theme.swatches.plum.dark,
			Parent = window,
		}),
		20
	)
	-- închis din afară (B pe gamepad, alt panou): anulează schimbul
	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if not window.Visible and trading and not closingByServer then
			Net.get("Trade"):FireServer("cancel")
		end
	end)
end

local function buildRequest(screen: Frame)
	requestBox = UI.frame({
		Name = "TradeRequest",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 168),
		Size = UDim2.fromOffset(420, 120),
		BackgroundColor3 = Theme.paper,
		Visible = false,
		ZIndex = 20,
		Parent = screen,
	})
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.ink
	stroke.Thickness = Theme.stroke
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = requestBox
	requestLabel = UI.capText(
		UI.label({
			Size = UDim2.new(1, -24, 0, 48),
			Position = UDim2.fromOffset(12, 6),
			Text = "",
			Parent = requestBox,
		}),
		20
	)
	local function answer(yes: boolean)
		if requestFrom then
			Net.get("Trade"):FireServer("respond", requestFrom, yes)
		end
		requestFrom = nil
		requestBox.Visible = false
	end
	UI.button({
		Size = UDim2.new(0.5, -18, 0, 50),
		Position = UDim2.new(0, 12, 1, -60),
		Text = ClientState.t("ui.yes"),
		swatch = "vine",
		ZIndex = 21,
		Parent = requestBox,
	}, function()
		answer(true)
	end)
	UI.button({
		Size = UDim2.new(0.5, -18, 0, 50),
		Position = UDim2.new(0.5, 6, 1, -60),
		Text = ClientState.t("ui.no"),
		swatch = "stone",
		ZIndex = 21,
		Parent = requestBox,
	}, function()
		answer(false)
	end)
end

-- Cere schimb cu jucătorul dat (din panoul Prieteni)
function TradePanel.request(userId: number)
	Net.get("Trade"):FireServer("request", userId)
end

-- Pentru teste și gamepad: e deschisă fereastra de schimb?
function TradePanel.isTrading(): boolean
	return trading
end

-- Pentru playtest: ce se vede acum (cererea, rândurile din cele două coloane, starea).
function TradePanel.debugState(): { [string]: any }
	local function rows(list: ScrollingFrame): number
		local n = 0
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				n += 1
			end
		end
		return n
	end
	return {
		trading = trading,
		window = window.Visible,
		request = requestBox.Visible,
		mineRows = rows(mineList),
		theirsRows = rows(theirsList),
		status = statusLabel.Text,
	}
end

function TradePanel.start()
	local screen = UI.screen()
	buildWindow()
	buildRequest(screen)

	Net.get("TradeUpdate").OnClientEvent:Connect(function(kind: string, data: { [string]: any })
		if kind == "request" then
			requestFrom = data.from
			requestUntil = os.clock() + TradeConfig.requestSeconds
			requestLabel.Text = ClientState.t("ui.tradeRequest", { data.name })
			requestBox.Visible = true
		elseif kind == "state" then
			view = data
			requestBox.Visible = false
			requestFrom = nil
			if not trading then
				trading = true
				UI.show(window, true)
			end
			renderWindow()
			tickStatus()
		elseif kind == "closed" then
			trading = false
			view = nil
			shown = ""
			closingByServer = true
			UI.show(window, false)
			closingByServer = false
			local key = "trade.closed." .. tostring(data.reason)
			local text = ClientState.t(key)
			NotifyController.toast(if text == key then ClientState.t("trade.closed.Other") else text)
		end
	end)
	ClientState.onChanged(function()
		if trading then
			renderWindow()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			if trading then
				tickStatus()
			end
			if requestBox.Visible and os.clock() > requestUntil then
				requestBox.Visible = false
				requestFrom = nil
			end
		end
	end)
end

return TradePanel
