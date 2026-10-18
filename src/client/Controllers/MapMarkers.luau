--!strict
-- Semnele vii ale satului, pentru busolă și pentru hartă: ograda ta (roșie și pulsând când intră un hoț),
-- prietenii și familia, întâmplarea ceasului satului, mini-jocul la care se intră acum, rutiera și ținta
-- aleasă pe hartă. Totul din ce știe deja clientul (atribute, evenimente, VillageLayout); nimic nou pe rețea.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local VillageLayout = require(Shared.Domain.VillageLayout)
local Minigames = require(Shared.Config.Minigames)
local ClientState = require(script.Parent.ClientState)

export type Marker = {
	id: string,
	kind: "home" | "friend" | "happening" | "minigame" | "rutiera" | "waypoint",
	position: Vector3,
	label: string?, -- numele (prieten, loc), deja tradus
	icon: string?, -- iconița din UiIcons
	glyph: string, -- emoji, dacă iconița lipsește
	color: Color3,
	priority: number, -- 0 = cel mai important (rândul de sus pe busolă)
	pinned: boolean, -- rămâne pe marginea busolei când e în spate
	alert: boolean, -- pulsează
	endsAt: number?, -- numărătoarea (timpul serverului)
}

local MapMarkers = {}

MapMarkers.COLORS = {
	home = Color3.fromRGB(255, 214, 102),
	alarm = Color3.fromRGB(255, 70, 70),
	friend = Color3.fromRGB(120, 220, 140),
	happening = Color3.fromRGB(255, 160, 60),
	minigame = Color3.fromRGB(110, 190, 255),
	rutiera = Color3.fromRGB(255, 200, 40),
	waypoint = Color3.fromRGB(255, 255, 255),
}

local ALARM_SECONDS = 15
local me = Players.LocalPlayer
local sites = VillageLayout.build().sites
local happening: { id: string, location: Vector3?, endsAt: number?, startsAt: number?, state: string }? = nil
local lobby: { id: string, closesAt: number? }? = nil
local alarmUntil = 0
local friends: { [number]: boolean } = {}
local waypoint: { position: Vector3, label: string }? = nil
local waypointListeners: { (Vector3?) -> () } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- Ținta aleasă pe hartă (nil o șterge)
function MapMarkers.setWaypoint(position: Vector3?, label: string?)
	waypoint = if position then { position = position, label = label or "" } else nil
	for _, listener in waypointListeners do
		task.spawn(listener, position)
	end
end

function MapMarkers.waypoint(): Vector3?
	return waypoint and waypoint.position
end

function MapMarkers.onWaypoint(listener: (Vector3?) -> ())
	table.insert(waypointListeners, listener)
end

function MapMarkers.sites(): { [string]: CFrame }
	return sites
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function MapMarkers.list(): { Marker }
	local list: { Marker } = {}
	local plot = ClientState.myPlot()
	if plot then
		local alarm = now() < alarmUntil
		table.insert(list, {
			id = "home",
			kind = "home",
			position = plot:GetPivot().Position,
			label = ClientState.t("map.home"),
			icon = if alarm then "alarm" else "yard",
			glyph = "🏡",
			color = if alarm then MapMarkers.COLORS.alarm else MapMarkers.COLORS.home,
			priority = if alarm then 0 else 2,
			pinned = true,
			alert = alarm,
		})
	end
	local myFamily = me:GetAttribute("FamilyId")
	for _, player in Players:GetPlayers() do
		if player ~= me then
			local root = rootOf(player)
			local family = myFamily ~= nil and player:GetAttribute("FamilyId") == myFamily
			if root and (family or friends[player.UserId]) then
				table.insert(list, {
					id = "friend" .. player.UserId,
					kind = "friend",
					position = root.Position,
					label = player.DisplayName,
					icon = "family",
					glyph = "🙂",
					color = MapMarkers.COLORS.friend,
					priority = 4,
					pinned = false,
					alert = false,
				})
			end
		end
	end
	local active = happening
	if active and active.location then
		table.insert(list, {
			id = "happening",
			kind = "happening",
			position = active.location,
			label = ClientState.t("happening." .. active.id),
			icon = nil,
			glyph = "⭐",
			color = MapMarkers.COLORS.happening,
			priority = 1,
			pinned = true,
			alert = active.state == "warn",
			endsAt = if active.state == "warn" then active.startsAt else active.endsAt,
		})
	end
	local open = lobby
	if open then
		local def = Minigames.byId[open.id]
		local site = def and sites[def.site]
		if site and (open.closesAt or 0) > now() then
			table.insert(list, {
				id = "minigame",
				kind = "minigame",
				position = site.Position,
				label = ClientState.t("minigame." .. open.id),
				icon = nil,
				glyph = "🎲",
				color = MapMarkers.COLORS.minigame,
				priority = 1,
				pinned = true,
				alert = true,
				endsAt = open.closesAt,
			})
		end
	end
	local bus = Workspace:FindFirstChild("Rutiera")
	if bus and bus:IsA("Model") then
		table.insert(list, {
			id = "rutiera",
			kind = "rutiera",
			position = bus:GetPivot().Position,
			label = ClientState.t("map.rutiera"),
			icon = nil,
			glyph = "🚐",
			color = MapMarkers.COLORS.rutiera,
			priority = 5,
			pinned = false,
			alert = false,
		})
	end
	if waypoint then
		table.insert(list, {
			id = "waypoint",
			kind = "waypoint",
			position = waypoint.position,
			label = waypoint.label,
			icon = nil,
			glyph = "📍",
			color = MapMarkers.COLORS.waypoint,
			priority = 0,
			pinned = true,
			alert = false,
		})
	end
	return list
end

function MapMarkers.start()
	Net.get("Happening").OnClientEvent:Connect(function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		if payload.state == "end" then
			happening = nil
		else
			happening = payload
		end
	end)
	Net.get("Minigame").OnClientEvent:Connect(function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		if payload.state == "enroll" then
			lobby = { id = payload.id, closesAt = payload.closesAt }
		elseif lobby and lobby.id == payload.id then
			lobby = nil
		end
	end)
	Net.get("Alarm").OnClientEvent:Connect(function()
		alarmUntil = now() + ALARM_SECONDS
	end)
	-- prietenii Roblox de pe server (o singură cerere pe jucător)
	local function check(player: Player)
		if player == me then
			return
		end
		local ok, isFriend = pcall(me.IsFriendsWith, me, player.UserId)
		friends[player.UserId] = ok and isFriend == true
	end
	Players.PlayerAdded:Connect(check)
	for _, player in Players:GetPlayers() do
		task.spawn(check, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		friends[player.UserId] = nil
	end)
end

return MapMarkers
