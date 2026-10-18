--!strict
-- Unelte pentru trasee cu porți (Domain/Course): porțile vizibile, câte o cursă pe jucător, reapariția la
-- ultima poartă (după ieșirea de pe culoar, o scurtătură sau o cădere).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Course = require(Shared.Domain.Course)
local Kit = require(script.Parent.Parent.Happenings.Kit)
local Actors = require(script.Parent.Parent.Actors)

local RaceKit = {}

-- Poarta: doi stâlpi și o bandă cu numărul
function RaceKit.gate(index: number, at: Vector3, facing: Vector3, parent: Instance, color: Color3)
	local cf = CFrame.lookAt(at, at + Vector3.new(facing.X, 0, facing.Z))
	for _, side in { -4, 4 } do
		local post = Instance.new("Part")
		post.Name = "Poarta" .. index
		post.Anchored = true
		post.CanCollide = false
		post.Size = Vector3.new(0.6, 7, 0.6)
		post.Color = color
		post.CFrame = cf * CFrame.new(side, 3.5, 0)
		post.Parent = parent
	end
	local banner = Instance.new("Part")
	banner.Name = "Banda" .. index
	banner.Anchored = true
	banner.CanCollide = false
	banner.Size = Vector3.new(8.6, 1.2, 0.2)
	banner.Color = color
	banner.Material = Enum.Material.Neon
	banner.CFrame = cf * CFrame.new(0, 7, 0)
	banner.Parent = parent
end

-- Pornește câte o cursă pentru fiecare jucător, de la poarta 1
function RaceKit.start(match: any, gates: { Vector3 }, radius: number, corridor: number)
	match.data.runs = {}
	match.data.finishOrder = {}
	for _, owner in match.players do
		match.data.runs[owner] = Course.new(gates, radius, corridor, match.startedAt)
		local character = owner.actor and Actors.characterOf(owner.actor)
		if character then
			character:PivotTo(CFrame.new(gates[1] + Vector3.new(0, 3, 0)))
		end
	end
end

local function respawn(owner: any, run: any)
	local character = owner.actor and Actors.characterOf(owner.actor)
	if character then
		character:PivotTo(CFrame.new(Course.respawnPoint(run) + Vector3.new(0, 3, 0)))
	end
end

-- Un pas: porțile, scurtăturile, căderile (mai jos cu `fallDepth` decât ultima poartă). Întoarce lista celor
-- care au terminat acum.
function RaceKit.tick(match: any, fallDepth: number?): { any }
	local finished = {}
	local now = workspace:GetServerTimeNow()
	for owner, run in match.data.runs do
		local root = Kit.root(owner)
		if not root or run.finishedAt then
			continue
		end
		if fallDepth and root.Position.Y < Course.respawnPoint(run).Y - fallDepth then
			respawn(owner, run)
			continue
		end
		local result = Course.update(run, root.Position, now)
		if result == "cheat" or result == "off" then
			respawn(owner, run)
		elseif result == "finish" then
			table.insert(match.data.finishOrder, owner)
			table.insert(finished, owner)
		end
	end
	return finished
end

return RaceKit
