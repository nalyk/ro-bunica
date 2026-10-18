--!strict
-- Mini-jocurile pe client: anunțul înscrierii (prin coada de mesaje) și butonul „Intră” când ești lângă loc,
-- numărătoarea 3-2-1 mare în mijloc, tabela de scor (o bandă sub mesaje: HudLayout.scoreboard), podiumul
-- la final. Fantomele (eliminații) au butonul „Încurajează”. Plus panoul „Mini-jocuri” (lista, cu „Intră”).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Minigames = require(Shared.Config.Minigames)
local HudLayout = require(Shared.Domain.HudLayout)
local Rhythm = require(Shared.Domain.Rhythm)
local VillageLayout = require(Shared.Domain.VillageLayout)
local ClientState = require(script.Parent.ClientState)
local NotifyController = require(script.Parent.NotifyController)
local Layout = require(script.Parent.Layout)
local UI = require(script.Parent.UI)
local Theme = require(script.Parent.Theme)

local MinigameController = {}

type Payload = { [string]: any }

local localPlayer = Players.LocalPlayer
local sites = VillageLayout.build().sites
local lobby: Payload? = nil -- înscrierea deschisă (cea mai recentă)
local running: Payload? = nil -- jocul în care e jucătorul
local joinButton: TextButton
local board: TextLabel
local countdown: TextLabel
local panel: Frame
local scroll: ScrollingFrame
local cheerButton: TextButton
local batButton: TextButton
local laughButton: TextButton
local rhythmButton: TextButton
local stationButton: TextButton
local stationId: string? = nil
local rhythmBeats: { number }? = nil
local rhythmStart = 0
local blindfold: Frame
local blur: BlurEffect

-- Un semn scurt în lume (Cucu!, Ha-ha!, Greșit!)
local function bubble(position: Vector3, text: string, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = position + Vector3.new(0, 5, 0)
	anchor.Parent = Workspace
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 50)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 200
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
	task.delay(2.2, function()
		anchor:Destroy()
	end)
end

-- Efectele jocurilor de ascuns: semnele din lume și butonul de râs
local function hideAndSeek(extra: any)
	if typeof(extra) ~= "table" then
		laughButton.Visible = false
		return
	end
	if typeof(extra.cucu) == "Vector3" then
		bubble(extra.cucu, "👻 " .. ClientState.t("minigame.cucu"), Color3.fromRGB(200, 230, 255))
	end
	if typeof(extra.laugh) == "Vector3" then
		bubble(extra.laugh, "Ha-ha-ha!", Color3.fromRGB(255, 220, 90))
	end
	if typeof(extra.wrong) == "Vector3" then
		bubble(extra.wrong, ClientState.t("minigame.wrong"), Color3.fromRGB(255, 120, 120))
	end
	local me = localPlayer.UserId
	local seeker = (extra.seekers and table.find(extra.seekers, me) ~= nil)
	local ghost = extra.ghosts and table.find(extra.ghosts, me) ~= nil
	laughButton.Visible = extra.seekers ~= nil and not seeker and not ghost
end
local choicePanel: Frame
local choiceScroll: ScrollingFrame
local choiceKey = "" -- ce variante se văd acum (refacem panoul doar la schimbare)

