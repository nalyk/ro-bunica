--!strict
-- Rutiera (Domain/Rutiera, Config/Rutiera): microbuzul galben ocolește satul în 150 s, după ceasul serverului
-- (toți îl văd în același loc). Pasagerii stau sudați de el; cine își alege o stație coboară singur acolo.
-- Atributele vehiculului: RutieraAt (0–1 pe circuit), RutieraNext (următoarea stație), RutieraStop (stația în
-- care stă acum, "" în mers).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ArtLibrary = require(Shared.Visual.ArtLibrary)
local Net = require(Shared.Net)
local Config = require(Shared.Config.Rutiera)
local Rutiera = require(Shared.Domain.Rutiera)
local VillageLayout = require(Shared.Domain.VillageLayout)
local RateLimiter = require(Shared.Domain.RateLimiter)
local Actors = require(script.Parent.Parent.Actors)
local RaidService = require(script.Parent.RaidService)
local Messenger = require(script.Parent.Messenger)

type Actor = Actors.Actor
type Rider = { seat: number, destination: string?, weld: WeldConstraint }

local RutieraService = {}

local GROUND = -1
local circuit: Rutiera.Circuit
local stops: { Rutiera.Stop }
local schedule: Rutiera.Schedule
local vehicle: Model
local body: BasePart
local riders: { [Actor]: Rider } = {}
local offset = 0 -- pentru teste: sare în timp
local limiter = RateLimiter.new(4, 1)

local function clock(): number
	return Workspace:GetServerTimeNow() + offset
end

-- Pentru teste: mută ceasul rutierei înainte (secunde)
function RutieraService.warp(seconds: number)
	offset += seconds
end

function RutieraService.vehicle(): Model
	return vehicle
end

function RutieraService.stops(): { Rutiera.Stop }
	return stops
end

-- Secundele până când rutiera ajunge în stația dată
function RutieraService.secondsTo(name: string): number
	local now = clock() % schedule.period
	local at = Rutiera.arrival(schedule, name)
	return (at - now) % schedule.period
end

function RutieraService.isRiding(actor: Actor): boolean
	return riders[actor] ~= nil
end

local function part(
	name: string,
	size: Vector3,
	offsetCf: CFrame,
	color: Color3,
	material: Enum.Material?
): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.CFrame = offsetCf
	p.Parent = vehicle
	return p
end

local function buildVehicle(): Model
	vehicle = Instance.new("Model")
	vehicle.Name = "Rutiera"
	local s = Config.size
	body = Instance.new("Part")
	body.Name = "Caroserie"
	body.Size = s
	body.Color = Config.color
	body.Anchored = true
	body.CanCollide = false -- un microbuz de desen animat: nu trântește copiii (pasagerii sunt sudați)
	body.Material = Enum.Material.SmoothPlastic
	body.Parent = vehicle
	vehicle.PrimaryPart = body
	local function weldTo(p: BasePart, local_: CFrame)
		p.CFrame = body.CFrame * local_
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = p
		weld.Parent = p
	end
	-- microbuzul sculptat, dacă există: caroseria rămâne ca rădăcină invizibilă, piesele sudate de ea
	local art = ArtLibrary.get("char.Rutiera")
	if art then
		local _, size = art:GetBoundingBox()
		local turned = size.X > size.Z -- lungimea microbuzului trebuie să fie pe Z
		art:ScaleTo(s.Z / math.max(size.X, size.Z))
		art:PivotTo(body.CFrame * (if turned then CFrame.Angles(0, math.pi / 2, 0) else CFrame.identity))
		local box, scaled = art:GetBoundingBox()
		art:PivotTo(
			art:GetPivot()
				+ (
					body.Position
					- Vector3.new(0, s.Y / 2, 0)
					- Vector3.new(box.X, box.Y - scaled.Y / 2, box.Z)
				)
		)
		for _, p in art:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = false
				p.CanCollide = false
				p.CanQuery = false
				p.Massless = true
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = body
				weld.Part1 = p
				weld.Parent = p
			end
		end
		art.Name = "Sculptat"
		art.Parent = vehicle
		body.Transparency = 1
	end
	local glass = Color3.fromRGB(70, 90, 110)
	for _, side in (if art then {} else { -1, 1 }) :: { number } do
		weldTo(
			part("Geamuri", Vector3.new(0.1, 2.2, s.Z - 4), CFrame.identity, glass, Enum.Material.Glass),
			CFrame.new(side * (s.X / 2 + 0.05), 1.4, 0.5)
		)
		for _, z in { -s.Z / 2 + 3, s.Z / 2 - 3 } do
			local wheel =
				part("Roata", Vector3.new(1.2, 2.6, 2.6), CFrame.identity, Color3.fromRGB(30, 30, 30));
			(wheel :: Part).Shape = Enum.PartType.Cylinder
			weldTo(wheel, CFrame.new(side * (s.X / 2 - 0.3), -s.Y / 2 + 0.6, z))
		end
	end
	if not art then
		weldTo(
			part("Parbriz", Vector3.new(s.X - 0.6, 2.6, 0.1), CFrame.identity, glass, Enum.Material.Glass),
			CFrame.new(0, 1.3, -s.Z / 2 - 0.05)
		)
		weldTo(
			part(
				"Dunga",
				Vector3.new(s.X + 0.1, 0.5, s.Z + 0.1),
				CFrame.identity,
				Color3.fromRGB(40, 90, 170)
			),
			CFrame.new(0, -0.6, 0)
		)
		weldTo(
			part(
				"Faruri",
				Vector3.new(s.X - 1.6, 0.6, 0.1),
				CFrame.identity,
				Color3.fromRGB(255, 250, 220),
				Enum.Material.Neon
			),
			CFrame.new(0, -1.6, -s.Z / 2 - 0.05)
		)
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UrcaPrompt"
	prompt.ActionText = "Urcă"
	prompt.ObjectText = "Rutiera"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.boardDistance
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("TextKey", "rutiera.board")
	prompt.Parent = body
	prompt.Triggered:Connect(function(player)
		RutieraService.board(Actors.forPlayer(player))
	end)
	vehicle.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- toți o văd, de oriunde
	vehicle.Parent = Workspace
	return vehicle
