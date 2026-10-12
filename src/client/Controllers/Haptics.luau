--!strict
-- Vibrație scurtă pe telefon (HapticEffect) și pe gamepad (HapticService). Tăcut unde nu există.

local HapticService = game:GetService("HapticService")
local Workspace = game:GetService("Workspace")

local Haptics = {}

function Haptics.impact(strong: boolean)
	pcall(function()
		local effect = Instance.new("HapticEffect")
		effect.Type = if strong
			then Enum.HapticEffectType.GameplayExplosion
			else Enum.HapticEffectType.GameplayCollision
		effect.Parent = Workspace
		effect:Play()
		task.delay(1, function()
			effect:Destroy()
		end)
	end)
	pcall(function()
		local gamepad = Enum.UserInputType.Gamepad1
		if HapticService:IsVibrationSupported(gamepad) then
			HapticService:SetMotor(gamepad, Enum.VibrationMotor.Large, if strong then 1 else 0.6)
			task.delay(0.15, function()
				HapticService:SetMotor(gamepad, Enum.VibrationMotor.Large, 0)
			end)
		end
	end)
end

return Haptics
