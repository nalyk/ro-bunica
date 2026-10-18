--!strict
-- Recomandările (Friend Referral): cine aduce un prieten nou în sat primește titlul „Gazda satului”,
-- cel adus „Musafirul”. Doar cosmetic (VISION, liniile roșii). Legătura se face o singură dată, la un
-- jucător nou; recompensa vine după 10 minute de joc ale celui nou, ca să nu se poată fabrica.

local Referral = {}

Referral.NEW_PLAYER_SECONDS = 120 -- legătura se face doar în primele minute ale contului în joc
Referral.REWARD_SECONDS = 600
Referral.MAX_REWARDS = 50

type ProfileLike = { playSeconds: number, referredBy: number?, referralRewarded: boolean? }

function Referral.canLink(profile: ProfileLike, referrer: number?, joiner: number): boolean
	return referrer ~= nil
		and referrer ~= joiner
		and profile.referredBy == nil
		and profile.playSeconds <= Referral.NEW_PLAYER_SECONDS
end

function Referral.due(profile: ProfileLike): boolean
	return profile.referredBy ~= nil
		and profile.referralRewarded ~= true
		and profile.playSeconds >= Referral.REWARD_SECONDS
end

-- Câte recompense în așteptare se pot lua acum, cu plafonul total
function Referral.claim(already: number, pending: number): number
	return math.max(0, math.min(pending, Referral.MAX_REWARDS - already))
end

return Referral
