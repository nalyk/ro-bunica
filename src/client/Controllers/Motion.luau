--!strict
-- Mișcare cu resort pentru interfață: „snappy” (răspuns la apăsare), „bouncy” (apariții cu depășire),
-- „gentle” (tranziții lente). Cu „Reduced motion” activ, totul devine instantaneu (accesibilitate).

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local Motion = {}

export type Preset = { frequency: number, damping: number }

Motion.presets = table.freeze({
	snappy = { frequency = 6, damping = 0.75 } :: Preset,
	bouncy = { frequency = 4, damping = 0.45 } :: Preset,
	gentle = { frequency = 2, damping = 1 } :: Preset,
})

type Spring = { value: number, velocity: number, target: number, preset: Preset, apply: (number) -> () }

local springs: { [any]: Spring } = {}
local running = false

local function reduced(): boolean
	local ok, value = pcall(function()
		return (GuiService :: any).ReducedMotionEnabled
	end)
	return ok and value == true
end

local function step(dt: number)
	dt = math.min(dt, 1 / 20)
	for key, s in springs do
		-- resort amortizat (integrare semi-implicită): stabil la orice fps
		local w = 2 * math.pi * s.preset.frequency
		local accel = -w * w * (s.value - s.target) - 2 * s.preset.damping * w * s.velocity
		s.velocity += accel * dt
		s.value += s.velocity * dt
		s.apply(s.value)
		if math.abs(s.value - s.target) < 1e-3 and math.abs(s.velocity) < 1e-3 then
			s.value = s.target
			s.apply(s.target)
			springs[key] = nil
		end
	end
end

-- Animează numărul identificat prin `key` spre `target`; `apply` primește valoarea curentă la fiecare cadru.
-- `from` (opțional) pornește de la o valoare dată (de exemplu un „pop” de la 0,8).
function Motion.spring(key: any, target: number, apply: (number) -> (), preset: Preset?, from: number?)
	if reduced() then
		springs[key] = nil
		apply(target)
		return
	end
	local s = springs[key]
	if not s then
		s = {
			value = from or target,
			velocity = 0,
			target = target,
			preset = preset or Motion.presets.snappy,
			apply = apply,
		}
		springs[key] = s
	end
	s.target = target
	s.preset = preset or s.preset
	s.apply = apply
	if from then
		s.value = from
	end
	if not running then
		running = true
		RunService.RenderStepped:Connect(step)
	end
end

-- Scala unui element (prin UIScale): apăsare, „pop” la apariție, salt la recompensă
function Motion.scale(gui: GuiObject, target: number, preset: Preset?, from: number?)
	local existing = gui:FindFirstChildOfClass("UIScale")
	local uiScale: UIScale
	if existing then
		uiScale = existing
	else
		uiScale = Instance.new("UIScale")
		uiScale.Parent = gui
	end
	Motion.spring(uiScale, target, function(v)
		uiScale.Scale = v
	end, preset, from)
end

function Motion.pop(gui: GuiObject)
	Motion.scale(gui, 1, Motion.presets.bouncy, 0.82)
end

return Motion
