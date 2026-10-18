--!strict
-- Decorul ogrăzii (Domain/Decor, Config/Decor): cumperi pe lei și așezi pe sloturi; obiectele apar în ograda
-- ta (doar vizual: fără coliziuni, fără avantaj). Poarta vopsită schimbă culoarea porții.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Decor = require(Shared.Domain.Decor)
local DecorConfig = require(Shared.Config.Decor)
local VillageLayout = require(Shared.Domain.VillageLayout)
local Village = require(Shared.Config.Village)
local RateLimiter = require(Shared.Domain.RateLimiter)
local DecorModels = require(script.Parent.Parent.World.DecorModels)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)
local Messenger = require(script.Parent.Messenger)
local Analytics = require(script.Parent.Parent.Analytics)
local Progress = require(script.Parent.Parent.Progress)

type Owner = PlotService.Owner

local DecorService = {}

local limiter = RateLimiter.new(6, 2)

local function folderOf(owner: Owner): Folder
	local model = owner.plot.geometry.model
	local folder = model:FindFirstChild("Decor") :: Folder?
	if not folder then
		local created = Instance.new("Folder")
		created.Name = "Decor"
		created.Parent = model
		folder = created
	end
	return folder :: Folder
end

local function paintGate(owner: Owner, color: Color3)
	for _, child in owner.plot.geometry.model:GetDescendants() do
		if
			child:IsA("BasePart")
			and (child.Name == "GatePost" or (child.Parent and child.Parent.Name == "world.Poarta"))
		then
			child.Color = color
		end
	end
end

-- Desenează decorul proprietarului în ograda lui (de la zero)
function DecorService.render(owner: Owner)
	local folder = folderOf(owner)
	folder:ClearAllChildren()
	local cf = owner.plot.geometry.cframe
	local gateColor = VillageLayout.variantFor(owner.plot.index, Village.variantSeed).gateColor
	for slotId, id in (owner.profile.decor or {}) :: { [string]: string } do
		local item, slot = DecorConfig.byId[id], DecorConfig.slotById[slotId]
		if item and slot then
			if item.kind == "gate" then
				gateColor = item.color or gateColor
			else
				local at = cf * CFrame.new(slot.offset) * CFrame.Angles(0, math.rad(slot.turn), 0)
				DecorModels.build(id, item.kind, item.color, at, folder)
			end
		end
	end
	paintGate(owner, gateColor)
end

function DecorService.buy(owner: Owner, id: string): boolean
	local ok, reason = Decor.canBuy(owner.profile, id)
	if not ok then
		Messenger.notify(owner.player, "notify." .. tostring(reason))
		return false
	end
	local price = Decor.price(id)
	Decor.buy(owner.profile, id)
	Analytics.sink(owner.player, owner.profile, price, "Decor", id)
	StateService.markDirty(owner.player)
	return true
end

-- Așază (sau, cu id nil, golește) un slot
function DecorService.place(owner: Owner, id: string?, slotId: string): boolean
	if id == nil then
		Decor.remove(owner.profile, slotId)
	elseif not Decor.place(owner.profile, id, slotId) then
		return false
	end
	DecorService.render(owner)
	Progress.emit(owner, "decor", Decor.placedCount(owner.profile))
	StateService.markDirty(owner.player)
	return true
end

function DecorService.start()
	Net.get("BuyDecor").OnServerEvent:Connect(function(player, id)
		local owner = PlotService.getOwner(player)
		if owner and typeof(id) == "string" and limiter:allow(player.UserId, os.clock()) then
			DecorService.buy(owner, id)
		end
	end)
	Net.get("PlaceDecor").OnServerEvent:Connect(function(player, id, slot)
		local owner = PlotService.getOwner(player)
		if
			owner
			and typeof(slot) == "string"
			and (id == nil or typeof(id) == "string")
			and limiter:allow(player.UserId, os.clock())
		then
			DecorService.place(owner, id, slot)
		end
	end)
	PlotService.onOwnerAdded(function(owner)
		if owner.kind == "Player" then
			DecorService.render(owner)
		end
	end)
	PlotService.onOwnerRemoving(function(owner)
		local folder = owner.plot.geometry.model:FindFirstChild("Decor")
		if folder then
			folder:ClearAllChildren()
		end
		paintGate(owner, VillageLayout.variantFor(owner.plot.index, Village.variantSeed).gateColor)
	end)
end

return DecorService
