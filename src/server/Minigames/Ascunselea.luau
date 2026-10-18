--!strict
-- De-a v-ați ascunselea în porumb (3–8 jucători, 2 minute, în lanul cu labirint): unul e „Bunica legată la
-- ochi” (pe client vede doar puțin în față). Ceilalți au 20 s să se ascundă în labirint. Bunica atinge = prinde.
-- Ascunșii iau un punct la fiecare 10 s nedescoperiți; prinșii devin fantome care fac „cucu” lângă unul încă
-- ascuns (un indiciu glumeț).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local PropHunt = require(Shared.Domain.PropHunt)
local Kit = require(script.Parent.Parent.Happenings.Kit)
local Actors = require(script.Parent.Parent.Actors)

local Ascunselea = {}

local CATCH = 3.5
local rounds = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

local function publish(match: any, extra: { [string]: any }?)
	local ghosts = {}
	for owner in match.ghosts do
		table.insert(ghosts, owner.userId)
	end
	local payload = { seeker = match.data.seeker.userId, hideUntil = match.data.hideUntil, ghosts = ghosts }
	for k, v in (extra or {}) :: { [string]: any } do
		payload[k] = v
	end
	match.publish(payload)
end

function Ascunselea.setup(match: any)
	rounds += 1
	local ids = {}
	for _, owner in match.players do
		table.insert(ids, owner.userId)
	end
	local seekerId = PropHunt.pickSeeker(ids, rounds)
	for _, owner in match.players do
		if owner.userId == seekerId then
			match.data.seeker = owner
		end
	end
	match.data.hideUntil = match.startedAt + PropHunt.HIDE_SECONDS
	match.data.nextCucu = match.data.hideUntil + PropHunt.CUCU_EVERY
	-- Bunica stă la intrare cu ochii închiși cât se ascund ceilalți
	local sites = workspace:FindFirstChild("Village") and workspace.Village:FindFirstChild("Sites")
	local lan = sites and sites:FindFirstChild("lanPorumb")
	local entrance = lan and lan:FindFirstChild("Intrare", true)
	local character = match.data.seeker.actor and Actors.characterOf(match.data.seeker.actor)
	if entrance and entrance:IsA("BasePart") and character then
		character:PivotTo(CFrame.new(entrance.Position + Vector3.new(0, 3, -6)))
	end
	Kit.slow(match.data.seeker, "blindfold", 0, PropHunt.HIDE_SECONDS + 3)
	publish(match)
end

function Ascunselea.seeker(match: any): any
	return match.data.seeker
end

function Ascunselea.tick(match: any, _dt: number)
	local t = now()
	if t < match.data.hideUntil then
		return
	end
	local seeker = match.data.seeker
	local seekerRoot = Kit.root(seeker)
	if not seekerRoot then
		return
	end
	local hidden = {}
	for _, owner in match.players do
		if owner ~= seeker and not match.isGhost(owner) then
			local root = Kit.root(owner)
			if root then
				if (root.Position - seekerRoot.Position).Magnitude <= CATCH then
					match.score(owner, PropHunt.hiderPoints(t - match.data.hideUntil))
					match.score(seeker, PropHunt.CATCH_POINTS)
					match.eliminate(owner)
					publish(match)
				else
					table.insert(hidden, root.Position)
				end
			end
		end
	end
	if #hidden == 0 then
		match.finish()
		return
	end
	-- „cucu”: o fantomă strigă lângă unul încă ascuns
	if next(match.ghosts) ~= nil and t >= match.data.nextCucu then
		match.data.nextCucu = t + PropHunt.CUCU_EVERY
		local target = hidden[math.random(1, #hidden)]
		publish(match, { cucu = target + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6)) })
	end
end

function Ascunselea.finish(match: any): { [number]: number }
	local seconds = math.max(0, math.min(now(), match.endsAt) - match.data.hideUntil)
	for _, owner in match.players do
		if owner ~= match.data.seeker and not match.isGhost(owner) then
			match.score(owner, PropHunt.hiderPoints(seconds))
		end
	end
	return match.scores
end

return Ascunselea
