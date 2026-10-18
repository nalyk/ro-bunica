--!strict
-- Regulile furtului, verificate pe server.

local Config = script.Parent.Parent.Config
local RaidConfig = require(Config.Raid)
local Rarities = require(Config.Rarities)

export type StealContext = {
	phase: "Day" | "Night",
	isOwnPlot: boolean,
	sameFamily: boolean?, -- membrii aceleiași familii nu-și fură între ei
	ownerPresent: boolean,
	thiefCarrying: boolean,
	thiefStunned: boolean,
	ownerShieldUntil: number,
	ownerStolenTonight: number?, -- furturi reușite de la această ogradă în noaptea curentă
	ownerPlaySeconds: number,
	ownerIsNpc: boolean,
	now: number,
	distance: number,
	creatureOnPedestal: boolean,
	creatureIsSoul: boolean?, -- creaturile de suflet nu se fură (Domain/Soul)
	inMinigame: boolean?, -- hoțul e într-un mini-joc: nu fură (Domain/Minigame)
	holiday: boolean?, -- hramul satului: casă deschisă, nu se fură
}

local Raid = {}

-- Recompensa pentru cine salvează o creatură cu papucul.
function Raid.defenseReward(sellPrice: number): number
	return math.floor(sellPrice * RaidConfig.defenseRewardShare)
end

-- Întoarce (true, nil) sau (false, motiv).
function Raid.canSteal(ctx: StealContext): (boolean, string?)
	if ctx.phase ~= "Night" then
		return false, "NotNight"
	elseif ctx.isOwnPlot then
		return false, "OwnPlot"
	elseif ctx.sameFamily then
		return false, "Family"
	elseif not ctx.ownerPresent then
		return false, "OwnerAway"
	elseif ctx.thiefCarrying then
		return false, "AlreadyCarrying"
	elseif ctx.thiefStunned then
		return false, "Stunned"
	elseif not ctx.creatureOnPedestal then
		return false, "NotDisplayed"
	elseif ctx.creatureIsSoul then
		return false, "Soul"
	elseif ctx.inMinigame then
		return false, "Busy"
	elseif ctx.holiday then
		return false, "Hram"
	elseif ctx.distance > RaidConfig.promptMaxDistance then
		return false, "TooFar"
	elseif not ctx.ownerIsNpc and ctx.now < ctx.ownerShieldUntil then
		return false, "Shielded"
	elseif (ctx.ownerStolenTonight or 0) >= RaidConfig.maxStealsPerVictimPerNight then
		return false, "NightLimit"
	elseif not ctx.ownerIsNpc and ctx.ownerPlaySeconds < RaidConfig.newPlayerProtectionSeconds then
		return false, "NewPlayer"
	end
	return true, nil
end

function Raid.carrySpeedMultiplier(rarityId: string): number
	local rarity = Rarities.byId[rarityId]
	return if rarity then rarity.carrySpeedMultiplier else 0.75
end

function Raid.holdSeconds(rarityId: string): number
	local rarity = Rarities.byId[rarityId]
	return if rarity then rarity.stealHoldSeconds else 1.5
end

-- Deplasare orizontală plauzibilă pentru viteza dată? Căderea pe verticală e permisă.
function Raid.isMovementPlausible(
	previous: Vector3,
	current: Vector3,
	dt: number,
	walkSpeed: number,
	tolerance: number
): boolean
	local horizontal = Vector3.new(current.X - previous.X, 0, current.Z - previous.Z).Magnitude
	local allowed = walkSpeed * math.max(dt, 0) * tolerance + 2
	return horizontal <= allowed
end

return Raid
