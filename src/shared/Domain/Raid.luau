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
	ownerPlaySeconds: number,
	ownerIsNpc: boolean,
	now: number,
	distance: number,
	creatureOnPedestal: boolean,
}

local Raid = {}

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
	elseif ctx.distance > RaidConfig.promptMaxDistance then
		return false, "TooFar"
	elseif not ctx.ownerIsNpc and ctx.now < ctx.ownerShieldUntil then
		return false, "Shielded"
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
