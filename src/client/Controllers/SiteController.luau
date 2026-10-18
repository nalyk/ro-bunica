--!strict
-- Locurile satului pe client: tăblițele (TextKey) traduse în limba jucătorului și palele morii care se rotesc.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ClientState = require(script.Parent.ClientState)

local SiteController = {}

type Spinner = { model: Model, base: CFrame, speed: number }
local spinners: { Spinner } = {}

local function translate(label: Instance)
	local key = label:GetAttribute("TextKey")
	if typeof(key) == "string" and label:IsA("TextLabel") then
		label.Text = ClientState.t(key)
	end
end

local function watch(sites: Instance)
	for _, descendant in sites:GetDescendants() do
		translate(descendant)
		if
			descendant:IsA("Model")
			and typeof(descendant:GetAttribute("Spin")) == "number"
			and descendant.PrimaryPart
		then
			table.insert(spinners, {
				model = descendant,
				base = descendant:GetPivot(),
				speed = descendant:GetAttribute("Spin") :: number,
			})
		end
	end
	sites.DescendantAdded:Connect(translate) -- cu streaming, tăblițele pot apărea mai târziu
end

-- Avizierul din centru: recordurile serverului (atributele „Record_<joc>” = "nume|scor"), traduse
local function watchBoard(sites: Instance)
	local centre = sites:WaitForChild("centru", 30)
	local part = centre and centre:FindFirstChild("Avizier", true) :: BasePart?
	if not part then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(250, 240, 210)
	label.Parent = gui
	local function refresh()
		local lines = { "🏆 " .. ClientState.t("ui.records") }
		for name, value in part:GetAttributes() do
			local id = string.match(name, "^Record_(.+)$")
			if id and typeof(value) == "string" then
				local who, score = string.match(value, "^(.*)|(%d+)$")
				table.insert(
					lines,
					string.format("%s: %s %s", ClientState.t("minigame." .. id), who or "?", score or "?")
				)
			end
		end
		label.Text = table.concat(lines, "\n")
	end
	part.AttributeChanged:Connect(refresh)
	refresh()
end

function SiteController.start()
	task.spawn(function()
		local village = Workspace:WaitForChild("Village")
		local sites = village:WaitForChild("Sites")
		watch(sites)
		watchBoard(sites)
	end)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, spinner in spinners do
			if spinner.model.Parent then
				-- axa palelor e X-ul local al axului (cilindrul e rotit): rotim în jurul LookVector-ului bazei
				spinner.model:PivotTo(spinner.base * CFrame.Angles(0, 0, t * spinner.speed * math.pi * 2))
			end
		end
	end)
end

return SiteController
