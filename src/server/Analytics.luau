--!strict
-- Măsurătorile (GDD §17), prin AnalyticsService de la Roblox: funnel-ul primelor minute, fluxurile de lei
-- (surse și cheltuieli) și evenimente proprii (furturi, apărări, horă). Doar pentru jucători reali; erorile
-- serviciului nu ajung niciodată în joc (pcall). Pașii funnel-ului se trimit o singură dată pe profil.

local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

-- Funnel-ul primelor minute, în ordine (numărul pasului contează pentru Roblox)
Analytics.FUNNEL = {
	"Joined", -- 1. a intrat
	"StarterHatched", -- 2. sămânța de start a eclozat
	"TutorialThief", -- 3. a prins hoțul din primul minut
	"FirstSeedBought", -- 4. a cumpărat o sămânță
	"FirstPlanted", -- 5. a plantat
	"FirstNight", -- 6. a prins prima noapte
	"FirstUpgrade", -- 7. prima îmbunătățire
	"FirstSteal", -- 8. primul furt reușit
	"FirstDefend", -- 9. prima apărare cu papucul
}

local CURRENCY = "Lei"

-- Funnel-ul social (al doilea funnel): cum ajung jucătorii să joace cu prietenii
Analytics.SOCIAL = { "Invited", "FriendArrived", "FamilyFormed" }
local socialSession: { [Player]: string } = {}
local socialDone: { [Player]: { [string]: boolean } } = {}

-- Câmpurile custom (segmentarea în Dashboard): limba, familie sau singur, regiune cu restricții
local function fields(player: Player): { [string]: string }
	return {
		[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = string.sub(player.LocaleId, 1, 2),
		[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = if player:GetAttribute("FamilyId") ~= nil
			then "familie"
			else "singur",
		[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = if player:GetAttribute("PaidRandomRestricted")
				== true
			then "restrictii"
			else "liber",
	}
end

type ProfileLike = { lei: number, funnel: { [string]: boolean } }

local function safe(fn: () -> ())
	local ok, err = pcall(fn :: any)
	if not ok then
		warn("[Analytics]", err)
	end
end

-- Un pas din funnel, o singură dată pe profil
function Analytics.step(player: Player?, profile: ProfileLike, name: string)
	if not player or profile.funnel[name] then
		return
	end
	local index = table.find(Analytics.FUNNEL, name)
	if not index then
		return
	end
	profile.funnel[name] = true
	safe(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, index, name)
	end)
end

-- Lei câștigați: `kind` = Income | Sell | DefenseReward | Offline | IAP
function Analytics.source(player: Player?, profile: ProfileLike, amount: number, kind: string, sku: string?)
	if not player or amount <= 0 then
		return
	end
	safe(function()
		local transaction = if kind == "IAP" then Enum.AnalyticsEconomyTransactionType.IAP.Name else kind
		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			CURRENCY,
			math.floor(amount),
			math.floor(profile.lei),
			transaction,
			sku,
			fields(player)
		)
	end)
end

-- Lei cheltuiți: `kind` = Shop | Gameplay
function Analytics.sink(player: Player?, profile: ProfileLike, amount: number, kind: string, sku: string?)
	if not player or amount <= 0 then
		return
	end
	safe(function()
		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Sink,
			CURRENCY,
			math.floor(amount),
			math.floor(profile.lei),
			kind,
			sku,
			fields(player)
		)
	end)
end

-- Eveniment propriu (Steal, Defend, Hora, RobuxPurchase...)
function Analytics.event(player: Player?, name: string, value: number?)
	if not player then
		return
	end
	safe(function()
		AnalyticsService:LogCustomEvent(player, name, value or 1, fields(player))
	end)
end

-- Un pas din funnel-ul social, o dată pe sesiune
function Analytics.social(player: Player?, name: string)
	local index = table.find(Analytics.SOCIAL, name)
	if not player or not index then
		return
	end
	local done = socialDone[player] or {}
	socialDone[player] = done
	if done[name] then
		return
	end
	done[name] = true
	local session = socialSession[player] or (tostring(player.UserId) .. ":" .. tostring(os.time()))
	socialSession[player] = session
	safe(function()
		AnalyticsService:LogFunnelStepEvent(player, "Social", session, index, name, fields(player))
	end)
end

function Analytics.forget(player: Player)
	socialSession[player] = nil
	socialDone[player] = nil
end

return Analytics
