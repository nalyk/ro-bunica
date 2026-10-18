--!strict
-- Pornirea clientului: controllerele, în ordine.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local Controllers = script.Controllers
local ORDER = {
	"ClientState",
	"Layout",
	"Music",
	"AmbienceController",
	"NotifyController",
	"ShopPanel",
	"CellarPanel",
	"UpgradePanel",
	"NotebookPanel",
	"TradePanel",
	"RevengeController",
	"SiteController",
	"AmbientLifeController",
	"RutieraController",
	"HappeningController",
	"MinigameController",
	"HoraStepController",
	"FishingController",
	"FriendsPanel",
	"StorePanel",
	"DailyPopup",
	"SlipperController",
	"HudController",
	"WorldController",
	"LightingDirector",
	"EffectsController",
	"TutorialController",
	"BunicaController",
	"DanceController",
	"StrideController",
	"GriveiController",
	"GamepadController",
}

for _, name in ORDER do
	local module = Controllers:FindFirstChild(name)
	assert(module and module:IsA("ModuleScript"), "Controller lipsă: " .. name)
	local controller = (require :: any)(module)
	if controller.start then
		task.spawn(controller.start)
	end
end

-- Ascultătorii sunt conectați: cerem serverului starea curentă
Net.get("ClientReady"):FireServer()
