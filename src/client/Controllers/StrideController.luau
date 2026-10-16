--!strict
-- Mersul procedural al personajelor sculptate (atributul „Walks”, pus de server pe boți precum Hoțomanul):
-- picioarele și brațele se leagănă în opoziție, corpul saltă și se răsucește ușor, pe măsura vitezei.
-- Pe loc, respirație lentă. Local, prin Joints, fără cost de rețea (ca DanceController).

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Joints = require(script.Parent.Joints)
local Motion = require(script.Parent.Motion)

local StrideController = {}

local JOINT_NAMES = { "Root", "LeftHip", "RightHip", "LeftShoulder", "RightShoulder", "Neck" }
local STRIDE_STUDS = 4.2 -- un pas complet (stânga + dreapta) la fiecare 4,2 studs parcurși
local FULL_SPEED = 10 -- viteza la care leagănul e complet

type Walker = {
	model: Model,
	root: BasePart,
	joints: { [string]: Joints.Joint },
	missing: number,
	phase: number,
	amount: number, -- 0 pe loc, 1 la mers complet (netezit)
}
local walkers: { [Model]: Walker } = {}

local function track(model: Model)
	if walkers[model] or model:GetAttribute("Walks") ~= true then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local joints = {}
	local missing = Joints.collect(model, JOINT_NAMES, joints)
	walkers[model] = { model = model, root = root, joints = joints, missing = missing, phase = 0, amount = 0 }
end

local function step(dt: number)
	local now = os.clock()
	for model, w in walkers do
		if not model.Parent then
			walkers[model] = nil
			continue
		end
		if w.missing > 0 then
			w.missing = Joints.collect(model, JOINT_NAMES, w.joints)
		end
		local velocity = w.root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local target = math.clamp(speed / FULL_SPEED, 0, 1)
		w.amount += (target - w.amount) * math.min(1, dt * 8)
		w.phase += dt * speed / STRIDE_STUDS * 2 * math.pi
		local a = if Motion.reduced() then w.amount * 0.4 else w.amount
		local s = math.sin(w.phase)
		local j = w.joints
		local breathe = math.sin(now * 2.2) * 0.02 * (1 - w.amount)
		if j.Root then
			-- salt de două ori pe pas, răsucire ușoară, aplecat înainte ca un hoț care se furișează
			j.Root.set(
				CFrame.new(0, math.abs(math.cos(w.phase)) * 0.22 * a + breathe, 0)
					* CFrame.Angles(math.rad(-6) * a, s * 0.12 * a, 0)
			)
		end
		if j.LeftHip then
			j.LeftHip.set(CFrame.Angles(s * 0.7 * a, 0, 0))
		end
		if j.RightHip then
			j.RightHip.set(CFrame.Angles(-s * 0.7 * a, 0, 0))
		end
		if j.LeftShoulder then
			j.LeftShoulder.set(CFrame.Angles(-s * 0.55 * a, 0, 0))
		end
		if j.RightShoulder then
			j.RightShoulder.set(CFrame.Angles(s * 0.55 * a, 0, 0))
		end
		if j.Neck then
			j.Neck.set(CFrame.Angles(math.rad(4) * a, -s * 0.08 * a, 0))
		end
	end
end

function StrideController.start()
	for _, child in Workspace:GetChildren() do
		if child:IsA("Model") then
			track(child)
		end
	end
	Workspace.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			-- piesele și atributele pot sosi după model
			task.delay(0.5, track, child)
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return StrideController
