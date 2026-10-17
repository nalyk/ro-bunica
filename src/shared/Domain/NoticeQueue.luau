--!strict
-- Coada mesajelor de pe ecran: priorități, unirea mesajelor identice (×n), durată după timpul de citire.
-- Folosită de NotifyController: pe telefon un singur mesaj odată (capsula), pe desktop câte o coloană.

export type Priority = "urgent" | "reward" | "hint" | "ambient" | "quiet"
export type Notice = {
	key: string,
	text: string,
	priority: Priority,
	count: number,
	at: number, -- când a intrat în coadă
	expires: number, -- după asta nu mai merită arătat
}
export type Queue = { items: { Notice }, capacity: number }

local NoticeQueue = {}

local RANK: { [Priority]: number } = { urgent = 4, reward = 3, hint = 2, ambient = 1, quiet = 0 }
local TTL: { [Priority]: number } = { urgent = 30, reward = 20, hint = 4, ambient = 8, quiet = 4 }

function NoticeQueue.new(capacity: number?): Queue
	return { items = {}, capacity = capacity or 6 }
end

function NoticeQueue.rank(priority: Priority): number
	return RANK[priority]
end

-- Adaugă un mesaj. Un mesaj identic deja în coadă crește doar contorul. Pentru indicii și ambient rămâne
-- doar cel mai nou (cele vechi nu mai contează). Peste capacitate se pierde cel mai puțin important.
function NoticeQueue.push(queue: Queue, key: string, text: string, priority: Priority, now: number)
	for _, item in queue.items do
		if item.text == text then
			item.count += 1
			item.expires = now + TTL[priority]
			return
		end
	end
	if priority == "hint" or priority == "ambient" then
		for index = #queue.items, 1, -1 do
			if queue.items[index].priority == priority then
				table.remove(queue.items, index)
			end
		end
	end
	table.insert(
		queue.items,
		{ key = key, text = text, priority = priority, count = 1, at = now, expires = now + TTL[priority] }
	)
	while #queue.items > queue.capacity do
		local worst, worstIndex = math.huge, 1
		for index, item in queue.items do
			local score = RANK[item.priority] * 1000 + item.at / 1e6
			if score < worst then
				worst, worstIndex = score, index
			end
		end
		table.remove(queue.items, worstIndex)
	end
end

-- Scoate următorul mesaj de arătat: cel mai important, apoi cel mai vechi. `minRank` filtrează (coloane).
-- Ambientul iese doar când nu așteaptă nimic mai important.
function NoticeQueue.pop(queue: Queue, now: number, minRank: number?, maxRank: number?): Notice?
	for index = #queue.items, 1, -1 do
		if queue.items[index].expires <= now then
			table.remove(queue.items, index)
		end
	end
	local best: Notice? = nil
	local bestIndex = 0
	for index, item in queue.items do
		local rank = RANK[item.priority]
		if rank >= (minRank or 0) and rank <= (maxRank or 99) then
			if
				not best
				or rank > RANK[best.priority]
				or (rank == RANK[best.priority] and item.at < best.at)
			then
				best, bestIndex = item, index
			end
		end
	end
	if best then
		table.remove(queue.items, bestIndex)
	end
	return best
end

function NoticeQueue.waiting(queue: Queue): number
	return #queue.items
end

-- Cât stă pe ecran: timpul de citire (~20 de caractere pe secundă), mai scurt când așteaptă multe.
function NoticeQueue.duration(text: string, priority: Priority, backlog: number): number
	local seconds = 1.2 + utf8.len(text) :: number * 0.05
	if priority == "hint" or priority == "ambient" then
		seconds = math.clamp(seconds, 1.6, 2.6)
	elseif priority == "urgent" then
		seconds = math.clamp(seconds, 2.6, 4.5)
	else
		seconds = math.clamp(seconds, 1.8, 4)
	end
	if backlog >= 2 then
		seconds *= 0.7
	end
	return seconds
end

-- Un mesaj nou întrerupe mesajul de pe ecran doar dacă e urgent și cel de pe ecran nu e.
function NoticeQueue.interrupts(showing: Notice?, incoming: Priority): boolean
	return showing ~= nil and incoming == "urgent" and showing.priority ~= "urgent"
end

return NoticeQueue
