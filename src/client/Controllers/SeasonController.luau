--!strict
-- Sărbătorile pe client (GameState.Holidays): o capsulă cu sărbătoarea zilei la intrare și când se schimbă,
-- butoanele de sezon (coronița de Drăgaică acasă; colinda și masca de Malanca iarna), gheața pe iaz iarna și
-- masca peste capul celui deghizat.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local GameState = require(Shared.GameState)
local VillageLayout = require(Shared.Domain.VillageLayout)
local ClientState = require(script.Parent.ClientState)
local UI = require(script.Parent.UI)
local NotifyController = require(script.Parent.NotifyController)

local SeasonController = {}

local layout = VillageLayout.build()
local active: { [string]: boolean } = {}
local buttons: { [string]: TextButton } = {}
local row: Frame
local ice: BasePart? = nil

local function holidays(): { string }
	local value = GameState.get(GameState.Attributes.Holidays)
	local list = {}
	if typeof(value) == "string" then
		for id in string.gmatch(value, "[^,]+") do
			table.insert(list, id)
		end
	end
	return list
end

local function setIce(on: boolean)
	if on and not ice then
		local pond = layout.sites.iaz.Position
		local part = Instance.new("Part")
		part.Name = "GheataIazului"
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(0.3, 36, 36)
		part.CFrame = CFrame.new(pond.X, pond.Y + 0.15, pond.Z) * CFrame.Angles(0, 0, math.rad(90))
		part.Material = Enum.Material.Ice
		part.Color = Color3.fromRGB(200, 225, 240)
		part.Transparency = 0.25
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.Parent = Workspace
		ice = part
	elseif not on and ice then
		ice:Destroy()
		ice = nil
	end
end

local function refresh()
	local list = holidays()
	local was = active
	active = {}
	for _, id in list do
		active[id] = true
		if not was[id] then
			NotifyController.notice("holiday." .. id, ClientState.t("holiday." .. id), "reward")
		end
	end
	local season = GameState.get(GameState.Attributes.Season)
	setIce(season == "Iarna" or active.Iarna == true) -- iarna din calendar sau sărbătoarea de iarnă (15 dec – 14 ian)
end

local function homeNear(root: BasePart): boolean
	local plot = ClientState.myPlot()
	local pivot = plot and plot:GetPivot()
	return pivot ~= nil and (root.Position - pivot.Position).Magnitude <= 45
end

-- Pentru playtest
function SeasonController.debugState(): { [string]: any }
	local visible = {}
	for id, button in buttons do
		visible[id] = button.Visible
	end
	return { holidays = table.concat(holidays(), ","), buttons = visible, ice = ice ~= nil }
end

function SeasonController.start()
	row = Instance.new("Frame")
	row.Name = "SeasonButtons"
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.Position = UDim2.new(0.5, 0, 1, -160)
	row.Size = UDim2.fromOffset(440, 52)
	row.BackgroundTransparency = 1
	row.Parent = UI.screen()
	UI.list(row, Enum.FillDirection.Horizontal, 8).HorizontalAlignment = Enum.HorizontalAlignment.Center
	for _, spec in
		{
			{ id = "crown", text = "👑 " .. ClientState.t("season.crown"), swatch = "wheat" },
			{ id = "colinda", text = "🎶 " .. ClientState.t("season.colinda"), swatch = "sky" },
			{ id = "mask", text = "🎭 " .. ClientState.t("season.maskButton"), swatch = "plum" },
		}
	do
		buttons[spec.id] = UI.button({
			Name = "Season_" .. spec.id,
			Size = UDim2.fromOffset(140, 48),
			Text = spec.text,
			swatch = spec.swatch,
			Visible = false,
			Parent = row,
		}, function()
			Net.get("Season"):FireServer(spec.id)
		end)
	end
	GameState.changed(GameState.Attributes.Holidays, refresh)
	GameState.changed(GameState.Attributes.Season, refresh)
	refresh()
	RunService.Heartbeat:Connect(function()
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local want = {
			crown = root ~= nil and active.Dragaica == true and homeNear(root),
			colinda = root ~= nil and active.Iarna == true and not homeNear(root),
			mask = root ~= nil and active.Iarna == true and not homeNear(root),
		}
		for id, button in buttons do
			if button.Visible ~= want[id] then
				button.Visible = want[id]
			end
		end
		-- masca de Malanca: cine e deghizat poartă o mască roșie peste cap
		for _, player in Players:GetPlayers() do
			local c = player.Character
			local head = c and c:FindFirstChild("Head") :: BasePart?
			if c and head then
				local until_ = c:GetAttribute("Malanca")
				local on = typeof(until_) == "number" and until_ > Workspace:GetServerTimeNow()
				local mask = head:FindFirstChild("MascaMalanca")
				if on and not mask then
					local m = Instance.new("Part")
					m.Name = "MascaMalanca"
					m.Size = Vector3.new(1.4, 1.4, 0.4)
					m.Color = Color3.fromRGB(200, 30, 40)
					m.Material = Enum.Material.Fabric
					m.CanCollide = false
					m.CanQuery = false
					m.Massless = true
					m.CFrame = head.CFrame * CFrame.new(0, 0, -0.65)
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = head
					weld.Part1 = m
					weld.Parent = m
					m.Parent = head
				elseif not on and mask then
					mask:Destroy()
				end
			end
		end
	end)
end

return SeasonController
