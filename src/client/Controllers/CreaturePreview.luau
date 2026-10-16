--!strict
-- Creatura în miniatură, pentru panouri (taraba, beciul): modelul sculptat (cu mărimea și mutația lui) într-un
-- ViewportFrame, din trei sferturi, încadrat după mărimea lui, pe un disc în culoarea rarității.
-- Modelele sunt grele: panourile le construiesc doar când se schimbă lista, nu la fiecare actualizare de stare.

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CreatureBuilder = require(Shared.Visual.CreatureBuilder)
local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)

local CreaturePreview = {}

local FOV = 30

export type Record = { id: string, size: string, mutation: string? }

function CreaturePreview.make(record: Record, rarityColor: Color3, side: number, parent: GuiObject): Frame
	local backdrop = UI.frame({
		Size = UDim2.fromOffset(side, side),
		Position = UDim2.fromOffset(4, 4),
		BackgroundColor3 = rarityColor:Lerp(Theme.paper, 0.55),
		Parent = parent,
	})
	local corner = backdrop:FindFirstChildWhichIsA("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = backdrop
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(228, 222, 214)
	viewport.LightColor = Color3.fromRGB(255, 250, 240)
	viewport.LightDirection = Vector3.new(-0.5, -1, 0.7)
	viewport.Parent = backdrop
	local ok, model = pcall(
		CreatureBuilder.build,
		{ id = record.id, size = record.size, mutation = record.mutation },
		CFrame.new()
	)
	if not ok then
		return backdrop
	end
	-- doar imagine: fără etichete, respirație sau alte efecte ale creaturilor din lume
	CollectionService:RemoveTag(model, CreatureBuilder.TAG)
	model.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	local box, size = model:GetBoundingBox()
	local distance = size.Magnitude / 2 / math.tan(math.rad(FOV / 2)) * 0.82
	-- modelele privesc spre -Z: camera stă în fața lor, puțin din dreapta și de sus
	local direction = Vector3.new(0.45, 0.25, -1).Unit
	camera.CFrame = CFrame.lookAt(box.Position + direction * distance, box.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return backdrop
end

return CreaturePreview
