--!strict
-- Răzbunarea: după un furt, victima vede hoțul până în zori. Dacă își fură înapoi aceeași creatură, primește un
-- bonus (jumătate din prețul ei). Pierderea devine o urmărire, nu un doliu.

export type Mark = { victim: number, thief: number, uid: string, untilTime: number, at: number }
export type Marks = { list: { Mark }, counter: number }

local Revenge = {}

function Revenge.new(): Marks
	return { list = {}, counter = 0 }
end

function Revenge.mark(marks: Marks, victimId: number, thiefId: number, uid: string, untilTime: number)
	marks.counter += 1
	table.insert(
		marks.list,
		{ victim = victimId, thief = thiefId, uid = uid, untilTime = untilTime, at = marks.counter }
	)
end

-- Victima a furat înapoi creatura `uid`? Întoarce true o singură dată și consumă marcajul.
function Revenge.claim(marks: Marks, claimerId: number, uid: string, now: number): boolean
	for index, mark in marks.list do
		if mark.uid == uid and mark.victim == claimerId and now <= mark.untilTime then
			table.remove(marks.list, index)
			return true
		end
	end
	return false
end

-- Hoțul pe care îl urmărește victima acum (cel mai recent marcaj activ), dacă există.
function Revenge.target(marks: Marks, victimId: number, now: number): number?
	local best: Mark? = nil
	for _, mark in marks.list do
		if mark.victim == victimId and now <= mark.untilTime and (best == nil or mark.at > best.at) then
			best = mark
		end
	end
	return if best then best.thief else nil
end

function Revenge.clear(marks: Marks)
	table.clear(marks.list)
end

function Revenge.bonus(sellPrice: number): number
	return math.floor(sellPrice / 2)
end

return Revenge
