--!strict
-- Primul minut pe client: banner când vine hoțul, indiciu mare + mână animată deasupra lui,
-- apoi mesajul de final. Fără text de citit obligatoriu: mâna arată unde se atinge.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Sounds = require(Shared.Config.Sounds)
local ClientState = require(script.Parent.ClientState)
local UI = require(script.Parent.UI)
local Sfx = require(script.Parent.Sfx)

local TutorialController = {}

local hint: Frame
local hintLabel: TextLabel
local pointer: BillboardGui? = nil
local pulse: RBXScriptConnection? = nil

local function showHint(text: string, color: Color3)
	hintLabel.Text = text
	hint.BackgroundColor3 = color
	hint.Visible = true
	hint.Size = UDim2.fromOffset(0, 70)
	TweenService
		:Create(hint, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(560, 70) })
		:Play()
end

local function hideHint()
	hint.Visible = false
	if pulse then
		pulse:Disconnect()
		pulse = nil
	end
	if pointer then
		pointer:Destroy()
		pointer = nil
	end
end

-- O mână mare care sare deasupra hoțului
local function pointAt(name: string)
	local model = Workspace:FindFirstChild(name)
	local head = model and model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(90, 90)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = head
	local hand = UI.label({ Size = UDim2.fromScale(1, 1), Text = "👇", Parent = billboard })
	billboard.Parent = head
	pointer = billboard
	pulse = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		billboard.StudsOffset = Vector3.new(0, 6 + math.abs(math.sin(t * 6)) * 1.5, 0)
		hand.TextTransparency = 0
	end)
end

function TutorialController.start()
	hint = UI.frame({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.fromOffset(560, 70),
		Visible = false,
		Parent = UI.screen(),
	})
	hintLabel = UI.label({
		Size = UDim2.new(1, -20, 1, -10),
		Position = UDim2.fromOffset(10, 5),
		Text = "",
		TextColor3 = UI.colors.linen,
		Parent = hint,
	})

	Net.get("Tutorial").OnClientEvent:Connect(function(stage: string, data: { any }?)
		local args = data or {}
		if stage == "incoming" then
			Sfx.play(Sounds.alarm, nil, 0.6)
			showHint("🐓 " .. ClientState.t("tutorial.incoming"), UI.colors.night)
		elseif stage == "throw" then
			showHint(ClientState.t("tutorial.throw"), UI.colors.stitch)
			pointAt(tostring(args[1]))
		elseif stage == "done" then
			hideHint()
			local byPlayer = args[1] == true
			showHint(
				ClientState.t(if byPlayer then "tutorial.doneByPlayer" else "tutorial.doneByBunica"),
				UI.colors.green
			)
			task.delay(4, hideHint)
		end
	end)
end

return TutorialController
