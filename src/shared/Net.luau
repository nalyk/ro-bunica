--!strict
-- Remote-urile jocului. Serverul le creează, clientul le așteaptă.
-- Direcția e trecută în comentariu: C→S = de la client, S→C = de la server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	-- C→S
	"BuySeed", -- (seedId: string)
	"Plant", -- (bedKey: string, seedId: string)
	"MoveToCellar", -- (pedestalKey: string)
	"MoveToPedestal", -- (uid: string)
	"Sell", -- (uid: string)
	"Throw", -- (target: Vector3, kind: "Slipper" | "RollingPin")
	"Rage", -- ()
	"Hora", -- () jucătorul dansează hora (în vatra satului)
	"BuyUpgrade", -- (upgradeId: string) îmbunătățire a ogrăzii, pe lei
	"ClientReady", -- () clientul și-a conectat ascultătorii; serverul retrimite starea
	"Trade", -- (action: "request" | "respond" | "offer" | "accept" | "cancel", a, b) schimburile
	"Notebook", -- (action: "claimQuest" | "claimBonus" | "rebirth", arg: number?) Caietul Bunicii
	"Rutiera", -- C→S ("board" | "alight" | "destination", stop: string?); S→C ({ riding: boolean, destination: string? })
	"Season", -- (action: "crown" | "colinda" | "mask") acțiunile de sezon
	"Code", -- (code: string) codul tantii de la magazin
	"Market", -- C→S ("list" | "unlist" | "buy" | "refresh", a, b); S→C ({ listings, stalls, sunday }) bazarul
	"QuickChat", -- (id: string) mesaj rapid (Config/QuickChat), fără text liber
	"Care", -- ("feed" | "pet", uid: string) îngrijirea creaturilor
	"SetTitle", -- (id: string?) titlul de deasupra numelui (Domain/Titles)
	"BuyOutfit", -- (id: string) ținută pentru Bunica, pe lei
	"WearOutfit", -- (id: string?) ținuta purtată de Bunica
	"BuyDecor", -- (id: string) decorul ogrăzii, pe lei
	"PlaceDecor", -- (id: string?, slot: string) așază sau golește un slot
	"Fishing", -- C→S ("cast" | "reel" | "sell", a, b); S→C ({ state: "waiting" | "bite" | "result", ... })
	"MinigameAction", -- ("open" | "join" | "act", arg) mini-jocurile (MinigameService)
	"HappeningAction", -- (payload: any) acțiunea jucătorului în întâmplarea activă (VillageClockService)
	"SetSoul", -- (uid: string, on: boolean) creatură de suflet (nu se fură, nu se schimbă)
	"FamilyMode", -- (mode: "Family" | "Rival") alegerea față de prietenii de pe server
	"Greeted", -- () ecranul de încărcare s-a închis: Bunica îl întâmpină (o dată pe sesiune)
	"Share", -- ("link" | "invite") link-ul ogrăzii de partajat (PromptLinkSharingAsync pe server) | invitația deschisă
	-- S→C
	"Minigame", -- ({ id, site, state: "enroll" | "countdown" | "running" | "results" | "cancelled", ... })
	"Happening", -- ({ id, state: "warn" | "active" | "end", startsAt?, endsAt?, location? }) ceasul satului
	"State", -- (snapshot: PlayerState) starea completă a jucătorului
	"Notify", -- (key: string, args: {any}?) mesaj personal
	"Announce", -- (key: string, args: {any}?) mesaj pentru tot serverul
	"Projectile", -- (info) proiectil pentru randare locală
	"Hit", -- (position: Vector3, kind: string, ownerUserId: number) efectul loviturii
	"Knockback", -- (velocity: Vector3, stunSeconds: number) aplicat de clientul lovit
	"Alarm", -- (plotIndex: number) hoț în ograda ta
	"Shop", -- (stock: {[string]: number}, nextRestockAt: number)
	"Tutorial", -- (stage: string, data: {any}?) pașii din primul minut
	"Replay", -- (best: BestThrow) lovitura nopții, reluată la răsărit
	"TradeUpdate", -- (kind: "request" | "state" | "closed", data) cereri și fereastra de schimb
	"Revenge", -- ({ thief: number, name: string, uid: string }?) hoțul de urmărit până în zori (nil = gata)
	"Daily", -- (claim: {day, lei, seed?}, serverTime) recompensa zilnică
}

local FOLDER_NAME = "Remotes"

local Net = {}

local cache: { [string]: RemoteEvent } = {}

function Net.setupServer()
	assert(RunService:IsServer(), "Net.setupServer rulează doar pe server")
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, name in NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		cache[name] = remote
	end
	folder.Parent = ReplicatedStorage
end

function Net.get(name: string): RemoteEvent
	local cached = cache[name]
	if cached then
		return cached
	end
	assert(table.find(NAMES, name), "Remote necunoscut: " .. name)
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	local remote = folder:WaitForChild(name) :: RemoteEvent
	cache[name] = remote
	return remote
end

return Net
