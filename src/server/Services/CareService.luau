--!strict
-- Îngrijirea creaturilor (Domain/Care): hrănești din beci (întâi un pește, apoi o plăcintă, apoi brânză
-- cumpărată pe loc), mângâi din ogradă. Fericirea scade încet cât ești pe server; peste 80 = +10% venit.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Care = require(Shared.Domain.Care)
local Fish = require(Shared.Config.Fish)
local Inventory = require(Shared.Domain.Inventory)
local RateLimiter = require(Shared.Domain.RateLimiter)
local PlotService = require(script.Parent.PlotService)
local CreatureService = require(script.Parent.CreatureService)
local EconomyService = require(script.Parent.EconomyService)
local StateService = require(script.Parent.StateService)
local Messenger = require(script.Parent.Messenger)

type Owner = PlotService.Owner

local CareService = {}

CareService.CHEESE_PRICE = 50
local DECAY_TICK = 60
local limiter = RateLimiter.new(8, 2)

local function find(owner: Owner, uid: string): any
	for _, record in owner.profile.pedestals do
		if record.uid == uid then
			return record
		end
	end
	for _, record in owner.profile.cellar do
		if record.uid == uid then
			return record
		end
	end
	return nil
end

local function refresh(owner: Owner, record: any)
	local key = Inventory.findPedestal(owner.profile, record.uid)
	local model = key and CreatureService.modelAt(owner, key)
	if model then
		model:SetAttribute("Happiness", math.floor(Care.happiness(record)))
	end
	StateService.markDirty(owner.player)
end

-- Hrana disponibilă, în ordine: un pește comestibil, o plăcintă, brânză cumpărată (50 lei)
local function takeFood(owner: Owner): string?
	local fish = (owner.profile.fish or {}) :: { [string]: number }
	for _, def in Fish.list do
		if def.id ~= "cizmaVeche" and not def.egg and (fish[def.id] or 0) > 0 then
			fish[def.id] -= 1
			return "peste"
		end
	end
	local food = (owner.profile.food or {}) :: { [string]: number }
	if (food.placinta or 0) > 0 then
		food.placinta -= 1
		return "placinta"
	end
	if owner.profile.lei >= CareService.CHEESE_PRICE then
		EconomyService.addLei(owner, -CareService.CHEESE_PRICE)
		return "branza"
	end
	return nil
end

function CareService.feed(owner: Owner, uid: string): string?
	local record = find(owner, uid)
	if not record or Care.happiness(record) >= 100 then
		return nil
	end
	local food = takeFood(owner)
	if not food then
		Messenger.notify(owner.player, "care.noFood")
		return nil
	end
	Care.feed(record, food)
	refresh(owner, record)
	return food
end

function CareService.pet(owner: Owner, uid: string): boolean
	local record = find(owner, uid)
	if not record or not Care.pet(record, Workspace:GetServerTimeNow()) then
		return false
	end
	refresh(owner, record)
	return true
end

function CareService.start()
	Net.get("Care").OnServerEvent:Connect(function(player, action, uid)
		local owner = PlotService.getOwner(player)
		if not owner or typeof(uid) ~= "string" or not limiter:allow(player.UserId, os.clock()) then
			return
		end
		if action == "feed" then
			CareService.feed(owner, uid)
		elseif action == "pet" then
			CareService.pet(owner, uid)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(DECAY_TICK)
			for _, owner in PlotService.owners() do
				if owner.kind == "Player" then
					for _, record in owner.profile.pedestals do
						Care.decay(record, DECAY_TICK)
					end
					for _, record in owner.profile.cellar do
						Care.decay(record, DECAY_TICK)
					end
				end
			end
		end
	end)
end

return CareService