end

local function seatCFrame(index: number): CFrame
	local s = Config.size
	local row = (index - 1) // 2
	local side = if index % 2 == 1 then -1 else 1
	return body.CFrame * CFrame.new(side * 1.6, -s.Y / 2 + 2.6, -s.Z / 2 + 5 + row * 2.6)
end

local function freeSeat(): number?
	local taken = {}
	for _, rider in riders do
		taken[rider.seat] = true
	end
	for i = 1, Config.seats do
		if not taken[i] then
			return i
		end
	end
	return nil
end

local function tell(actor: Actor)
	if actor.player then
		local rider = riders[actor]
		Net.get("Rutiera")
			:FireClient(actor.player, { riding = rider ~= nil, destination = rider and rider.destination })
	end
end

-- Urcă un actor aflat lângă rutieră. Întoarce true dacă a urcat.
function RutieraService.board(actor: Actor): boolean
	local root = Actors.root(actor)
	local character = Actors.characterOf(actor)
	if riders[actor] or not root or not character then
		return false
	end
	if RaidService.isCarrying(actor) then
		Messenger.notify(actor.player, "rutiera.carrying")
		return false
	end
	if (root.Position - body.Position).Magnitude > Config.boardDistance + Config.size.Z / 2 then
		return false
	end
	local seat = freeSeat()
	if not seat then
		Messenger.notify(actor.player, "rutiera.full")
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Sit = true
	end
	character:PivotTo(seatCFrame(seat))
	local weld = Instance.new("WeldConstraint")
	weld.Name = "RutieraWeld"
	weld.Part0 = body
	weld.Part1 = root
	weld.Parent = body
	riders[actor] = { seat = seat, destination = nil, weld = weld }
	tell(actor)
	return true
end

-- Alege stația la care coboară (numele din `stops()`), sau coboară acum (nil)
function RutieraService.alight(actor: Actor, stopName: string?): boolean
	local rider = riders[actor]
	if not rider then
		return false
	end
	if stopName then
		for _, stop in stops do
			if stop.name == stopName then
				rider.destination = stopName
				tell(actor)
				return true
			end
		end
		return false
	end
	rider.weld:Destroy()
	riders[actor] = nil
	local character = Actors.characterOf(actor)
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Sit = false
		end
		-- coboară pe partea ușii (dreapta), pe drum
		character:PivotTo(
			body.CFrame * CFrame.new(Config.size.X / 2 + 3, 0, 0)
				- Vector3.new(0, body.Position.Y - GROUND - 3, 0)
		)
	end
	tell(actor)
	return true
end

local function step()
	local t = Rutiera.progress(schedule, clock())
	local position, direction = Rutiera.at(circuit, t)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	local right = flat.Unit:Cross(Vector3.yAxis)
	local at = Vector3.new(position.X, GROUND + Config.size.Y / 2 + 1, position.Z) + right * Config.sideOffset
	body.CFrame = CFrame.lookAt(at, at + flat.Unit)
	local next = Rutiera.nextStop(stops, t)
	local here = ""
	for _, stop in stops do
		if math.abs(stop.t - t) < 1e-9 then
			here = stop.name
		end
	end
	vehicle:SetAttribute("RutieraAt", t)
	vehicle:SetAttribute("RutieraNext", next.name)
	vehicle:SetAttribute("RutieraStop", here)
	if here ~= "" then
		for actor, rider in riders do
			if rider.destination == here then
				RutieraService.alight(actor, nil)
			end
		end
	end
	for actor in riders do
		if not actor.alive or not Actors.root(actor) then
			riders[actor] = nil
		end
	end
end

function RutieraService.init()
	local layout = VillageLayout.build()
	circuit = Rutiera.circuit(layout)
	stops = Rutiera.stops(layout, circuit)
	schedule = Rutiera.schedule(stops, Config.period, Config.dwell)
	buildVehicle()
	step()
end

function RutieraService.start()
	Net.get("Rutiera").OnServerEvent:Connect(function(player, action, stop)
		if not limiter:allow(player.UserId, os.clock()) then
			return
		end
		local actor = Actors.forPlayer(player)
		if action == "board" then
			RutieraService.board(actor)
		elseif action == "alight" then
			RutieraService.alight(actor, nil)
		elseif action == "destination" and typeof(stop) == "string" then
			RutieraService.alight(actor, stop)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for actor in riders do
			if actor.player == player then
				riders[actor] = nil
			end
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return RutieraService
