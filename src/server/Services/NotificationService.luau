--!strict
-- Notificările după plecare (Domain/NotifyPlan): la ieșirea din joc se alege una (plantele coapte, sâmbăta
-- în sat, bazarul de duminică) și se pune într-un sorted map MemoryStore, cu scadența drept cheie de
-- sortare. Orice server pornit le ia pe cele ajunse la termen și le trimite prin Open Cloud
-- (UserNotification). Cine revine în joc între timp nu mai primește nimic. Roblox livrează doar celor
-- 13+ care au acceptat notificările, cel mult una pe zi. Fără secretul Open Cloud (Config/Notifications.secret)
-- nu se trimite nimic.

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Notifications = require(Shared.Config.Notifications)
local EconomyConfig = require(Shared.Config.Economy)
local Growth = require(Shared.Domain.Growth)
local NotifyPlan = require(Shared.Domain.NotifyPlan)
local Launch = require(Shared.Domain.Launch)
local PlotService = require(script.Parent.PlotService)

type Owner = PlotService.Owner

local NotificationService = {}

local POLL = 60
local BATCH = 50

local queue: MemoryStoreSortedMap? = nil
local function store(): MemoryStoreSortedMap?
	if not queue then
		local ok, map = pcall(MemoryStoreService.GetSortedMap, MemoryStoreService, "Notify")
		queue = if ok then map else nil
	end
	return queue
end

-- Peste cât timp se coc toate plantele care se pot coace cât lipsește jucătorul (nil dacă niciuna)
function NotificationService.growSeconds(owner: Owner): number?
	local latest: number? = nil
	for _, plant in owner.profile.beds do
		local left = Growth.secondsLeft(plant :: any, 1)
		if left > 0 and left <= EconomyConfig.offlineCapSeconds then
			latest = math.max(latest or 0, left)
		end
	end
	return latest
end

-- Trimite o notificare prin Open Cloud; întoarce codul HTTP (0 dacă cererea n-a plecat)
function NotificationService.send(userId: number, kind: string): (number, string?)
	local message = Notifications.messages[kind]
	if not message or message == "" then
		return 0, "no-message"
	end
	-- cheia Open Cloud (scope user.user-notification:write) stă în Secrets-ul experienței, nu în cod
	local okSecret, secret = pcall(HttpService.GetSecret, HttpService, Notifications.secret)
	if not okSecret then
		return 0, "no-secret"
	end
	local body = HttpService:JSONEncode({
		source = { universe = "universes/" .. tostring(game.GameId) },
		payload = { message_id = message, type = "MOMENT" },
		join_experience = { launch_data = Launch.encode({ kind = "notify" }) },
		analytics_data = { category = kind },
	})
	local ok, response = pcall(HttpService.RequestAsync, HttpService, {
		Url = string.format("https://apis.roblox.com/cloud/v2/users/%d/notifications", userId),
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json", ["x-api-key"] = secret :: any },
		Body = body,
	})
	if not ok then
		return 0, tostring(response)
	end
	return (response :: any).StatusCode, (response :: any).Body
end

local function schedule(owner: Owner)
	local map = store()
	if not map or owner.kind ~= "Player" then
		return
	end
	local now = os.time()
	local plan = NotifyPlan.choose(now, { growSeconds = NotificationService.growSeconds(owner) })
	if plan and Notifications.messages[plan.kind] ~= "" then
		local ttl = math.clamp(plan.due - now + 6 * 3600, 60, 30 * 24 * 3600)
		pcall(map.SetAsync, map, tostring(owner.userId), plan.kind, ttl, plan.due)
	end
end

local function cancel(owner: Owner)
	local map = store()
	if map and owner.kind == "Player" then
		pcall(map.RemoveAsync, map, tostring(owner.userId))
	end
end

-- Trimite notificările ajunse la termen (orice server poate; Roblox oricum limitează la una pe zi)
function NotificationService.poll()
	local map = store()
	if not map then
		return
	end
	local ok, items = pcall(map.GetRangeAsync, map, Enum.SortDirection.Ascending, BATCH, nil, {
		sortKey = os.time() + 1,
	})
	if not ok or type(items) ~= "table" then
		return
	end
	for _, item in items :: { any } do
		local removed = pcall(map.RemoveAsync, map, item.key)
		local userId = tonumber(item.key)
		if removed and userId and type(item.value) == "string" then
			NotificationService.send(userId, item.value)
		end
	end
end

function NotificationService.start()
	PlotService.onOwnerAdded(function(owner)
		task.spawn(cancel, owner)
	end)
	PlotService.onOwnerRemoving(function(owner)
		task.spawn(schedule, owner)
	end)
	task.spawn(function()
		while true do
			task.wait(POLL)
			NotificationService.poll()
		end
	end)
end

return NotificationService
