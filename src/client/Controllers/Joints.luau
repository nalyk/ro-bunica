--!strict
-- Articulații pentru animații procedurale locale, indiferent de sistemul avatarului:
-- Motor6D (clasic) sau AnimationConstraint („Avatar Joint Upgrade”, folosit acum de Roblox).
-- Poza se aplică peste cadrul de bază al articulației (C0, respectiv Attachment0), pe care Animator-ul nu-l rescrie.

export type Joint = {
	name: string,
	set: (CFrame) -> (),
	reset: () -> (),
}

local Joints = {}

local function wrap(instance: Instance): Joint?
	if instance:IsA("Motor6D") then
		local motor = instance
		local base = motor.C0
		return {
			name = motor.Name,
			set = function(pose: CFrame)
				motor.C0 = base * pose
			end,
			reset = function()
				motor.C0 = base
			end,
		}
	elseif instance:IsA("AnimationConstraint") then
		local attachment = instance.Attachment0
		if not attachment then
			return nil
		end
		local base = attachment.CFrame
		return {
			name = instance.Name,
			set = function(pose: CFrame)
				attachment.CFrame = base * pose
			end,
			reset = function()
				attachment.CFrame = base
			end,
		}
	end
	return nil
end

-- Completează `found` cu articulațiile din `names` care există acum în model. Întoarce câte lipsesc.
function Joints.collect(model: Model, names: { string }, found: { [string]: Joint }): number
	for _, descendant in model:GetDescendants() do
		local name = descendant.Name
		if not found[name] and table.find(names, name) then
			local joint = wrap(descendant)
			if joint then
				found[name] = joint
			end
		end
	end
	local missing = 0
	for _, name in names do
		if not found[name] then
			missing += 1
		end
	end
	return missing
end

return Joints
