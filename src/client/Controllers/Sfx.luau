--!strict
-- Redare de efecte sonore: 2D (interfață) sau 3D, la o poziție din lume.

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Sfx = {}

function Sfx.play(soundId: string, position: Vector3?, volume: number?, pitch: number?)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.8
	sound.PlaybackSpeed = pitch or 1
	if position then
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.CFrame = CFrame.new(position)
		holder.Parent = Workspace
		sound.RollOffMaxDistance = 140
		sound.Parent = holder
		Debris:AddItem(holder, 8)
	else
		sound.Parent = SoundService
		Debris:AddItem(sound, 8)
	end
	sound:Play()
end

return Sfx
