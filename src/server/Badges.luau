--!strict
-- Insignele (create în Creator Dashboard). Id 0 = insignă încă necreată (se sare).
-- Acordarea e o singură dată pe sesiune per insignă și jucător; erorile nu ajung în joc.

local BadgeService = game:GetService("BadgeService")

local Badges = {}

Badges.IDS = {
	hatch = 4197656250134259, -- First Creature
	steal = 3574816874267202, -- Sneaky Neighbour
	defend = 789090629982362, -- PLEOSC!
	legend = 2444435420055300, -- Legend of the Village
	hora = 0, -- Hora Dancer (de creat)
	million = 0, -- First Million (de creat)
}

local LEGENDARY_OR_BETTER = { Legendary = true, Mythic = true, Secret = true }

local awarded: { [Player]: { [string]: boolean } } = {}

function Badges.award(player: Player?, key: string)
	local id = Badges.IDS[key]
	if not player or not id or id == 0 then
		return
	end
	local mine = awarded[player] or {}
	awarded[player] = mine
	if mine[key] then
		return
	end
	mine[key] = true
	task.spawn(function()
		local ok, err = pcall(function()
			if not BadgeService:UserHasBadgeAsync(player.UserId, id) then
				BadgeService:AwardBadge(player.UserId, id)
			end
		end)
		if not ok then
			mine[key] = nil -- se reîncearcă la următoarea ocazie
			warn("[Badges]", key, err)
		end
	end)
end

-- Insigna de legendar, dacă raritatea o merită
function Badges.forRarity(player: Player?, rarity: string)
	if LEGENDARY_OR_BETTER[rarity] then
		Badges.award(player, "legend")
	end
end

function Badges.forget(player: Player)
	awarded[player] = nil
end

return Badges
