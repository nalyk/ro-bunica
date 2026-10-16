--!strict
-- Ochitul și aruncarea: click pe PC, atingere scurtă pe mobil. Serverul decide lovitura.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Defense = require(Shared.Config.Defense)
local ClientState = require(script.Parent.ClientState)

local TAP_MAX_SECONDS = 0.3
local TAP_MAX_MOVE = 12 -- pixeli; peste asta e rotire de cameră, nu aruncare
local LOCAL_COOLDOWN = 0.25
local AIM_DISTANCE = 300

local SlipperController = {}

local armed: "Slipper" | "RollingPin" = "Slipper"
local lastThrowAt = 0
local armedListeners: { () -> () } = {}

function SlipperController.armed(): string
	return armed
end

function SlipperController.arm(kind: "Slipper" | "RollingPin")
	armed = kind
	for _, callback in armedListeners do
		task.spawn(callback)
	end
end

function SlipperController.onArmedChanged(callback: () -> ())
	table.insert(armedListeners, callback)
end

-- Muniția estimată local, din ultima stare și timpul de reîncărcare.
function SlipperController.predictedAmmo(): number
	local state = ClientState.state
	local ammo = state.ammo or 0
	local maxAmmo = state.maxAmmo or Defense.slipper.maxAmmo
	if ammo >= maxAmmo or not state.ammoRegenStart then
		return ammo
	end
	local regenerated = math.floor(
		(Workspace:GetServerTimeNow() - state.ammoRegenStart)
			/ (state.ammoRegenSeconds or Defense.slipper.regenSeconds)
	)
	return math.min(ammo + math.max(regenerated, 0), maxAmmo)
end

-- `viewport` = coordonate cu inset (mouse); altfel coordonate fără inset (atingere).
local function aimPoint(screenPosition: Vector2, viewport: boolean): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local ray = if viewport
		then camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
		else camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local character = Players.LocalPlayer.Character
	params.FilterDescendantsInstances = if character then { character } else {}
	local result = Workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, params)
	return if result then result.Position else ray.Origin + ray.Direction * 120
end

local function throw(screenPosition: Vector2, viewport: boolean)
	local now = os.clock()
	if now - lastThrowAt < LOCAL_COOLDOWN then
		return
	end
	local kind = armed
	if kind == "Slipper" and SlipperController.predictedAmmo() < 1 then
		return
	end
	if kind == "RollingPin" and (ClientState.state.nervi or 0) < Defense.rollingPin.cost then
		SlipperController.arm("Slipper")
		return
	end
	local target = aimPoint(screenPosition, viewport)
	if not target then
		return
	end
	lastThrowAt = now
	Net.get("Throw"):FireServer(target, kind)
	if kind ~= "Slipper" then
		SlipperController.arm("Slipper")
	end
end

-- Aruncare spre un punct al ecranului în coordonate de viewport (gamepad: ținta fixă, camera ochește)
function SlipperController.throwAtViewport(point: Vector2)
	throw(point, true)
end

function SlipperController.start()
	local touchStarts: { [InputObject]: { at: number, position: Vector2 } } = {}

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			throw(UserInputService:GetMouseLocation(), true)
		elseif input.UserInputType == Enum.UserInputType.Touch then
			touchStarts[input] =
				{ at = os.clock(), position = Vector2.new(input.Position.X, input.Position.Y) }
		end
	end)

	UserInputService.InputEnded:Connect(function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local start = touchStarts[input]
		touchStarts[input] = nil
		if processed or not start then
			return
		end
		local position = Vector2.new(input.Position.X, input.Position.Y)
		if
			os.clock() - start.at <= TAP_MAX_SECONDS
			and (position - start.position).Magnitude <= TAP_MAX_MOVE
		then
			throw(position, false)
		end
	end)
end

return SlipperController
