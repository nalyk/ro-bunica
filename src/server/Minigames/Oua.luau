--!strict
-- Ciocnitul ouălor (1 la 1, 30 s, la bucătăria de vară): fiecare își alege un ou din colecție (sau i se dă
-- cel mai slab). Ouăle se ciocnesc (Domain/EggDuel: tăria oului plus noroc); câștigătorul ia oul celuilalt.
-- Se ciocnește de trei ori; cine câștigă mai multe ciocniri câștigă jocul.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local EggDuel = require(Shared.Domain.EggDuel)
local StateService = require(script.Parent.Parent.Services.StateService)

local Oua = {}

Oua.ROUNDS = 3
local CHOOSE_SECONDS = 8

local function options(owner: any): { any }
	local list = {}
	for _, egg in EggDuel.EGGS do
		local n = owner.profile.eggs[egg] or 0
		if n > 0 then
			table.insert(list, { id = egg, text = "minigame.egg", args = { egg, tostring(n) } })
		end
	end
	return list
end

function Oua.setup(match: any)
	for _, owner in match.players do
		owner.profile.eggs = owner.profile.eggs or { Alb = 3 }
		if not EggDuel.weakest(owner.profile.eggs) then
			owner.profile.eggs.Alb = 1 -- nimeni nu rămâne fără ou de ciocnit
		end
	end
	match.data.choice = {}
	match.data.round = 0
	match.data.chooseUntil = os.clock() + CHOOSE_SECONDS
	match.data.rng = Random.new()
	match.publish({ choose = options(match.players[1]), chooseKey = "oua" })
end

function Oua.action(match: any, owner: any, payload: any)
	if
		typeof(payload) == "table"
		and typeof(payload.choice) == "string"
		and (owner.profile.eggs[payload.choice] or 0) > 0
	then
		match.data.choice[owner] = payload.choice
	end
end

local function clash(match: any)
	local a, b = match.players[1], match.players[2]
	if not a or not b then
		match.finish()
		return
	end
	local eggA = match.data.choice[a] or EggDuel.weakest(a.profile.eggs) or "Alb"
	local eggB = match.data.choice[b] or EggDuel.weakest(b.profile.eggs) or "Alb"
	local rng: Random = match.data.rng
	local winner = EggDuel.resolve(eggA, eggB, function()
		return rng:NextNumber()
	end)
	local w, l, lost =
		if winner == "A" then a else b, if winner == "A" then b else a, if winner == "A" then eggB else eggA
	match.score(w, 1)
	-- oul crăpat trece la câștigător (colecția)
	if (l.profile.eggs[lost] or 0) > 0 then
		l.profile.eggs[lost] -= 1
		w.profile.eggs[lost] = (w.profile.eggs[lost] or 0) + 1
	end
	StateService.markDirty(a.player)
	StateService.markDirty(b.player)
	match.data.round += 1
	match.data.last = { winner = w.userId, eggA = eggA, eggB = eggB }
	match.publish({ clash = match.data.last })
	if match.data.round >= Oua.ROUNDS then
		match.finish()
	else
		match.data.chooseUntil = os.clock() + 4
	end
end

function Oua.tick(match: any, _dt: number)
	local both = match.data.choice[match.players[1]] and match.data.choice[match.players[2] or {}]
	if both or os.clock() >= match.data.chooseUntil then
		clash(match)
	end
end

return Oua
