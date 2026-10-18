--!strict
-- Plăcintăria nebună (co-op, 2–4 jucători, 2 minute, la bucătăria de vară): comenzile vin pe bilețele
-- (brânză, varză, vișine). Fiecare face plăcinta lui la stații: aluat → umplutură → cuptor (pui, aștepți 3 s,
-- scoți) → livrare. O plăcintă livrată pe o comandă deschisă = un punct pentru toată echipa și 10 minute de
-- creștere mai rapidă în ogradă (GardenService.boost).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Recipe = require(Shared.Domain.Recipe)
local Kit = require(script.Parent.Parent.Happenings.Kit)
local GardenService = require(script.Parent.Parent.Services.GardenService)

local Placinte = {}

Placinte.REACH = 7
Placinte.BAKE_SECONDS = 3
Placinte.BOOST_SECONDS = 600
Placinte.BOOST_FACTOR = 1.25
local ORDER_EVERY = 15
local MAX_ORDERS = 4

local STATIONS = {
	{ id = "Aluat", offset = Vector3.new(0, 0, -7), color = Color3.fromRGB(240, 230, 200) },
	{ id = "Branza", offset = Vector3.new(-7, 0, -4), color = Color3.fromRGB(250, 250, 240) },
	{ id = "Varza", offset = Vector3.new(-7, 0, 0), color = Color3.fromRGB(150, 200, 110) },
	{ id = "Visine", offset = Vector3.new(-7, 0, 4), color = Color3.fromRGB(140, 20, 50) },
	{ id = "Cuptor", offset = Vector3.new(9, 0, 1), color = Color3.fromRGB(226, 204, 170) },
	{ id = "Livrare", offset = Vector3.new(0, 0, -13), color = Color3.fromRGB(60, 112, 186) },
}

local function publish(match: any)
	local stations = {}
	for id, position in match.data.stations do
		table.insert(stations, { id = id, text = "minigame.station." .. id, position = position })
	end
	local pies = {}
	for owner, pie in match.data.pies do
		pies[tostring(owner.userId)] = Recipe.next(pie)
	end
	match.publish({
		orders = match.data.orders,
		stations = stations,
		pies = pies,
		delivered = match.data.delivered,
	})
end

local function addOrder(match: any)
	if #match.data.orders < MAX_ORDERS then
		table.insert(match.data.orders, Recipe.ORDERS[match.data.rng:NextInteger(1, #Recipe.ORDERS)])
	end
end

function Placinte.setup(match: any)
	match.data.rng = Random.new()
	match.data.stations = {}
	for _, def in STATIONS do
		local p = (match.arena * CFrame.new(def.offset)).Position
		local at = Vector3.new(p.X, Kit.groundY(p.X, p.Z), p.Z)
		match.data.stations[def.id] = at
		if def.id == "Branza" or def.id == "Varza" or def.id == "Visine" then
			local bowl = Instance.new("Part")
			bowl.Name = "Castron" .. def.id
			bowl.Shape = Enum.PartType.Cylinder
			bowl.Size = Vector3.new(1, 2.4, 2.4)
			bowl.CFrame = CFrame.new(at + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			bowl.Color = def.color
			bowl.Anchored = true
			bowl.CanCollide = false
			bowl.Parent = match.folder
			local stand = Instance.new("Part")
			stand.Name = "Masuta"
			stand.Size = Vector3.new(3, 2, 3)
			stand.CFrame = CFrame.new(at + Vector3.new(0, 1, 0))
			stand.Color = Color3.fromRGB(128, 86, 52)
			stand.Material = Enum.Material.WoodPlanks
			stand.Anchored = true
			stand.Parent = match.folder
		end
	end
	match.data.orders = {}
	match.data.pies = {}
	match.data.oven = {}
	match.data.delivered = 0
	for _, owner in match.players do
		match.data.pies[owner] = Recipe.new()
	end
	addOrder(match)
	addOrder(match)
	match.data.nextOrder = os.clock() + ORDER_EVERY
	publish(match)
end

function Placinte.station(match: any, id: string): Vector3
	return match.data.stations[id]
end

function Placinte.action(match: any, owner: any, payload: any)
	if typeof(payload) ~= "table" or typeof(payload.station) ~= "string" then
		return
	end
	local station = match.data.stations[payload.station]
	local root = Kit.root(owner)
	local pie = match.data.pies[owner]
	if not station or not root or not pie then
		return
	end
	if
		Vector3.new(root.Position.X - station.X, 0, root.Position.Z - station.Z).Magnitude > Placinte.REACH
	then
		return
	end
	local id = payload.station
	if id == "Aluat" then
		Recipe.apply(pie, "Aluat")
	elseif id == "Branza" or id == "Varza" or id == "Visine" then
		Recipe.apply(pie, "Umplutura:" .. id)
	elseif id == "Cuptor" then
		-- pui plăcinta, aștepți, o scoți
		local baking = match.data.oven[owner]
		if not baking and Recipe.next(pie) == "Cuptor" then
			match.data.oven[owner] = os.clock() + Placinte.BAKE_SECONDS
		elseif baking and os.clock() >= baking then
			match.data.oven[owner] = nil
			Recipe.apply(pie, "Cuptor")
		end
	elseif id == "Livrare" then
		for index, order in match.data.orders do
			if Recipe.complete(order, pie) then
				table.remove(match.data.orders, index)
				match.data.delivered += 1
				for _, member in match.players do
					match.score(member, 1) -- co-op: punctul e al echipei
					GardenService.boost(member, Placinte.BOOST_SECONDS, Placinte.BOOST_FACTOR)
				end
				match.data.pies[owner] = Recipe.new()
				break
			end
		end
	end
	publish(match)
end

function Placinte.tick(match: any, _dt: number)
	if os.clock() >= match.data.nextOrder then
		match.data.nextOrder = os.clock() + ORDER_EVERY
		addOrder(match)
		publish(match)
	end
end

return Placinte
