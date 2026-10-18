--!strict
-- Navigarea spre ținta aleasă pe hartă: o potecă de puncte „cusute” pe pământ (roșu și alb, ca broderia),
-- pe drumul calculat de PathfindingService, doar bucata din fața jucătorului, recalculată din mers. Un
-- val de lumină trece prin puncte spre țintă; la sosire poteca dispare. Totul local (piese în cameră).

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Waypoint = require(Shared.Domain.Waypoint)
local MapMarkers = require(script.Parent.MapMarkers)
local ClientState = require(script.Parent.ClientState)
local NotifyController = require(script.Parent.NotifyController)

local WaypointController = {}

local SPACING = 3.2
local AHEAD = 72 -- studs de potecă vizibilă
local ARRIVE = 12
local REPATH = 1.2
local RED = Color3.fromRGB(220, 40, 50)
local WHITE = Color3.fromRGB(255, 246, 230)

local me = Players.LocalPlayer
local folder: Folder? = nil
local dots: { BasePart } = {}
local points: { Vector3 } = {}
local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 6, AgentCanJump = true })

local function rootPosition(): Vector3?
	local character = me.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

local function container(): Folder
	if not folder or not folder.Parent then
		local made = Instance.new("Folder")
		made.Name = "PotecaTintei"
		made.Parent = Workspace.CurrentCamera
		folder = made
	end
	return folder :: Folder
end

local function dot(index: number): BasePart
	local existing: BasePart? = dots[index]
	if existing then
		return existing
	end
	do
		local part = Instance.new("Part")
		part.Name = "Punct"
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(0.12, 0.9, 0.9)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = if index % 2 == 0 then RED else WHITE
		part.Parent = container()
		dots[index] = part
		return part
	end
end

local function clear()
	points = {}
	for _, part in dots do
		part:Destroy()
	end
	dots = {}
end

-- Drumul de la jucător la țintă: Pathfinding, altfel linie dreaptă
local function compute(from: Vector3, target: Vector3): { Vector3 }
	local ok = pcall(path.ComputeAsync, path, from, target)
	if ok and path.Status == Enum.PathStatus.Success then
		local list = {}
		for _, waypoint in path:GetWaypoints() do
			table.insert(list, waypoint.Position)
		end
		return list
	end
	return { from - Vector3.new(0, 2.5, 0), target }
end

local function refresh()
	local target = MapMarkers.waypoint()
	local from = rootPosition()
	if not target or not from then
		return
	end
	if Waypoint.arrived(from, target, ARRIVE) then
		MapMarkers.setWaypoint(nil)
		NotifyController.notice("map.arrived", ClientState.t("map.arrived"), "hint")
		return
	end
	points = Waypoint.trail(compute(from, target), SPACING, AHEAD)
	for i, p in points do
		dot(i).CFrame = CFrame.new(p + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	end
	for i = #points + 1, #dots do
		dots[i]:Destroy()
		dots[i] = nil
	end
end

function WaypointController.start()
	MapMarkers.onWaypoint(function(position)
		if not position then
			clear()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(REPATH)
			if MapMarkers.waypoint() then
				refresh()
			elseif #dots > 0 then
				clear()
			end
		end
	end)
	-- valul de lumină: fiecare punct crește și se aprinde când trece unda spre țintă
	RunService.RenderStepped:Connect(function()
		if #dots == 0 then
			return
		end
		local t = os.clock() * 9
		for i, part in dots do
			local wave = math.max(0, math.cos((i - t) * 0.5)) ^ 6
			local size = 0.8 + wave * 0.7
			part.Size = Vector3.new(0.12, size, size)
			part.Transparency = 0.35 - wave * 0.35
		end
	end)
end

return WaypointController
