--!strict
-- Lupii la stână (co-op contra serverului): câți vin, când fug oile, cum se împarte răsplata.

local Wolves = {}

Wolves.HITS_TO_SCARE = 2 -- două papuce gonesc un lup
Wolves.FAIL_AT = 3 -- atâția lupi în țarc: oile fug
Wolves.POOL = 300 -- lei de împărțit la apărători, dacă oile rămân
Wolves.MIN_SHARE = 0.1 -- fiecare participant ia măcar o zecime din partea egală

function Wolves.count(players: number): number
	return if players <= 1 then 3 else 6
end

function Wolves.failed(inPen: number): boolean
	return inPen >= Wolves.FAIL_AT
end

-- Împarte `pool` după lovituri; cine a participat fără lovituri ia o parte mică (MIN_SHARE din partea egală)
function Wolves.split<K>(hits: { [K]: number }, pool: number): { [K]: number }
	local people, total = 0, 0
	for _, h in hits do
		people += 1
		total += h
	end
	local shares: { [K]: number } = {}
	if people == 0 then
		return shares
	end
	local floor = pool / people * Wolves.MIN_SHARE
	local rest = pool - floor * people
	for who, h in hits do
		local part = if total > 0 then rest * h / total else rest / people
		shares[who] = math.floor(floor + part)
	end
	return shares
end

return Wolves
