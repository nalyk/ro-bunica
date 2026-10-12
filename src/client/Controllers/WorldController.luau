--!strict
-- Randare locală: etichete și „respirația” creaturilor, plantele din straturi, prompt-urile,
-- lumina de zi/noapte și particulele de vreme. Nimic de aici nu afectează jocul pe server.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local GameState = require(Shared.GameState)
local CreatureBuilder = require(Shared.Visual.CreatureBuilder)
local Economy = require(Shared.Domain.Economy)
local ClientState = require(script.Parent.ClientState)

local WorldController = {}

local localPlayer = Players.LocalPlayer

-- Creaturi ---------------------------------------------------------------

type Animated = { model: Model, base: CFrame, phase: number }
local animated: { [Model]: Animated } = {}

local function labelCreature(model: Model)
	local id = model:GetAttribute("CreatureId") :: string?
	local creature = id and Creatures.byId[id]
	local primary = model.PrimaryPart
	if not creature or not primary or model:GetAttribute("Showcase") then
		return
	end
	local mutation = model:GetAttribute("Mutation") :: string?
	local size = model:GetAttribute("Size") :: string?
	local rarity = Rarities.byId[creature.rarity]

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CreatureLabel"
	billboard.Size = UDim2.fromOffset(170, 58)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, model:GetExtentsSize().Y / 2 + 1.8, 0)
	billboard.MaxDistance = 30
	billboard.Adornee = primary
	billboard.Parent = model
	local nameText = ClientState.t("creature." .. creature.id)
	if mutation and mutation ~= "" then
		nameText = ClientState.t("mutation." .. mutation) .. " " .. nameText
	end
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 0.5)
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextStrokeTransparency = 0.2
	name.TextColor3 = if mutation
			and mutation ~= ""
			and Mutations.byId[mutation]
		then Mutations.byId[mutation].color
		else Color3.new(1, 1, 1)
	name.Text = nameText
	name.Parent = billboard
	local info = name:Clone()
	info.Position = UDim2.fromScale(0, 0.5)
	info.TextColor3 = rarity.color
	info.Text = ClientState.t("rarity." .. creature.rarity)
		.. " · "
		.. ClientState.t("ui.perSecond", {
			Economy.formatShort(
				Economy.incomePerSecond({ id = creature.id, size = size or "Normal", mutation = mutation })
			),
		})
	info.Parent = billboard
end