-- Alegerile cerute de joc (oul pentru ciocnit, votul): extra.choose = { { id, text, args? } }
local function renderChoices(extra: any)
	local options = nil
	if typeof(extra) == "table" then
		options = extra.choose or (extra.chooseFor and extra.chooseFor[tostring(localPlayer.UserId)])
	end
	local key = if options then (extra.chooseKey or "") .. "#" .. tostring(#options) else ""
	if key == choiceKey then
		return
	end
	choiceKey = key
	UI.clear(choiceScroll)
	if not options or #options == 0 then
		UI.show(choicePanel, false)
		return
	end
	UI.list(choiceScroll, Enum.FillDirection.Vertical, 6)
	for order, option in options do
		UI.button({
			Size = UDim2.new(1, -12, 0, 48),
			LayoutOrder = order,
			Text = ClientState.t(option.text, option.args),
			swatch = option.swatch or "sky",
			Parent = choiceScroll,
		}, function()
			Net.get("MinigameAction"):FireServer("act", { choice = option.id })
			UI.show(choicePanel, false)
		end)
	end
	UI.show(choicePanel, true)
end

local function title(id: string): string
	return ClientState.t("minigame." .. id)
end

local function nearSite(site: string): boolean
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local cf: CFrame? = sites[site]
	if not root or not cf then
		return false
	end
	return Vector3.new(root.Position.X - cf.X, 0, root.Position.Z - cf.Z).Magnitude
		<= Minigames.enrollDistance
end

local function applyLayout()
	local size = Layout.size()
	if Layout.isTouch() then
		local layout =
			HudLayout.touch(size.X, size.Y, Layout.jump(), HudLayout.TOUCH_ACTIONS, HudLayout.MENU_ITEMS)
		local rect = layout.scoreboard
		board.AnchorPoint = Vector2.zero
		board.Position = UDim2.fromOffset(rect.x, rect.y)
		board.Size = UDim2.fromOffset(rect.w, rect.h)
		board.TextSize = if layout.compact then 14 else 17
	else
		board.AnchorPoint = Vector2.new(0.5, 0)
		board.Position = UDim2.new(0.5, 0, 0, 140)
		board.Size = UDim2.fromOffset(520, 34)
		board.TextSize = 18
	end
end

-- Banda de scor: primii trei și locul tău
local function renderBoard(payload: Payload)
	local scores: { [any]: number } = payload.scores or {}
	local list = {}
	for id, score in scores do
		table.insert(list, { id = tonumber(id) or id, score = score })
	end
	table.sort(list, function(a, b)
		return a.score > b.score
	end)
	local parts = {}
	local medals = { "🥇", "🥈", "🥉" }
	for place, entry in list do
		local player = Players:GetPlayerByUserId(entry.id :: number)
		local name = if entry.id == localPlayer.UserId
			then ClientState.t("ui.you")
			elseif player then player.DisplayName
			else "…"
		if place <= 3 then
			table.insert(parts, string.format("%s %s %d", medals[place], name, entry.score))
		elseif entry.id == localPlayer.UserId then
			table.insert(parts, string.format("#%d %s %d", place, name, entry.score))
		end
	end
	local left = math.max(0, math.ceil((payload.endsAt or 0) - Workspace:GetServerTimeNow()))
	local extra = payload.extra
	if typeof(extra) == "table" and extra.orders then
		-- plăcintăria: comenzile deschise și pasul plăcintei tale
		local orders = {}
		for _, order in extra.orders do
			table.insert(orders, ClientState.t("minigame.pie." .. order))
		end
		table.insert(parts, "🥧 " .. table.concat(orders, ", "))
		local mine = extra.pies and extra.pies[tostring(localPlayer.UserId)]
		if mine then
			table.insert(parts, "→ " .. ClientState.t("minigame.step." .. mine))
		end
	end
	board.Text = string.format("⏱ %d  ·  %s", left, table.concat(parts, "  ·  "))
	board.Visible = true
end

local function renderPanel()
	UI.clear(scroll)
	UI.list(scroll, Enum.FillDirection.Vertical, 6)
	for order, def in Minigames.list do
		local near = nearSite(def.site)
		UI.button({
			Size = UDim2.new(1, -12, 0, 46),
			LayoutOrder = order,
			Text = title(def.id) .. "  " .. def.ages .. (if near
				then "  ▶ " .. ClientState.t("minigame.join")
				else ""),
			swatch = if near then "sky" else "stone",
			Parent = scroll,
		}, function()
			if nearSite(def.site) then
				Net.get("MinigameAction"):FireServer("open", def.id)
			else
				NotifyController.notice("minigame.far", ClientState.t("minigame.far"), "hint")
			end
		end)
	end
end

function MinigameController.toggle()
	UI.show(panel, not panel.Visible)
	if panel.Visible then
		renderPanel()
	end
end

-- Pentru playtest
function MinigameController.debugState(): { [string]: any }
	return {
		lobby = lobby and lobby.id,
		running = running and running.id,
		state = running and running.state,
		board = board.Visible and board.Text or nil,
		join = joinButton.Visible,
		choices = choicePanel.Visible,
	}
end

local function onMinigame(payload: Payload)
	local state = payload.state
	if state == "enroll" then
		local fresh = not lobby or lobby.id ~= payload.id
		lobby = payload
		if fresh then
			local seconds = math.max(0, math.floor((payload.closesAt or 0) - Workspace:GetServerTimeNow()))
			NotifyController.notice(
				"minigame.enroll",
				ClientState.t("minigame.enroll", { title(payload.id), tostring(seconds) })
			)
		end
	elseif state == "cancelled" then
		if lobby and lobby.id == payload.id then
			lobby = nil
		end
	elseif state == "countdown" then
		if lobby and lobby.id == payload.id then
			lobby = nil
		end
		if table.find(payload.players or {}, localPlayer.UserId) then
			running = payload
		end
	elseif state == "running" then
		if running and running.id == payload.id then
			running = payload
			renderChoices(payload.extra)
			local extra = payload.extra
			local myTeam = typeof(extra) == "table"
				and extra.teams
				and extra.teams[tostring(localPlayer.UserId)]
			local ghost = typeof(extra) == "table"
				and extra.ghosts
				and table.find(extra.ghosts, localPlayer.UserId) ~= nil
			batButton.Visible = myTeam ~= nil and myTeam == extra.batting and not ghost
			hideAndSeek(extra)
			if typeof(extra) == "table" and typeof(extra.rhythm) == "table" then
				rhythmBeats = Rhythm.track(
					extra.rhythm.seed,
					extra.rhythm.bpm,
					(payload.endsAt or 0) - extra.rhythm.startsAt
				)
				rhythmStart = extra.rhythm.startsAt
				rhythmButton.Visible = true
			end
			cheerButton.Visible = typeof(payload.extra) == "table"
				and payload.extra.ghosts ~= nil
				and table.find(payload.extra.ghosts, localPlayer.UserId) ~= nil
		end
	elseif state == "results" then
		if running and running.id == payload.id then
			running = nil
			board.Visible = false
			cheerButton.Visible = false
			batButton.Visible = false
			laughButton.Visible = false
			rhythmButton.Visible = false
			rhythmBeats = nil
			stationButton.Visible = false
			blindfold.Visible = false
			blur.Enabled = false
			renderChoices(nil)
		end
	end
end

function MinigameController.start()
	local root = UI.screen()
	board = UI.label({
		Name = "MinigameBoard",
		BackgroundTransparency = 0.25,
		BackgroundColor3 = Theme.ink,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = false,
		TextWrapped = false,
		Visible = false,
		Parent = root,
	})
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = board
	countdown = UI.label({
		Name = "MinigameCountdown",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(220, 160),
		TextSize = 120,
		TextColor3 = Color3.fromRGB(255, 220, 90),
		TextStrokeTransparency = 0.2,
		Visible = false,
		Parent = root,
	})
	joinButton = UI.button({
		Name = "MinigameJoin",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 180),
		Size = UDim2.fromOffset(220, 50),
		Text = ClientState.t("minigame.join"),
		swatch = "sky",
		Visible = false,
		Parent = root,
	}, function()
		if lobby then
			Net.get("MinigameAction"):FireServer("join", lobby.id)
		end
	end)
	cheerButton = UI.button({
		Name = "MinigameCheer",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 236),
		Size = UDim2.fromOffset(200, 46),
		Text = "📣 " .. ClientState.t("minigame.cheer"),
		swatch = "ie",
		Visible = false,
		Parent = root,
	}, function()
		Net.get("MinigameAction"):FireServer("act", { cheer = true })
	end)
	batButton = UI.button({
		Name = "MinigameBat",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 236),
		Size = UDim2.fromOffset(200, 50),
		Text = "⚾ " .. ClientState.t("minigame.bat"),
		swatch = "vine",
		Visible = false,
		Parent = root,
	}, function()
		Net.get("MinigameAction"):FireServer("act", { bat = true })
	end)
	laughButton = UI.button({
		Name = "MinigameLaugh",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 236),
		Size = UDim2.fromOffset(200, 50),
		Text = "😆 " .. ClientState.t("minigame.laugh"),
		swatch = "wheat",
		Visible = false,
		Parent = root,
	}, function()
		Net.get("MinigameAction"):FireServer("act", { laugh = true })
	end)
	rhythmButton = UI.button({
		Name = "MinigameRhythm",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -90),
		Size = UDim2.fromOffset(220, 70),
		Text = "🍇 " .. ClientState.t("minigame.stomp"),
		swatch = "plum",
		Visible = false,
		Parent = root,
	}, function()
		local pressed = Workspace:GetServerTimeNow()
		Net.get("MinigameAction"):FireServer("act", { press = pressed })
		local beats = rhythmBeats
		if beats then
			local t = pressed - rhythmStart
			local judgement = Rhythm.judge(beats[Rhythm.nearest(beats, t)], t)
			NotifyController.toast(judgement, "quiet")
		end
	end)
	stationButton = UI.button({
		Name = "MinigameStation",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -90),
		Size = UDim2.fromOffset(240, 60),
		Text = "",
		swatch = "wheat",
		Visible = false,
		Parent = root,
	}, function()
		if stationId then
			Net.get("MinigameAction"):FireServer("act", { station = stationId })
		end
	end)
	blindfold = UI.frame({
		Name = "Blindfold",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 20,
		Parent = root,
	})
	UI.label({
		Size = UDim2.fromScale(1, 0.3),
		Position = UDim2.fromScale(0, 0.35),
		Text = ClientState.t("minigame.blind"),
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 28,
		ZIndex = 21,
		Parent = blindfold,
	})
	blur = Instance.new("BlurEffect")
	blur.Name = "SeekerBlur"
	blur.Size = 20
	blur.Enabled = false
	blur.Parent = game:GetService("Lighting")
	panel, scroll = UI.panel(ClientState.t("minigame.title"), function()
		UI.show(panel, false)
	end)
	choicePanel, choiceScroll = UI.panel(ClientState.t("minigame.choose"), function()
		UI.show(choicePanel, false)
	end)
	applyLayout()
	Layout.onChanged(applyLayout)
	Net.get("Minigame").OnClientEvent:Connect(onMinigame)
	RunService.RenderStepped:Connect(function()
		local now = Workspace:GetServerTimeNow()
		-- „Intră” doar lângă locul înscrierii deschise
		local open = lobby ~= nil and (lobby.closesAt or 0) > now and nearSite(lobby.site)
		if joinButton.Visible ~= open then
			joinButton.Visible = open
		end
		local beats = rhythmBeats
		if beats and rhythmButton.Visible then
			local t = now - rhythmStart
			local nearest = beats[Rhythm.nearest(beats, t)]
			local pulse = math.clamp(1 - math.abs(t - nearest) / 0.2, 0, 1)
			rhythmButton.Size = UDim2.fromOffset(220 + pulse * 24, 70 + pulse * 10)
		end
		local game_ = running
		-- stația cea mai apropiată (plăcintăria): un buton cu ce faci acolo
		local nearestStation, nearestText = nil, nil
		local extraNow = game_ and game_.extra
		local character = localPlayer.Character
		local myRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if myRoot and typeof(extraNow) == "table" and extraNow.stations then
			local best = 7
			for _, station in extraNow.stations do
				local d = Vector3.new(
					station.position.X - myRoot.Position.X,
					0,
					station.position.Z - myRoot.Position.Z
				).Magnitude
				if d < best then
					best, nearestStation, nearestText = d, station.id, station.text
				end
			end
		end
		stationId = nearestStation
		if (nearestStation ~= nil) ~= stationButton.Visible then
			stationButton.Visible = nearestStation ~= nil
		end
		if nearestText then
			stationButton.Text = ClientState.t(nearestText)
		end
		if game_ then
			if game_.startsAt and now < game_.startsAt then
				countdown.Visible = true
				countdown.Text = tostring(math.ceil(game_.startsAt - now))
			elseif game_.startsAt and now < game_.startsAt + 0.8 then
				countdown.Visible = true
				countdown.Text = ClientState.t("minigame.go")
			else
				countdown.Visible = false
			end
			if game_.scores then
				renderBoard(game_)
			end
			local extra = game_.extra
			local me = localPlayer.UserId
			local isSeeker = typeof(extra) == "table"
				and (extra.seeker == me or (extra.seekers and table.find(extra.seekers, me) ~= nil))
			local hiding = isSeeker and typeof(extra.hideUntil) == "number" and now < extra.hideUntil
			if blindfold.Visible ~= (hiding == true) then
				blindfold.Visible = hiding == true
			end
			-- Bunica legată la ochi (ascunselea): după numărătoare vede încețoșat, doar aproape
			local blurred = typeof(extra) == "table" and extra.seeker == me and not hiding
			if blur.Enabled ~= (blurred == true) then
				blur.Enabled = blurred == true
			end
		elseif countdown.Visible then
			countdown.Visible = false
		end
	end)
end

return MinigameController
