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
	"ClientReady", -- () clientul și-a conectat ascultătorii; serverul retrimite starea
	-- S→C
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
