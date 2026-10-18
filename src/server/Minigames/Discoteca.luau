--!strict
-- Concursul de la Discotecă (2–8 jucători, 60 s, în Casa de cultură). Două feluri, pe rând:
-- - dansul: 45 s de dans liber pe ring, apoi 15 s de vot;
-- - „Cea mai tare Bunică”: fiecare își îmbracă Bunica (basma, șorț, podoabă: alegeri din meniu), apoi vot.
-- La vot, fiecare dă 1–3 inimi fiecărui celuilalt concurent (fără chat, fără text liber; nu se votează singur).

local Kit = require(script.Parent.Parent.Happenings.Kit)
local Actors = require(script.Parent.Parent.Actors)
local HoraService = require(script.Parent.Parent.Services.HoraService)

local Discoteca = {}

Discoteca.VOTE_SECONDS = 15
local rounds = 0

type Choice = { name: string, color: Color3 }

local SCARVES: { Choice } = {
	{ name = "rosie", color = Color3.fromRGB(200, 40, 50) },
	{ name = "albastra", color = Color3.fromRGB(60, 100, 190) },
	{ name = "verde", color = Color3.fromRGB(60, 150, 90) },
}
local APRONS: { Choice } = {
	{ name = "inflorat", color = Color3.fromRGB(240, 200, 220) },
	{ name = "alb", color = Color3.fromRGB(245, 245, 240) },
	{ name = "galben", color = Color3.fromRGB(240, 210, 80) },
}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function names(match: any): { [string]: string }
	local list = {}
	for _, owner in match.players do
		list[tostring(owner.userId)] = owner.name
	end
	return list
end

-- Variantele de vot pentru un votant: 1–3 inimi pentru fiecare alt concurent
local function voteOptions(match: any, voter: any): { any }
	local options = {}
	for _, owner in match.players do
		if owner ~= voter and not (match.data.votes[voter] and match.data.votes[voter][owner.userId]) then
			for hearts = 3, 1, -1 do
				table.insert(options, {
					id = tostring(owner.userId) .. ":" .. hearts,
					text = "minigame.vote",
					args = { owner.name, string.rep("❤", hearts) },
					swatch = if hearts == 3 then "ie" elseif hearts == 2 then "plum" else "stone",
				})
			end
			break -- câte un concurent pe rând
		end
	end
	return options
end

local function publish(match: any)
	local extra: { [string]: any } =
		{ phase = match.data.phase, mode = match.data.mode, names = names(match), voteAt = match.data.voteAt }
	if match.data.phase == "vote" then
		-- fiecare client își vede propriile variante: le trimitem pe toate, cheie după votant
		local perVoter = {}
		for _, owner in match.players do
			perVoter[tostring(owner.userId)] = voteOptions(match, owner)
		end
		extra.chooseFor = perVoter
		extra.chooseKey = "vot" .. tostring(match.data.voteRevision)
	elseif match.data.mode == "bunica" then
		extra.chooseFor = match.data.dressOptions
		extra.chooseKey = "bunica" .. tostring(match.data.dressRevision)
	end
	match.publish(extra)
end

local function dressOptions(match: any, owner: any): { any }
	local look = match.data.looks[owner]
	local list = {}
	local stage = if not look.scarf then SCARVES elseif not look.apron then APRONS else nil
	local key = if not look.scarf then "scarf" else "apron"
	for _, entry in (stage or {}) :: { Choice } do
		table.insert(
			list,
			{ id = key .. ":" .. entry.name, text = "minigame.dress." .. key, args = { entry.name } }
		)
	end
	return list
end

local function refreshDress(match: any)
	match.data.dressRevision += 1
	local per = {}
	for _, owner in match.players do
		per[tostring(owner.userId)] = dressOptions(match, owner)
	end
	match.data.dressOptions = per
end

local function buildBunica(match: any, owner: any, index: number)
	local look = match.data.looks[owner]
	if look.model then
		look.model:Destroy()
	end
	local at = match.arena * CFrame.new((index - (#match.players + 1) / 2) * 4, 1.2, 6)
	local scarf = look.scarf and look.scarf.color or Color3.fromRGB(120, 120, 120)
	local apron = look.apron and look.apron.color or Color3.fromRGB(200, 200, 200)
	look.model =
		Kit.figure("Bunica_" .. owner.name, at * CFrame.Angles(0, math.pi, 0), apron, match.folder, scarf)
end

function Discoteca.setup(match: any)
	rounds += 1
	match.data.mode = if rounds % 2 == 1 then "dans" else "bunica"
	match.data.phase = "show"
	match.data.voteAt = match.endsAt - Discoteca.VOTE_SECONDS
	match.data.votes = {}
	match.data.voteRevision = 0
	match.data.looks = {}
	match.data.dressRevision = 0
	for i, owner in match.players do
		match.data.looks[owner] = {}
		local character = owner.actor and Actors.characterOf(owner.actor)
		if character then
			character:PivotTo(match.arena * CFrame.new((i - (#match.players + 1) / 2) * 3, 3, 0))
		end
		if match.data.mode == "bunica" then
			buildBunica(match, owner, i)
		end
	end
	if match.data.mode == "bunica" then
		refreshDress(match)
	end
	publish(match)
end

function Discoteca.phase(match: any): string
	return match.data.phase
end

function Discoteca.action(match: any, owner: any, payload: any)
	if typeof(payload) ~= "table" or typeof(payload.choice) ~= "string" then
		return
	end
	if match.data.phase == "show" and match.data.mode == "bunica" then
		local key, value = string.match(payload.choice, "^(%a+):(%a+)$")
		local list = if key == "scarf" then SCARVES elseif key == "apron" then APRONS else nil
		for _, entry in (list or {}) :: { Choice } do
			if entry.name == value and not match.data.looks[owner][key] then
				match.data.looks[owner][key] = entry
				buildBunica(match, owner, table.find(match.players, owner) or 1)
				refreshDress(match)
				publish(match)
			end
		end
		return
	end
	if match.data.phase ~= "vote" then
		return
	end
	local target, hearts = string.match(payload.choice, "^(%-?%d+):(%d)$")
	local targetId, count = tonumber(target), tonumber(hearts)
	if not targetId or not count or count < 1 or count > 3 or targetId == owner.userId then
		return
	end
	match.data.votes[owner] = match.data.votes[owner] or {}
	if match.data.votes[owner][targetId] then
		return -- un singur vot pentru fiecare concurent
	end
	for _, candidate in match.players do
		if candidate.userId == targetId then
			match.data.votes[owner][targetId] = count
			match.score(candidate, count)
			match.data.voteRevision += 1
			publish(match)
			return
		end
	end
end

function Discoteca.tick(match: any, _dt: number)
	if match.data.phase == "show" then
		if match.data.mode == "dans" then
			for _, owner in match.players do
				if owner.actor then
					HoraService.setDancing(owner.actor, 1) -- dansul pe ring (emote-ul horei, muzica)
				end
			end
		end
		if now() >= match.data.voteAt then
			match.data.phase = "vote"
			match.data.voteRevision += 1
			publish(match)
		end
	end
end

return Discoteca
