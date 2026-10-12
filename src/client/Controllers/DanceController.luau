--!strict
-- Hora pe client: orice personaj cu atributul „Dancing” (pus de server) dansează local:
-- brațele întinse lateral (ca prinși de mâini), pas lateral și legănat.
-- Mișcarea se aplică prin Joints (Motor6D sau AnimationConstraint), local, fără cost de rețea.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Joints = require(script.Parent.Joints)

local DanceController = {}

local JOINT_NAMES = { "RightShoulder", "LeftShoulder", "RightHip", "LeftHip", "Root", "Waist" }

type Dancer = { character: Model, joints: { [string]: Joints.Joint }, missing: number, phase: number }
local dancers: { [Model]: Dancer } = {}

local localPlayer = Players.LocalPlayer
local danceTrack: AnimationTrack? = nil

-- Personajul propriu (articulații noi, animate de Roblox): animația de dans din scriptul Animate
-- al avatarului (aceeași ca la „/e dance”). Animațiile personajului propriu se replică singure.
local function emote(character: Model, dancing: boolean)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	if dancing and not danceTrack then
		local animate = character:FindFirstChild("Animate")
		local folder = animate and animate:FindFirstChild("dance")
		local animation = folder and folder:FindFirstChildWhichIsA("Animation")
		if animation then
			local track = animator:LoadAnimation(animation)
			track.Looped = true
			track.Priority = Enum.AnimationPriority.Action
			track:Play(0.2)
			danceTrack = track
		end
	elseif not dancing and danceTrack then
		danceTrack:Stop(0.2)
		danceTrack = nil
	end
end

local function usesMotors(character: Model): boolean
	return character:FindFirstChildWhichIsA("Motor6D", true) ~= nil
end

local waiting: { [Model]: RBXScriptConnection } = {}

local function consider(character: Model)
	local dancing = character:GetAttribute("Dancing") == true
	if character == localPlayer.Character and not usesMotors(character) then
		emote(character, dancing)
		return
	end
	if not usesMotors(character) then
		-- Boții: cu StreamingEnabled, articulațiile pot sosi după model; reîncercăm când sosesc.
		-- Alt jucător: dansul lui vine prin replicarea animației de pe clientul lui.
		if not Players:GetPlayerFromCharacter(character) and not waiting[character] then
			waiting[character] = character.DescendantAdded:Connect(function(descendant)
				if descendant:IsA("Motor6D") then
					local connection = waiting[character]
					waiting[character] = nil
					if connection then
						connection:Disconnect()
					end
					consider(character)
				end
			end)
		end
		return
	end
	if dancing then
		if not dancers[character] then
			local joints = {}
			local missing = Joints.collect(character, JOINT_NAMES, joints)
			dancers[character] =
				{ character = character, joints = joints, missing = missing, phase = math.random() * 3 }
		end
	else
		local dancer = dancers[character]
		if dancer then
			for _, joint in dancer.joints do
				joint.reset()
			end
		end
		dancers[character] = nil
	end
end

local function watch(character: Model)
	consider(character)
	character:GetAttributeChangedSignal("Dancing"):Connect(function()
		consider(character)
	end)
end

function DanceController.start()
	local function watchPlayer(player: Player)
		if player.Character then
			watch(player.Character)
		end
		player.CharacterAdded:Connect(watch)
	end
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	-- Boții (de exemplu în teste) sunt modele direct în Workspace
	Workspace.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
			watch(child :: Model)
		end
	end)

	-- Plasă de siguranță: evenimentele pot rata boți sosiți prin streaming; o dată pe secundă căutăm
	-- modelele marcate „Dancing” care nu dansează încă
	task.spawn(function()
		while true do
			task.wait(1)
			for _, child in Workspace:GetChildren() do
				if child:IsA("Model") and child:GetAttribute("Dancing") == true and not dancers[child] then
					consider(child)
				end
			end
		end
	end)

	RunService.PreSimulation:Connect(function()
		local t = os.clock()
		for character, dancer in dancers do
			if not character.Parent then
				dancers[character] = nil
				continue
			end
			if dancer.missing > 0 then
				-- Cu StreamingEnabled, articulațiile pot sosi după model
				dancer.missing = Joints.collect(character, JOINT_NAMES, dancer.joints)
			end
			local step = math.sin(t * 6 + dancer.phase)
			local joints = dancer.joints
			if joints.RightShoulder then
				joints.RightShoulder.set(CFrame.Angles(0, 0, math.rad(80 + step * 6)))
			end
			if joints.LeftShoulder then
				joints.LeftShoulder.set(CFrame.Angles(0, 0, math.rad(-80 - step * 6)))
			end
			if joints.RightHip then
				joints.RightHip.set(CFrame.Angles(0, 0, math.rad(math.max(step, 0) * 25)))
			end
			if joints.LeftHip then
				joints.LeftHip.set(CFrame.Angles(0, 0, math.rad(math.min(step, 0) * 25)))
			end
			if joints.Root then
				joints.Root.set(CFrame.new(0, math.abs(step) * 0.4, 0))
			end
			if joints.Waist then
				joints.Waist.set(CFrame.Angles(0, 0, math.rad(step * 5)))
			end
		end
	end)
end

return DanceController
