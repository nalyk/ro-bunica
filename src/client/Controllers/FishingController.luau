--!strict
-- Pescuitul pe client: lângă iaz apare „Aruncă undița”; după tremur, „Trage!” și bara de tensiune (zona verde
-- e cea bună; ții apăsat ca să tragi, lași ca să slăbești). Apăsările se trimit pe pași de 0,1 s; serverul
-- refă tragerea (Domain/Fishing). Panoul „Pescuit”: șansele de acum și colecția, cu „Vinde”.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local GameState = require(Shared.GameState)
local Fish = require(Shared.Config.Fish)
local Fishing = require(Shared.Domain.Fishing)
local VillageLayout = require(Shared.Domain.VillageLayout)
local ClientState = require(script.Parent.ClientState)
local NotifyController = require(script.Parent.NotifyController)
local UI = require(script.Parent.UI)
local Theme = require(script.Parent.Theme)

local FishingController = {}

local pond = VillageLayout.build().sites.iaz.Position
local state = "idle" -- "idle" | "waiting" | "bite" | "reeling"
local castButton: TextButton
local collectionButton: TextButton
local holdButton: TextButton
local meter: Frame
local tensionFill: Frame
local progressFill: Frame
local panel: Frame
local scroll: ScrollingFrame
local holding = false
local reel: Fishing.Reel? = nil
local pulls: { number } = {}
local inputs: { boolean } = {}
local accumulator = 0
local reelStarted = 0

local function near(): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil
		and Vector3.new(root.Position.X - pond.X, 0, root.Position.Z - pond.Z).Magnitude
			<= Fish.castDistance
end

local function finishReel()
	state = "idle"
	meter.Visible = false
	holdButton.Visible = false
	Net.get("Fishing"):FireServer("reel", inputs)
	reel = nil
end

local function renderPanel()
	UI.clear(scroll)
	UI.list(scroll, Enum.FillDirection.Vertical, 6)
	local weather = GameState.get(GameState.Attributes.Weather)
	local season = GameState.get(GameState.Attributes.Season)
	local odds = Fishing.odds(
		if typeof(weather) == "string" then weather else "",
		if typeof(season) == "string" and season ~= "" then season else "Vara"
	)
	local order = 0
	local function line(text: string)
		order += 1
		UI.label({
			Size = UDim2.new(1, -12, 0, 26),
			LayoutOrder = order,
			Text = text,
			TextColor3 = Theme.ink,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = scroll,
		})
	end
	line("🎲 " .. ClientState.t("fishing.odds"))
	for _, fish in Fish.list do
		local p = odds[fish.id]
		if p then
			line(string.format("   %s  %.1f%%", ClientState.t("fish." .. fish.id), p * 100))
		end
	end
	line("🐟 " .. ClientState.t("fishing.collection"))
	local mine = ClientState.state.fish or {}
	for _, fish in Fish.list do
		local n = mine[fish.id] or 0
		if n > 0 and fish.sell > 0 then
			order += 1
			UI.button({
				Size = UDim2.new(1, -12, 0, 46),
				LayoutOrder = order,
				Text = string.format(
					"%s ×%d · %s %d lei",
					ClientState.t("fish." .. fish.id),
					n,
					ClientState.t("fishing.sell"),
					fish.sell * n
				),
				swatch = "wheat",
				icon = "lei",
				Parent = scroll,
			}, function()
				Net.get("Fishing"):FireServer("sell", fish.id, n)
			end)
		end
	end
end

-- Pentru playtest
function FishingController.debugState(): { [string]: any }
	return { state = state, cast = castButton.Visible, meter = meter.Visible }
end

