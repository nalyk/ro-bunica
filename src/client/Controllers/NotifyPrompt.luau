--!strict
-- Cererea de acord pentru notificări (ExperienceNotificationService): o singură dată pe sesiune, într-un
-- moment liniștit — dimineața de după prima lovitură reușită cu papucul, niciodată în timpul unui furt
-- (fereastra Roblox acoperă jocul). Textul ferestrei e al Roblox; Roblox nu o arată sub 13 ani, celor care
-- au acceptat deja și celor care au văzut-o în ultimele 30 de zile. În Studio nu apare.

local ExperienceNotificationService = game:GetService("ExperienceNotificationService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameState = require(Shared.GameState)

local NotifyPrompt = {}

local MIN_SESSION = 180 -- nu în primele minute (tutorialul, primul hoț)
local DAY_DELAY = 8 -- după răsărit și reluarea loviturii nopții
local started = os.clock()
local pending = false
local asked = false

local function ask()
	asked = true
	local ok, can = pcall(ExperienceNotificationService.CanPromptOptInAsync, ExperienceNotificationService)
	if ok and can then
		pcall(ExperienceNotificationService.PromptOptIn, ExperienceNotificationService)
	end
end

-- O lovitură reușită: cererea vine la următoarea dimineață
function NotifyPrompt.moment()
	if asked or pending or RunService:IsStudio() or os.clock() - started < MIN_SESSION then
		return
	end
	pending = true
	task.spawn(function()
		while GameState.get(GameState.Attributes.Phase) ~= "Day" do
			task.wait(1)
		end
		task.wait(DAY_DELAY)
		ask()
	end)
end

return NotifyPrompt
