--!strict
-- Grivei, câinele din ogradă (pus de server, tag „Grivei”): respiră liniștit, iar cât are hoți în ogradă
-- (atributul „Barking”) sare în labe și se răsucește spre ei la fiecare lătrat. Local, fără cost de rețea.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Motion = require(script.Parent.Motion)

local GriveiController = {}

local TAG = "Grivei"
local BARK_PERIOD = 0.42

type Dog = { model: Model, home: CFrame, phase: number }
local dogs: { [Model]: Dog } = {}

local function add(instance: Instance)
	if instance:IsA("Model") and not dogs[instance] then
		dogs[instance] = { model = instance, home = instance:GetPivot(), phase = math.random() * 10 }
	end
end

local function step()
	local t = os.clock()
	local reduced = Motion.reduced()
	for model, dog in dogs do
		if not model.Parent then
			dogs[model] = nil
			continue
		end
		local offset: CFrame
		if model:GetAttribute("Barking") == true and not reduced then
			-- un salt scurt la fiecare lătrat, cu capul spre drum
			local k = ((t + dog.phase) % BARK_PERIOD) / BARK_PERIOD
			local hop = math.sin(math.min(k * 2, 1) * math.pi) * 0.45
			offset = CFrame.new(0, hop, 0)
				* CFrame.Angles(math.rad(-8) * hop / 0.45, math.sin(t * 9) * 0.08, 0)
		else
			-- respirația: pieptul urcă și coboară ușor
			local breathe = math.sin((t + dog.phase) * 2.4) * 0.03
			offset = CFrame.new(0, breathe, 0)
		end
		model:PivotTo(dog.home * offset)
	end
end

function GriveiController.start()
	for _, instance in CollectionService:GetTagged(TAG) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	RunService.RenderStepped:Connect(step)
end

return GriveiController
