--!strict
-- Hora pe ritm, pe client: cât dansezi, apare butonul „Pas!” care pulsează pe bătaie (o bătaie la 0,5 s, după
-- ceasul serverului). Patru pași buni la rând pentru toți din cerc = „cercul perfect” (HoraService).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Rhythm = require(Shared.Domain.Rhythm)
local ClientState = require(script.Parent.ClientState)
local NotifyController = require(script.Parent.NotifyController)
local UI = require(script.Parent.UI)

local HoraStepController = {}

local BEAT = 0.5
local button: TextButton

function HoraStepController.start()
	button = UI.button({
		Name = "HoraStep",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -90),
		Size = UDim2.fromOffset(200, 64),
		Text = "💃 " .. ClientState.t("hora.step"),
		swatch = "plum",
		Visible = false,
		Parent = UI.screen(),
	}, function()
		local pressed = Workspace:GetServerTimeNow()
		Net.get("Hora"):FireServer("step", pressed)
		local beat = math.floor(pressed / BEAT + 0.5) * BEAT
		NotifyController.toast(Rhythm.judge(beat, pressed), "quiet")
	end)
	RunService.RenderStepped:Connect(function()
		local character = Players.LocalPlayer.Character
		local dancing = character ~= nil and character:GetAttribute("Dancing") == true
		if button.Visible ~= dancing then
			button.Visible = dancing
		end
		if dancing then
			local t = Workspace:GetServerTimeNow()
			local phase = math.abs(t / BEAT - math.floor(t / BEAT + 0.5)) * BEAT
			local pulse = math.clamp(1 - phase / 0.2, 0, 1)
			button.Size = UDim2.fromOffset(200 + pulse * 22, 64 + pulse * 8)
		end
	end)
end

return HoraStepController
