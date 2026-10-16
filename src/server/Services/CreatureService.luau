--!strict
-- Randează creaturile expuse pe piedestale și pe gardul de laudă.
-- Nu decide nimic despre furt; doar anunță când a creat un model (RaidService pune prompt-urile).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CreatureBuilder = require(Shared.Visual.CreatureBuilder)
local Economy = require(Shared.Domain.Economy)
local PlotService = require(script.Parent.PlotService)
local ArtFade = require(script.Parent.Parent.World.ArtFade)

type Owner = PlotService.Owner

local SHOWCASE_SCALE = 0.6

local CreatureService = {}

local modelsByOwner: { [Owner]: { [string]: Model } } = {}
local showcaseByOwner: { [Owner]: { Model } } = {}
local createdCallbacks: { (Owner, string, Model) -> () } = {}
local hidden: { [Owner]: { [string]: boolean } } = {} -- piedestale golite temporar (creatură cărată)

local function clearShowcase(owner: Owner)
	local list = showcaseByOwner[owner]
	if list then
		for _, model in list do
			model:Destroy()
		end
	end
	showcaseByOwner[owner] = {}
end

local function renderShowcase(owner: Owner)
	clearShowcase(owner)
	local records = {}
	for _, record in owner.profile.pedestals do
		table.insert(records, record)
	end
	table.sort(records, function(a, b)
		return Economy.incomePerSecond(a) > Economy.incomePerSecond(b)
	end)
	local shelves = owner.plot.geometry.showcase
	for index, shelf in shelves do
		local record = records[index]
		if not record then
			break
		end
		local pivot = shelf.CFrame * CFrame.new(0, shelf.Size.Y / 2, 0) * CFrame.Angles(0, math.pi, 0)
		local model =
			CreatureBuilder.build({ id = record.id, size = record.size, mutation = record.mutation }, pivot)
		model:ScaleTo(model:GetScale() * SHOWCASE_SCALE)
		CreatureBuilder.placeOn(model, pivot)
		model:SetAttribute("Showcase", true)
		model.Parent = owner.plot.geometry.creatureFolder
		table.insert(showcaseByOwner[owner], model)
	end
end

local function destroyKey(owner: Owner, key: string)
	local models = modelsByOwner[owner]
	if models and models[key] then
		models[key]:Destroy()
		models[key] = nil
	end
end

-- Redesenează un singur piedestal după datele din profil.
function CreatureService.renderKey(owner: Owner, key: string)
	destroyKey(owner, key)
	local record = owner.profile.pedestals[key]
	local pedestal = owner.plot.geometry.pedestals[key]
	if not record or not pedestal or (hidden[owner] and hidden[owner][key]) then
		return
	end
	local pivot = pedestal.CFrame * CFrame.Angles(0, 0, -math.pi / 2) * CFrame.new(0, pedestal.Size.X / 2, 0)
	-- Creaturile privesc spre drum
	pivot = CFrame.new(pivot.Position) * owner.plot.geometry.cframe.Rotation
	local model = CreatureBuilder.build(record, pivot)
	model:SetAttribute("PedestalKey", key)
	model:SetAttribute("OwnerUserId", owner.userId)
	model.Parent = owner.plot.geometry.creatureFolder
	modelsByOwner[owner] = modelsByOwner[owner] or {}
	modelsByOwner[owner][key] = model
	for _, callback in createdCallbacks do
		task.spawn(callback, owner, key, model)
	end
end

-- Redesenează tot ce ține de un proprietar.
function CreatureService.render(owner: Owner)
	local existing = modelsByOwner[owner]
	if existing then
		for key in existing do
			destroyKey(owner, key)
		end
	end
	modelsByOwner[owner] = {}
	for key in owner.profile.pedestals do
		CreatureService.renderKey(owner, key)
	end
	renderShowcase(owner)
	-- Piedestalele blocate se văd estompate
	for key, pedestal in owner.plot.geometry.pedestals do
		ArtFade.set(pedestal, if (tonumber(key) or 0) <= owner.profile.pedestalCount then 0 else 0.7)
	end
end

function CreatureService.modelAt(owner: Owner, key: string): Model?
	local models = modelsByOwner[owner]
	return if models then models[key] else nil
end

-- Ascunde temporar modelul unui piedestal (cât e cărat de un hoț) fără să atingă datele.
function CreatureService.setHidden(owner: Owner, key: string, isHidden: boolean)
	hidden[owner] = hidden[owner] or {}
	if isHidden then
		hidden[owner][key] = true
	else
		hidden[owner][key] = nil
	end
	if isHidden then
		-- Modelul e preluat de hoț; doar uităm referința
		local models = modelsByOwner[owner]
		if models then
			models[key] = nil
		end
	else
		CreatureService.renderKey(owner, key)
	end
end

-- Apelat pentru fiecare model nou; și pentru modelele deja existente la înregistrare.
function CreatureService.onModelCreated(callback: (Owner, string, Model) -> ())
	table.insert(createdCallbacks, callback)
	for owner, models in modelsByOwner do
		for key, model in models do
			task.spawn(callback, owner, key, model)
		end
	end
end

function CreatureService.refreshShowcase(owner: Owner)
	renderShowcase(owner)
end

function CreatureService.start()
	PlotService.refresh = CreatureService.render
	PlotService.onOwnerAdded(CreatureService.render)
	PlotService.onOwnerRemoving(function(owner)
		local existing = modelsByOwner[owner]
		if existing then
			for key in existing do
				destroyKey(owner, key)
			end
		end
		clearShowcase(owner)
		modelsByOwner[owner] = nil
		showcaseByOwner[owner] = nil
		hidden[owner] = nil
	end)
end

return CreatureService
