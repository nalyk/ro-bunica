--!strict
-- Cum arată o mutație pe o creatură. Modelele texturate (SurfaceAppearance) primesc o nuanță și strălucire
-- direct pe textură, plus particule; formele procedurale (fără textură) primesc un Highlight colorat.
-- Curcubeul e animat pe client (MutationVisuals.animate), restul e static și se replică normal.

local MutationVisuals = {}

type Look = {
	tint: Color3,
	glow: number, -- EmissiveStrength pe textură
	sparkle: Color3?,
	rate: number,
	drip: boolean?,
	light: number,
}

local LOOKS: { [string]: Look } = {
	Wet = {
		tint = Color3.fromRGB(205, 225, 255),
		glow = 0,
		sparkle = Color3.fromRGB(120, 180, 255),
		rate = 6,
		drip = true,
		light = 0,
	},
	Hail = {
		tint = Color3.fromRGB(235, 242, 255),
		glow = 0,
		sparkle = Color3.fromRGB(255, 255, 255),
		rate = 8,
		light = 0,
	},
	Frozen = {
		tint = Color3.fromRGB(170, 215, 255),
		glow = 0.15,
		sparkle = Color3.fromRGB(150, 230, 255),
		rate = 10,
		light = 1,
	},
	Golden = {
		tint = Color3.fromRGB(255, 205, 90),
		glow = 0.25,
		sparkle = Color3.fromRGB(255, 215, 80),
		rate = 14,
		light = 1.6,
	},
	Papucita = {
		tint = Color3.fromRGB(255, 205, 205),
		glow = 0.1,
		sparkle = Color3.fromRGB(230, 40, 50),
		rate = 12,
		light = 1.2,
	},
	Rainbow = {
		tint = Color3.fromRGB(255, 255, 255),
		glow = 0.3,
		sparkle = Color3.fromRGB(255, 120, 220),
		rate = 16,
		light = 1.4,
	},
}

local function textured(model: Model): { SurfaceAppearance }
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("SurfaceAppearance") then
			table.insert(list, d)
		end
	end
	return list
end

local function sparkles(primary: BasePart, look: Look)
	if not look.sparkle then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "MutationSparkle"
	emitter.Color = ColorSequence.new(look.sparkle :: Color3)
	emitter.LightEmission = 0.8
	emitter.Rate = look.rate
	emitter.Lifetime = NumberRange.new(0.8, 1.6)
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.3, 0.25),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new(0.1, 1)
	if look.drip then
		emitter.Acceleration = Vector3.new(0, -12, 0)
		emitter.Speed = NumberRange.new(0)
	end
	emitter.Parent = primary
end

-- Aplică mutația pe model (server sau client); `mutationId` nil = nimic.
function MutationVisuals.apply(model: Model, mutationId: string?, fallbackColor: Color3?)
	if not mutationId or mutationId == "" then
		return
	end
	local look = LOOKS[mutationId]
	local primary = model.PrimaryPart
	local surfaces = textured(model)
	if look and #surfaces > 0 then
		for _, surface in surfaces do
			surface.Color = look.tint
			surface.EmissiveTint = look.sparkle or look.tint
			surface.EmissiveStrength = look.glow
		end
	elseif fallbackColor then
		local highlight = Instance.new("Highlight")
		highlight.FillColor = fallbackColor
		highlight.FillTransparency = 0.55
		highlight.OutlineColor = fallbackColor
		highlight.OutlineTransparency = 0.2
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = model
	end
	if primary and look then
		sparkles(primary, look)
		if look.light > 0 then
			local light = Instance.new("PointLight")
			light.Name = "MutationLight"
			light.Color = look.sparkle or look.tint
			light.Range = 9
			light.Brightness = look.light
			light.Parent = primary
		end
	end
end

-- Curcubeul curge prin spectru (local, pe client). Întoarce funcția de oprire.
function MutationVisuals.animate(model: Model, clock: () -> number): (() -> ())?
	if model:GetAttribute("Mutation") ~= "Rainbow" then
		return nil
	end
	local surfaces = textured(model)
	if #surfaces == 0 then
		return nil
	end
	local running = true
	task.spawn(function()
		local offset = math.random()
		while running and model.Parent do
			local hue = (clock() * 0.25 + offset) % 1
			local color = Color3.fromHSV(hue, 0.55, 1)
			for _, surface in surfaces do
				surface.Color = color
				surface.EmissiveTint = color
			end
			task.wait(0.05)
		end
	end)
	return function()
		running = false
	end
end

return MutationVisuals