function FishingController.start()
	local root = UI.screen()
	castButton = UI.button({
		Name = "FishingCast",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, -60, 1, -90),
		Size = UDim2.fromOffset(200, 56),
		Text = "🎣 " .. ClientState.t("fishing.cast"),
		swatch = "sky",
		Visible = false,
		Parent = root,
	}, function()
		Net.get("Fishing"):FireServer("cast")
	end)
	collectionButton = UI.button({
		Name = "FishingCollection",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 100, 1, -90),
		Size = UDim2.fromOffset(110, 56),
		Text = "🐟",
		swatch = "wheat",
		Visible = false,
		Parent = root,
	}, function()
		UI.show(panel, not panel.Visible)
		if panel.Visible then
			renderPanel()
		end
	end)
	meter = UI.frame({
		Name = "FishingMeter",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -160),
		Size = UDim2.fromOffset(300, 40),
		BackgroundColor3 = Theme.paper,
		Visible = false,
		Parent = root,
	})
	UI.frame({
		Position = UDim2.fromScale(Fishing.SWEET_LOW, 0),
		Size = UDim2.fromScale(Fishing.SWEET_HIGH - Fishing.SWEET_LOW, 0.55),
		BackgroundColor3 = Color3.fromRGB(120, 200, 120),
		Parent = meter,
	})
	tensionFill = UI.frame({
		Size = UDim2.fromScale(0, 0.55),
		BackgroundColor3 = Color3.fromRGB(230, 80, 60),
		BackgroundTransparency = 0.3,
		Parent = meter,
	})
	progressFill = UI.frame({
		Position = UDim2.fromScale(0, 0.65),
		Size = UDim2.fromScale(0, 0.35),
		BackgroundColor3 = Color3.fromRGB(70, 130, 210),
		Parent = meter,
	})
	holdButton = UI.button({
		Name = "FishingHold",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -90),
		Size = UDim2.fromOffset(200, 60),
		Text = "🎣 " .. ClientState.t("fishing.hold"),
		swatch = "vine",
		Visible = false,
		Parent = root,
	}, function() end)
	holdButton.MouseButton1Down:Connect(function()
		holding = true
	end)
	holdButton.MouseButton1Up:Connect(function()
		holding = false
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			holding = false
		end
	end)
	panel, scroll = UI.panel(ClientState.t("fishing.title"), function()
		UI.show(panel, false)
	end)
	Net.get("Fishing").OnClientEvent:Connect(function(payload: { [string]: any })
		if payload.state == "waiting" then
			state = "waiting"
			NotifyController.notice("fishing.wait", ClientState.t("fishing.wait"), "quiet")
		elseif payload.state == "bite" then
			state = "reeling"
			NotifyController.notice("fishing.bite", ClientState.t("fishing.bite"), "urgent")
			reel = Fishing.newReel()
			pulls = Fishing.pulls(payload.seed, Fish.maxSteps)
			inputs = {}
			accumulator = 0
			reelStarted = os.clock()
			meter.Visible = true
			holdButton.Visible = true
		elseif payload.state == "result" then
			state = "idle"
			meter.Visible = false
			holdButton.Visible = false
			if payload.fish then
				NotifyController.notice(
					"fishing.caught",
					ClientState.t("fishing.caught", { ClientState.t("fish." .. payload.fish) }),
					"reward"
				)
			elseif payload.outcome == "Snapped" then
				NotifyController.notice("fishing.snapped", ClientState.t("fishing.snapped"), "hint")
			else
				NotifyController.notice("fishing.escaped", ClientState.t("fishing.escaped"), "hint")
			end
			if panel.Visible then
				renderPanel()
			end
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local isNear = near()
		local idle = state == "idle"
		if castButton.Visible ~= (isNear and idle) then
			castButton.Visible = isNear and idle
		end
		if collectionButton.Visible ~= isNear then
			collectionButton.Visible = isNear
		end
		local current = reel
		if state ~= "reeling" or not current then
			return
		end
		accumulator += dt
		while accumulator >= Fish.reelStep and current.state == "Reeling" do
			accumulator -= Fish.reelStep
			local step = #inputs + 1
			inputs[step] = holding or UserInputService:IsKeyDown(Enum.KeyCode.Space)
			Fishing.reel(current, inputs[step], Fish.reelStep, pulls[step] or 0)
			if step >= Fish.maxSteps then
				current.state = "Escaped"
			end
		end
		tensionFill.Size = UDim2.fromScale(math.clamp(current.tension, 0, 1), 0.55)
		progressFill.Size = UDim2.fromScale(math.clamp(current.progress, 0, 1), 0.35)
		if current.state ~= "Reeling" or os.clock() - reelStarted > Fish.maxSteps * Fish.reelStep then
			finishReel()
		end
	end)
	ClientState.onChanged(function()
		if panel.Visible then
			renderPanel()
		end
	end)
end

return FishingController
