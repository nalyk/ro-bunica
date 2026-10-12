--!strict
-- Rig-uri create pe server (Bunica, boți): Roblox le construiește acum cu AnimationConstraint
-- („Avatar Joint Upgrade”), rezolvate de fizică pe server, deci pozele locale de pe client nu au efect.
-- Le convertim în Motor6D clasice, pe care clientul le poate anima local (văzut în playtest).

local Rig = {}

function Rig.useMotors(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("AnimationConstraint") then
			local a0, a1 = descendant.Attachment0, descendant.Attachment1
			local part0 = a0 and a0.Parent
			local part1 = a1 and a1.Parent
			if a0 and a1 and part0 and part0:IsA("BasePart") and part1 and part1:IsA("BasePart") then
				local motor = Instance.new("Motor6D")
				motor.Name = descendant.Name
				motor.Part0 = part0
				motor.Part1 = part1
				motor.C0 = a0.CFrame
				motor.C1 = a1.CFrame
				motor.Parent = part1
			end
			descendant:Destroy()
		end
	end
	-- Constrângerile de ragdoll care însoțesc articulațiile noi nu mai au sens fără ele
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BallSocketConstraint") then
			descendant:Destroy()
		end
	end
end

return Rig
