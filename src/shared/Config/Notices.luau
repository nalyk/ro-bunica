--!strict
-- Importanța fiecărui mesaj (Domain/NoticeQueue). Pe telefon se vede un singur mesaj odată, deci ordinea contează.
--   urgent: hoțul, furtul — sare în fața cozii și întrerupe orice alt mesaj
--   reward: ce ai reușit tu (descoperiri, recompense, eclozări)
--   hint:   de ce n-a mers ce ai încercat — scurt, doar cel mai nou rămâne în coadă
--   ambient: ce se întâmplă cu alții pe server — doar când coada e goală, expiră repede
--   quiet:  confirmarea unei apăsări dintr-un panou; pe ecran tactil nu apare (monedele care zboară spun tot)
-- Ce nu e în listă: `notify.*` e „reward”, `announce.*` e „ambient”.

export type Priority = "urgent" | "reward" | "hint" | "ambient" | "quiet"

local byKey: { [string]: Priority } = {
	-- urgent
	["notify.Alarm"] = "urgent",
	["notify.Stolen"] = "urgent",
	["notify.NpcThiefComing"] = "urgent",
	["notify.StealBack"] = "urgent",
	["notify.RevengeStart"] = "urgent",
	["notify.RevengeDone"] = "reward",
	["announce.Night"] = "urgent",
	-- indicii (după o acțiune care n-a mers)
	["notify.NotNight"] = "hint",
	["notify.Shielded"] = "hint",
	["notify.NewPlayer"] = "hint",
	["notify.Family"] = "hint",
	["notify.NightLimit"] = "hint",
	["notify.Soul"] = "hint",
	["notify.NoFight"] = "hint",
	["season.colindaDone"] = "hint",
	["season.colindaFar"] = "hint",
	["notify.Hram"] = "hint",
	["notify.ChainAlarm"] = "quiet",
	["code.Used"] = "hint",
	["code.Expired"] = "hint",
	["code.Unknown"] = "hint",
	["market.Far"] = "hint",
	["market.Missing"] = "hint",
	["market.Soul"] = "hint",
	["market.Listed"] = "hint",
	["market.Price"] = "hint",
	["market.StallFull"] = "hint",
	["market.NoStall"] = "hint",
	["market.Gone"] = "hint",
	["market.NotTradable"] = "hint",
	["market.Own"] = "hint",
	["market.NotEnoughLei"] = "hint",
	["market.CellarFull"] = "hint",
	["market.sold"] = "reward",
	["market.soldNpc"] = "reward",
	["notify.Listed"] = "hint",
	["notify.Hybrid"] = "reward",
	["care.noFood"] = "hint",
	["fishing.far"] = "hint",
	["fishing.egg"] = "reward",
	["notify.Busy"] = "hint",
	["happening.coneHit"] = "hint",
	["happening.mumaSeed"] = "reward",
	["happening.trainSeed"] = "reward",
	["rutiera.carrying"] = "hint",
	["rutiera.full"] = "hint",
	["notify.SoulMax"] = "hint",
	["notify.TradeSoul"] = "hint",
	["notify.Full"] = "hint",
	["notify.NotEnoughLei"] = "hint",
	["notify.OutOfStock"] = "hint",
	["notify.NotForSale"] = "hint",
	["notify.FamilyModeDayOnly"] = "hint",
	["notify.RebirthDayOnly"] = "hint",
	["notify.Max"] = "hint",
	["notify.TradeBusy"] = "hint",
	["notify.TradeWait"] = "hint",
	["notify.TradeTooMany"] = "hint",
	["notify.TradeNotEnoughLei"] = "hint",
	["notify.TradeDuplicate"] = "hint",
	["notify.TradeNotInCellar"] = "hint",
	["notify.TradeNotTradable"] = "hint",
	["notify.TradeFull"] = "hint",
	["hora.goToWell"] = "hint",
	-- confirmări de panou
	["notify.Sold"] = "quiet",
	["notify.QuestReward"] = "quiet",
	["notify.UpgradeBought"] = "quiet",
	["notify.TradeSent"] = "quiet",
	-- deja vizibile în HUD (vremea are rândul ei sub ceas)
	["announce.Weather"] = "quiet",
}

local Notices = {}

function Notices.priority(key: string): Priority
	local known = byKey[key]
	if known then
		return known :: Priority
	end
	-- întâmplările satului: anunțul și pornirea sunt urgente (toată lumea trebuie să afle); răsplata e reward
	if string.sub(key, 1, 10) == "happening." and key ~= "happening.reward" then
		return "urgent"
	end
	local fallback: Priority = if string.sub(key, 1, 9) == "announce." then "ambient" else "reward"
	return fallback
end

return table.freeze(Notices)
