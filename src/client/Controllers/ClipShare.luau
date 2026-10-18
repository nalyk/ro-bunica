--!strict
-- Clipul loviturii nopții (CaptureService): cât rulează reluarea, jocul filmează ecranul celui care a
-- aruncat; la final apare „Trimite clipul”, iar clipul pleacă cu un link spre ograda lui (LaunchData).
-- Fără CaptureService (Studio, dispozitive vechi, permisiune refuzată) nu apare nimic.

local CaptureService = game:GetService("CaptureService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Launch = require(Shared.Domain.Launch)
local ClientState = require(script.Parent.ClientState)
local UI = require(script.Parent.UI)

local ClipShare = {}

local me = Players.LocalPlayer
local recording = false
local OFFER_SECONDS = 10

local function offer(capture: Instance)
	local button: GuiObject
	button = UI.button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 300),
		Size = UDim2.fromOffset(300, 64),
		Text = ClientState.t("clip.share"),
		swatch = "ie",
		Parent = UI.screen(),
	}, function()
		button:Destroy()
		local launch = Launch.encode({ kind = "clip", host = me.UserId, referrer = me.UserId })
		pcall(function()
			local content = (Content :: any).fromObject(capture)
			CaptureService:PromptShareCapture(content, launch, function() end, function() end)
		end)
	end)
	task.delay(OFFER_SECONDS, function()
		if button.Parent then
			button:Destroy()
		end
	end)
end

-- Pornește filmarea (doar pentru cel care a aruncat)
function ClipShare.begin(throwerId: number?)
	-- în Studio nu se partajează nimic, iar filmarea încetinește clientul (playtestul pe Vinegar)
	if recording or throwerId ~= me.UserId or RunService:IsStudio() then
		return
	end
	recording = true
	task.spawn(function()
		local ok = pcall(CaptureService.StartVideoCaptureAsync, CaptureService, function(result, capture)
			recording = false
			if result == Enum.VideoCaptureResult.Success and capture then
				offer(capture)
			end
		end, {})
		if not ok then
			recording = false
		end
	end)
end

function ClipShare.finish()
	if recording then
		pcall(CaptureService.StopVideoCapture, CaptureService)
	end
end

return ClipShare
