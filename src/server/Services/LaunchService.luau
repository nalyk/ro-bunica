--!strict
-- Sosirile din link-uri, invitații, clipuri și notificări (LaunchData, Domain/Launch):
-- • cine vine la ograda unui prieten ajunge pe serverul lui (Presence + TeleportService) și intră în
--   familia lui pe sesiunea asta (FamilyService.bond);
-- • recomandările (Domain/Referral): jucătorul nou adus de cineva → „Musafirul”, iar cel care l-a adus
--   → „Gazda satului”, după 10 minute de joc ale celui nou. Recompensele pentru cine nu e pe server
--   așteaptă în DataStore („Referrals”) și se iau la intrare sau la semnalul MessagingService.
-- • „Trimite link-ul ogrăzii”: PromptLinkSharingAsync (doar pe server), cu LaunchData spre ograda ta.

local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local TeleportService = game:GetService("TeleportService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Launch = require(Shared.Domain.Launch)
local Referral = require(Shared.Domain.Referral)
local RateLimiter = require(Shared.Domain.RateLimiter)
local Strings = require(Shared.Strings)
local Net = require(Shared.Net)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)
local FamilyService = require(script.Parent.FamilyService)
local Messenger = require(script.Parent.Messenger)
local Presence = require(script.Parent.Parent.Social.Presence)
local Analytics = require(script.Parent.Parent.Analytics)

type Owner = PlotService.Owner

local LaunchService = {}

local TOPIC = "Referral"
local shareLimiter = RateLimiter.new(2, 1 / 30)
local teleported: { [number]: boolean } = {}

local referrals: DataStore? = nil
local function referralStore(): DataStore?
	if not referrals then
		local ok, store = pcall(DataStoreService.GetDataStore, DataStoreService, "Referrals")
		referrals = if ok then store else nil
	end
	return referrals
end

-- Datele de lansare ale jucătorului (nil dacă a intrat normal); testele le pot impune
local forced: { [Player]: string? } = {}
function LaunchService.force(player: Player, text: string?)
	forced[player] = text
end

local function launchOf(player: Player): Launch.Data?
	local text = forced[player]
	if text then
		return Launch.decode(text)
	end
	local ok, join = pcall(player.GetJoinData, player)
	return if ok and type(join) == "table" then Launch.decode((join :: any).LaunchData) else nil
end

-- Jucătorii reali și boții care țin locul unui jucător (teste)
local function isPerson(owner: Owner): boolean
	return owner.player ~= nil or owner.standIn == true
end

local function ownerById(userId: number): Owner?
	for _, owner in PlotService.owners() do
		if owner.userId == userId and isPerson(owner) then
			return owner
		end
	end
	return nil
end

local function addStat(owner: Owner, field: string, amount: number)
	local stats = owner.profile.stats :: any
	stats[field] = (stats[field] or 0) + amount
	StateService.markDirty(owner.player)
end

-- Ia recompensele de recomandare în așteptare (DataStore), cu plafonul total
function LaunchService.claimPending(owner: Owner)
	local store = referralStore()
	if not store or not isPerson(owner) then
		return
	end
	local pending = 0
	local ok = pcall(store.UpdateAsync, store, tostring(owner.userId), function(old: number?)
		pending = old or 0
		return if pending > 0 then 0 else nil
	end)
	if ok and pending > 0 then
		local gained = Referral.claim((owner.profile.stats :: any).referrals or 0, pending)
		if gained > 0 then
			addStat(owner, "referrals", gained)
			Messenger.notify(owner.player, "notify.ReferralHost")
		end
	end
end

-- Recompensa pentru cine a adus un prieten: direct, dacă e pe server; altfel prin DataStore + semnal
local function rewardReferrer(referrer: number)
	local owner = ownerById(referrer)
	if owner then
		if Referral.claim((owner.profile.stats :: any).referrals or 0, 1) > 0 then
			addStat(owner, "referrals", 1)
			Messenger.notify(owner.player, "notify.ReferralHost")
		end
		return
	end
	local store = referralStore()
	if store then
		pcall(store.UpdateAsync, store, tostring(referrer), function(old: number?)
			return (old or 0) + 1
		end)
		pcall(MessagingService.PublishAsync, MessagingService, TOPIC, referrer)
	end