local function onCreature(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	labelCreature(instance)
	local primary = instance.PrimaryPart
	if primary and primary.Anchored then
		animated[instance] =
			{ model = instance, base = instance:GetPivot(), phase = math.random() * math.pi * 2 }
	end
end

local function animateCreatures(t: number)
	for model, entry in animated do
		local primary = model.PrimaryPart
		if not model.Parent or not primary or not primary.Anchored then
			animated[model] = nil
			continue
		end
		local bob = math.sin(t * 2.4 + entry.phase)
		model:PivotTo(entry.base * CFrame.new(0, math.abs(bob) * 0.5, 0) * CFrame.Angles(0, 0, bob * 0.06))
	end
end

-- Plante -----------------------------------------------------------------

local plantModels: { [BasePart]: Model } = {}

local function renderPlant(bed: BasePart)
	local existing = plantModels[bed]
	if existing then
		existing:Destroy()
		plantModels[bed] = nil
	end
	local seedId = bed:GetAttribute("SeedId") :: string?
	if not seedId or not Creatures.byId[seedId] then
		return
	end
	local progress = (bed:GetAttribute("Progress") :: number?) or 0
	local mutation = bed:GetAttribute("Mutation") :: string?
	local model = Instance.new("Model")
	model.Name = "Plant"
	local scale = 0.3 + 0.7 * progress
	local stem = Instance.new("Part")
	stem.Anchored = true
	stem.CanCollide = false
	stem.CanQuery = false
	stem.Size = Vector3.new(0.4, 2.4 * scale, 0.4)
	stem.Color = Color3.fromRGB(70, 150, 60)
	stem.CFrame = bed.CFrame * CFrame.new(0, bed.Size.Y / 2 + stem.Size.Y / 2, 0)
	stem.Parent = model
	model.PrimaryPart = stem
	if progress >= 0.5 then
		-- Spre final, creatura se vede crescând ca un „fruct” pe tulpină
		local fruit =
			CreatureBuilder.build({ id = seedId, size = "Normal", mutation = mutation }, stem.CFrame)
		fruit:ScaleTo(math.max(0.25, progress * 0.6))
		CreatureBuilder.placeOn(fruit, stem.CFrame * CFrame.new(0, stem.Size.Y / 2, 0))
		CollectionService:RemoveTag(fruit, CreatureBuilder.TAG)
		fruit.Parent = model
	else
		local leaf = Instance.new("Part")
		leaf.Anchored = true
		leaf.CanCollide = false
		leaf.CanQuery = false
		leaf.Size = Vector3.new(1.6 * scale + 0.4, 0.2, 0.8 * scale + 0.3)
		leaf.Color = Color3.fromRGB(90, 180, 70)
		leaf.CFrame = stem.CFrame * CFrame.new(0, stem.Size.Y / 2, 0)
		leaf.Parent = model
	end
	if mutation and Mutations.byId[mutation] then
		local light = Instance.new("PointLight")
		light.Color = Mutations.byId[mutation].color
		light.Range = 8
		light.Parent = stem
	end
	model.Parent = Workspace
	plantModels[bed] = model
end

-- Prompt local de plantare pe straturile proprii, libere și deblocate
local function setupBedPrompt(bed: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PlantPrompt"
	prompt.ActionText = ClientState.t("ui.plant")
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = bed
	prompt.Triggered:Connect(function()
		local seed = ClientState.selectedSeed
		if not seed then
			-- Fără sămânță aleasă: alege automat prima disponibilă
			for id in ClientState.state.seeds or {} do
				seed = id
				break
			end
		end
		if seed then
			Net.get("Plant"):FireServer(bed:GetAttribute("BedKey"), seed)
		end
	end)
end

local function refreshBedPrompts()
	local plot = ClientState.myPlot()
	local state = ClientState.state
	local hasSeeds = next(state.seeds or {}) ~= nil
	for _, bed in CollectionService:GetTagged("BunicaBed") do
		local prompt = bed:FindFirstChild("PlantPrompt") :: ProximityPrompt?
		if prompt then
			local key = bed:GetAttribute("BedKey") :: string
			local mine = plot ~= nil and bed:IsDescendantOf(plot)
			local unlocked = (tonumber(key) or 0) <= (state.bedCount or 0)
			prompt.Enabled = mine and unlocked and hasSeeds and bed:GetAttribute("SeedId") == nil
		end
	end
end

local function onBed(bed: BasePart)
	CollectionService:AddTag(bed, "BunicaBed")
	setupBedPrompt(bed)
	renderPlant(bed)
	local lastProgressStep = -1
	bed.AttributeChanged:Connect(function(attribute)
		if attribute == "Progress" then
			-- Redesenăm planta doar la pași vizibili de creștere
			local step = math.floor(((bed:GetAttribute("Progress") :: number?) or 0) * 10)
			if step == lastProgressStep then
				return
			end
			lastProgressStep = step
		end
		renderPlant(bed)
		refreshBedPrompts()
	end)
end

-- Prompt-uri de furt ----------------------------------------------------------

local function setupStealPrompt(prompt: ProximityPrompt)
	if prompt:GetAttribute("Kind") ~= "Steal" then
		return
	end
	prompt.ActionText = ClientState.t("ui.steal")
	-- Nu-ți arăta prompt-ul de furt pe propriile creaturi
	if prompt:GetAttribute("OwnerUserId") == localPlayer.UserId then
		prompt.MaxActivationDistance = 0
	end
end

-- Lumină și vreme ---------------------------------------------------------------

local LIGHTING = {
	Day = {
		ClockTime = 16.5,
		Brightness = 2.2,
		Ambient = Color3.fromRGB(120, 105, 90),
		OutdoorAmbient = Color3.fromRGB(150, 135, 115),
	},
	Night = {
		ClockTime = 0.5,
		Brightness = 1,
		Ambient = Color3.fromRGB(60, 60, 110),
		OutdoorAmbient = Color3.fromRGB(70, 70, 130),
	},
}

local function applyPhase(phase: string?)
	local goal = LIGHTING[phase or "Day"] or LIGHTING.Day
	TweenService:Create(Lighting, TweenInfo.new(3, Enum.EasingStyle.Sine), goal):Play()
end

local weatherPart: Part? = nil

local WEATHER_PARTICLES: { [string]: { color: Color3, rate: number, speed: number, size: number } } = {
	Rain = { color = Color3.fromRGB(150, 180, 255), rate = 400, speed = 60, size = 0.15 },
	Hail = { color = Color3.fromRGB(235, 245, 255), rate = 200, speed = 70, size = 0.4 },
	FrostNight = { color = Color3.fromRGB(255, 255, 255), rate = 150, speed = 8, size = 0.3 },
	GoldHarvest = { color = Color3.fromRGB(255, 210, 60), rate = 120, speed = 6, size = 0.35 },
	Rainbow = { color = Color3.fromRGB(255, 120, 220), rate = 160, speed = 6, size = 0.35 },
}

local function applyWeather(weather: string?)
	if weatherPart then
		weatherPart:Destroy()
		weatherPart = nil
	end
	local config = weather and WEATHER_PARTICLES[weather]
	if not config then
		return
	end
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(120, 1, 120)
	part.Parent = Workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(config.color)
	emitter.Rate = config.rate
	emitter.Speed = NumberRange.new(config.speed)
	emitter.Size = NumberSequence.new(config.size)
	emitter.Lifetime = NumberRange.new(1.5, 2.5)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.LightEmission = if weather == "GoldHarvest" or weather == "Rainbow" then 0.8 else 0.2
	emitter.Parent = part
	weatherPart = part
end

function WorldController.start()
	for _, model in CollectionService:GetTagged(CreatureBuilder.TAG) do
		onCreature(model)
	end
	CollectionService:GetInstanceAddedSignal(CreatureBuilder.TAG):Connect(onCreature)

	local village = Workspace:WaitForChild("Village")
	for _, descendant in village:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("BedKey") then
			onBed(descendant)
		end
	end

	village.DescendantAdded:Connect(function(descendant: Instance)
		if
			descendant:IsA("BasePart")
			and descendant:GetAttribute("BedKey")
			and not plantModels[descendant]
		then
			if not descendant:FindFirstChild("PlantPrompt") then
				onBed(descendant)
			end
		end
	end)

	ProximityPromptService.PromptShown:Connect(function(prompt)
		setupStealPrompt(prompt)
	end)
	village.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then
			setupStealPrompt(descendant)
		end
	end)

	ClientState.onChanged(refreshBedPrompts)

	applyPhase(GameState.get(GameState.Attributes.Phase))
	GameState.changed(GameState.Attributes.Phase, applyPhase)
	applyWeather(GameState.get(GameState.Attributes.Weather))
	GameState.changed(GameState.Attributes.Weather, applyWeather)

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		animateCreatures(t)
		local camera = Workspace.CurrentCamera
		if weatherPart and camera then
			weatherPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 40, 0))
		end
	end)
end

return WorldController
