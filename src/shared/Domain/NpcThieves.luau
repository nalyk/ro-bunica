--!strict
-- Logica pură pentru hoții vecini: câte încercări pe noapte, cine e țintă și ce creatură iau.

local Config = script.Parent.Parent.Config
local NpcThievesConfig = require(Config.NpcThieves)
local Creatures = require(Config.Creatures)
local Rarities = require(Config.Rarities)
local Economy = require(script.Parent.Economy)

type CreatureRecord = { uid: string, id: string, size: string, mutation: string? }

local NpcThieves = {}

-- Încercări pe noapte pentru numărul de jucători reali de pe server.
function NpcThieves.attempts(realPlayers: number): number
	if realPlayers <= 0 then
		return 0
	end
	return NpcThievesConfig.attemptsByPlayers[realPlayers] or 0
end

-- Pauză aleatorie dintr-un interval {min, max}.
function NpcThieves.delay(range: { number }, rng: () -> number): number
	return range[1] + (range[2] - range[1]) * rng()
end

-- Jucătorul e activ (nu AFK)?
function NpcThieves.isActive(lastActive: number?, now: number): boolean
	return lastActive ~= nil and now - lastActive <= NpcThievesConfig.activeWindowSeconds
end

-- Creatura țintită: cea mai valoroasă expusă, de raritate cel mult `maxRarityOrder`, care nu e deja cărată.
function NpcThieves.pickTarget(
	pedestals: { [string]: CreatureRecord },
	isCarried: (string) -> boolean
): string?
	local best: string? = nil
	local bestValue = -1
	for key, record in pedestals do
		local creature = Creatures.byId[record.id]
		local rarity = creature and Rarities.byId[creature.rarity]
		if rarity and rarity.order <= NpcThievesConfig.maxRarityOrder and not isCarried(record.uid) then
			local value = Economy.incomePerSecond(record)
			-- la egalitate, cheia mai mică: alegerea e deterministă
			if value > bestValue or (value == bestValue and best ~= nil and key < best) then
				best, bestValue = key, value
			end
		end
	end
	return best
end

return NpcThieves