end

-- Recompensele recomandărilor ajunse la termen (10 minute de joc ale celui nou)
function LaunchService.checkReferrals()
	for _, owner in PlotService.owners() do
		local profile = owner.profile :: any
		if isPerson(owner) and Referral.due(profile) then
			profile.referralRewarded = true
			addStat(owner, "welcomed", 1)
			Messenger.notify(owner.player, "notify.ReferralGuest")
			rewardReferrer(profile.referredBy)
		end
	end
end

-- Leagă un jucător nou de cel care l-a adus (o singură dată); întoarce dacă s-a legat
function LaunchService.linkReferral(owner: Owner, data: Launch.Data?): boolean
	local referrer = Launch.referrerFor(data, owner.userId)
	if Referral.canLink(owner.profile :: any, referrer, owner.userId) then
		(owner.profile :: any).referredBy = referrer
		StateService.markDirty(owner.player)
		return true
	end
	return false
end

local function arrive(owner: Owner)
	local player = owner.player
	if not player then
		return
	end
	local data = launchOf(player)
	if not data then
		return
	end
	LaunchService.linkReferral(owner, data)
	local host = data.host
	if not host or host == player.UserId then
		return
	end
	local hostPlayer = Players:GetPlayerByUserId(host)
	if hostPlayer then
		Analytics.social(hostPlayer, "FriendArrived")
		FamilyService.bond(player, hostPlayer)
		Messenger.notify(player, "notify.JoinedHost", { hostPlayer.DisplayName })
		Messenger.notify(hostPlayer, "notify.HostArrived", { player.DisplayName })
		return
	end
	-- gazda e pe alt server: o singură încercare de mutare (serverul ei poate fi plin)
	local job = Presence.jobOf(host)
	if job and job ~= game.JobId and not teleported[player.UserId] then
		teleported[player.UserId] = true
		Messenger.notify(player, "notify.GoingToHost")
		local options = Instance.new("TeleportOptions")
		options.ServerInstanceId = job
		local ok = pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, { player }, options)
		if not ok then
			Messenger.notify(player, "notify.HostUnreachable")
		end
	end
end

-- „Trimite link-ul ogrăzii”: link de partajat cu LaunchData spre ograda (și serverul) jucătorului
function LaunchService.shareLink(player: Player): boolean
	local language = Strings.languageFor(player.LocaleId)
	local launch = Launch.encode({ kind = "yard", host = player.UserId, referrer = player.UserId })
	local ok = pcall(SocialService.PromptLinkSharingAsync, SocialService, player, {
		LaunchData = launch,
		ExpirationSeconds = 7 * 24 * 3600,
		PreviewTitle = Strings.get(language, "share.title", { player.DisplayName }),
		PreviewDescription = Strings.get(language, "share.description"),
	})
	return ok
end

function LaunchService.start()
	Presence.start()
	PlotService.onOwnerAdded(function(owner)
		task.spawn(arrive, owner)
		task.spawn(LaunchService.claimPending, owner)
	end)
	Players.PlayerRemoving:Connect(function(player)
		forced[player] = nil
	end)
	pcall(MessagingService.SubscribeAsync, MessagingService, TOPIC, function(message)
		local player = Players:GetPlayerByUserId(tonumber(message.Data) or 0)
		local owner = player and PlotService.getOwner(player)
		if owner then
			LaunchService.claimPending(owner)
		end
	end)
	Net.get("Share").OnServerEvent:Connect(function(player, action)
		if action == "link" and shareLimiter:allow(player.UserId, os.clock()) then
			Analytics.social(player, "Invited")
			LaunchService.shareLink(player)
		elseif action == "invite" then -- invitația Roblox a fost deschisă (din FriendsPanel)
			Analytics.social(player, "Invited")
		end
	end)
	task.spawn(function()
		while true do
			task.wait(30)
			LaunchService.checkReferrals()
		end
	end)
end

return LaunchService
