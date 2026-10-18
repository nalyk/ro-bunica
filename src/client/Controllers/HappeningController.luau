--!strict
-- Ceasul satului pe client: anunțul („În 30 s: Gâștele au scăpat!”) prin coada de mesaje, un semn cu cronometru
-- deasupra locului (se vede de departe, prin dealuri) și o săgeată deasupra jucătorului, spre loc. Nicio
-- fereastră nouă în HUD: totul trece prin NotifyController și prin lume.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local ClientState = require(script.Parent.ClientState)
local NotifyController = require(script.Parent.NotifyController)
local UI = require(script.Parent.UI)
local Economy = require(Shared.Domain.Economy)

local HappeningController = {}

type Payload = {
	id: string,
	state: string,
	startsAt: number?,
	endsAt: number?,
	location: Vector3?,
	extra: any?,
}

local current: Payload? = nil
local marker: BasePart? = nil
local timerLabel: TextLabel? = nil
local arrow: BasePart? = nil
local shopPanel: Frame
local shopScroll: ScrollingFrame
local confetti: BasePart? = nil

-- Negustorul: panoul cu cele 3 semințe, cât stai lângă el
local function renderShop(extra: any)
	UI.clear(shopScroll)
	UI.list(shopScroll, Enum.FillDirection.Vertical, 6)
	for order, offer in extra.offers do
		UI.button({
			Size = UDim2.new(1, -12, 0, 50),
			LayoutOrder = order,
			Text = ClientState.t("creature." .. offer.seedId)
				.. "  "
				.. Economy.formatShort(offer.price)
				.. " lei",
			swatch = "wheat",
			icon = "lei",
			Parent = shopScroll,
		}, function()
			Net.get("HappeningAction"):FireServer({ buy = offer.seedId })
		end)
	end
end

-- Nunta: un nor de confetti care urmează cortegiul
local function weddingAt(position: Vector3)
	local part = confetti
	if not part then
		local p = Instance.new("Part")
		p.Name = "Confetti"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(8, 1, 8)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Rate = 40
		emitter.Lifetime = NumberRange.new(1.5, 2.5)
		emitter.Speed = NumberRange.new(6, 10)
		emitter.SpreadAngle = Vector2.new(60, 60)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-180, 180)
		emitter.Acceleration = Vector3.new(0, -8, 0)
		emitter.Size = NumberSequence.new(0.35)
		emitter.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 120)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 220, 80)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 180, 255)),
		})
		emitter.Parent = p
		p.Parent = Workspace
		confetti = p
		part = p
	end
	(part :: BasePart).Position = position + Vector3.new(0, 9, 0)
end

local function clear()
	if confetti then
		confetti:Destroy()
		confetti = nil
	end
	if shopPanel then
		UI.show(shopPanel, false)
	end
	if marker then
		marker:Destroy()
		marker = nil
		timerLabel = nil
	end
	if arrow then
		arrow:Destroy()
		arrow = nil
	end
end

local function buildMarker(location: Vector3, title: string)
	clear()
	local anchor = Instance.new("Part")
	anchor.Name = "HappeningMarker"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = location + Vector3.new(0, 18, 0)
	anchor.Parent = Workspace
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 90)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 2000
	gui.Adornee = anchor
	gui.Parent = anchor
	local name = Instance.new("TextLabel")
	name.Size = UDim2.fromScale(1, 0.55)
	name.BackgroundTransparency = 1
	name.TextScaled = true
	name.Font = Enum.Font.FredokaOne
	name.TextColor3 = Color3.fromRGB(255, 220, 90)
	name.TextStrokeTransparency = 0.2
	name.Text = "❗ " .. title
	name.Parent = gui
	local timer = name:Clone()
	timer.Position = UDim2.fromScale(0, 0.55)
	timer.Size = UDim2.fromScale(1, 0.45)
	timer.TextColor3 = Color3.new(1, 1, 1)
	timer.Text = ""
	timer.Parent = gui
	marker = anchor
	timerLabel = timer
	-- săgeata de deasupra jucătorului
	local a = Instance.new("Part")
	a.Name = "HappeningArrow"
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.CanTouch = false
	a.CastShadow = false
	a.Material = Enum.Material.Neon
	a.Color = Color3.fromRGB(255, 210, 60)
	a.Size = Vector3.new(0.6, 0.3, 2.6)
	local tip = Instance.new("SpecialMesh")
	tip.MeshType = Enum.MeshType.Wedge
	tip.Parent = a
	a.Parent = Workspace
	arrow = a
end

-- Pentru playtest
function HappeningController.debugState(): { [string]: any }
	return {
		id = current and current.id,
		state = current and current.state,
		marker = marker ~= nil,
		shop = shopPanel and shopPanel.Visible,
		timer = timerLabel and timerLabel.Text,
	}
end

local function onHappening(payload: Payload)
	local title = ClientState.t("happening." .. payload.id)
	if payload.state == "end" then
		current = nil
		clear()
		return
	end
	local previous = current
	current = payload
	if
		payload.location
		and not (previous and previous.id == payload.id and previous.state == payload.state and marker)
	then
		buildMarker(payload.location, title)
	end
	local extra = payload.extra
	if typeof(extra) == "table" then
		if extra.offers then
			renderShop(extra)
		end
		if typeof(extra.wedding) == "Vector3" then
			weddingAt(extra.wedding)
		end
		if previous and previous.id == payload.id and previous.state == payload.state then
			return -- doar datele s-au schimbat: fără un nou anunț
		end
	end
	if payload.state == "warn" then
		local seconds = math.max(0, math.floor((payload.startsAt or 0) - Workspace:GetServerTimeNow()))
		NotifyController.notice(
			"happening.warn",
			ClientState.t("happening.warn", { tostring(seconds), title })
		)
	else
		NotifyController.notice("happening.go", ClientState.t("happening.go", { title }))
	end
end

function HappeningController.start()
	shopPanel, shopScroll = UI.panel(ClientState.t("happening.Negustor"), function()
		UI.show(shopPanel, false)
	end)
	Net.get("Happening").OnClientEvent:Connect(onHappening)
	RunService.RenderStepped:Connect(function()
		local payload = current
		if not payload then
			return
		end
		local now = Workspace:GetServerTimeNow()
		local target = if payload.state == "warn" then payload.startsAt else payload.endsAt
		if timerLabel and target then
			timerLabel.Text = string.format("%d s", math.max(0, math.ceil(target - now)))
		end
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		-- lângă negustor (10 studs) apare oferta; când pleci, dispare
		local extra = payload.extra
		if
			root
			and typeof(extra) == "table"
			and typeof(extra.merchant) == "Vector3"
			and (extra.left or 3) > 0
		then
			local near = (root.Position - extra.merchant).Magnitude <= 10
			if near ~= shopPanel.Visible then
				UI.show(shopPanel, near)
			end
		end
		local a = arrow
		if a and root and payload.location then
			local from = root.Position + Vector3.new(0, 4.6, 0)
			local flat = Vector3.new(payload.location.X - from.X, 0, payload.location.Z - from.Z)
			a.Transparency = if flat.Magnitude < 25 then 1 else 0.1 -- ajuns: săgeata dispare
			if flat.Magnitude > 0.1 then
				a.CFrame = CFrame.lookAt(from, from + flat.Unit) * CFrame.Angles(0, math.pi, 0)
			end
		end
	end)
end

return HappeningController
