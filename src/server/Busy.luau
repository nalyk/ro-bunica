--!strict
-- Cine e prins într-un mini-joc acum (MinigameService scrie, RaidService și SlipperService citesc): nu fură,
-- iar papucul lui e al jocului (nu apără ogrăzi). Modul separat, ca să nu lege serviciile în cerc.

local Busy = {}

local busy: { [any]: string? } = {}

function Busy.set(actor: any, minigameId: string?)
	busy[actor] = minigameId
end

function Busy.get(actor: any): string?
	return busy[actor]
end

function Busy.is(actor: any): boolean
	return busy[actor] ~= nil
end

return Busy
