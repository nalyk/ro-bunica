--!strict
-- Păcală se ascunde (3–8 jucători, 2,5 minute, la claia de fân): ascunșii devin obiecte din ogradă (găleată,
-- oală, dovleac, butuc, claie), printre momeli de același fel. Căutătorii (unul la patru jucători) aruncă
-- papuci: în Păcală = prins; în momeală = runda se scurtează cu 4 s (bine pentru ascunși). Ascunșii pot râde
-- (acțiunea { laugh = true }): +2 puncte, dar râsul se aude și se vede o clipă.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local PropHunt = require(Shared.Domain.PropHunt)
local Kit = require(script.Parent.Parent.Happenings.Kit)
local Actors = require(script.Parent.Parent.Actors)
local PlotService = require(script.Parent.Parent.Services.PlotService)
local SlipperService = require(script.Parent.Parent.Services.SlipperService)
local Props = require(script.Parent.Props)

local Pacala = {}

local DECOYS = 14
local ARENA = 30
local rounds = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Ascunde personajul și sudează obiectul de el (vizual: piesele devin transparente)
local function disguise(match: any, owner: any, name: string)
	local character = owner.actor and Actors.characterOf(owner.actor)
	local root = Kit.root(owner)
	if not character or not root then
		return
	end
	local saved = {}
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("Decal") then
			saved[part] = part.Transparency
			part.Transparency = 1
		end
	end
	local prop = Props.make(name, CFrame.new(root.Position - Vector3.new(0, 3, 0)), match.folder)
	prop.Anchored = false
	prop.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = prop
	weld.Parent = prop
	match.data.disguised[owner] = { saved = saved, prop = prop, name = name, character = character }
end

local function reveal(match: any, owner: any)
	local entry = match.data.disguised[owner]
	if not entry then
		return
	end
	for part, transparency in entry.saved do
		if part.Parent then
			part.Transparency = transparency
		end
	end
	entry.prop:Destroy()
	SlipperService.unregisterTarget(entry.character)
	match.data.disguised[owner] = nil
end

local function publish(match: any, extra: { [string]: any }?)
	local ghosts, seekers = {}, {}
	for owner in match.ghosts do
		table.insert(ghosts, owner.userId)
	end
	for owner in match.data.seekers do
		table.insert(seekers, owner.userId)
	end
	local payload = { seekers = seekers, hideUntil = match.data.hideUntil, ghosts = ghosts }
	for k, v in (extra or {}) :: { [string]: any } do
		payload[k] = v
	end
	match.publish(payload)
end

function Pacala.setup(match: any)
	rounds += 1
	local rng = Random.new()
	match.data.seekers = {}
	match.data.disguised = {}
	match.data.laughAt = {}
	match.data.hideUntil = match.startedAt + PropHunt.HIDE_SECONDS
	local ids = {}
	for _, owner in match.players do
		table.insert(ids, owner.userId)
	end
	local count = math.max(1, #match.players // 4)
	for k = 1, count do
		local id = PropHunt.pickSeeker(ids, rounds + k - 1)
		for _, owner in match.players do
			if owner.userId == id then
				match.data.seekers[owner] = true
				Kit.slow(owner, "blindfold", 0, PropHunt.HIDE_SECONDS)
			end
		end
	end
	local center = match.arena.Position
	-- momelile: obiecte de aceleași feluri, împrăștiate prin arenă
	for _ = 1, DECOYS do
		local angle = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber(4, ARENA)
		local p = center + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
		local name = PropHunt.disguises[rng:NextInteger(1, #PropHunt.disguises)]
		local decoy = Props.make(
			name,
			CFrame.new(p.X, Kit.groundY(p.X, p.Z), p.Z) * CFrame.Angles(0, angle, 0),
			match.folder
		)
		local model = Instance.new("Model")
		model.Name = "Momeala"
		model.Parent = match.folder
		decoy.Parent = model
		model.PrimaryPart = decoy
		SlipperService.registerTarget(model, function(thrower)
			local by = thrower and PlotService.getOwnerOfActor(thrower)
			if by and match.data.seekers[by] then
				match.endsAt -= PropHunt.WRONG_HIT_SECONDS -- obiectul greșit: timpul curge în favoarea ascunșilor
				publish(match, { wrong = decoy.Position })
			end
		end, 2.5)
	end
	for _, owner in match.players do
		if not match.data.seekers[owner] then
			disguise(match, owner, PropHunt.disguises[rng:NextInteger(1, #PropHunt.disguises)])
			local entry = match.data.disguised[owner]
			if entry then
				SlipperService.registerTarget(entry.character, function(thrower)
					local by = thrower and PlotService.getOwnerOfActor(thrower)
					if
						by
						and match.data.seekers[by]
						and now() >= match.data.hideUntil
						and match.data.disguised[owner]
					then
						match.score(owner, PropHunt.hiderPoints(now() - match.data.hideUntil))
						match.score(by, PropHunt.CATCH_POINTS)
						reveal(match, owner)
						match.eliminate(owner)
						publish(match)
						if next(match.data.disguised) == nil then
							match.finish()
						end
					end
				end, 2.5)
			end
		end
	end
	publish(match)
end

function Pacala.isDisguised(match: any, owner: any): boolean
	return match.data.disguised[owner] ~= nil
end

function Pacala.action(match: any, owner: any, payload: any)
	if typeof(payload) ~= "table" or payload.laugh ~= true or not match.data.disguised[owner] then
		return
	end
	local last = match.data.laughAt[owner] or -math.huge
	if os.clock() - last < PropHunt.LAUGH_COOLDOWN then
		return
	end
	match.data.laughAt[owner] = os.clock()
	match.score(owner, PropHunt.LAUGH_POINTS)
	local root = Kit.root(owner)
	publish(match, { laugh = root and root.Position })
end

function Pacala.finish(match: any): { [number]: number }
	local seconds = math.max(0, math.min(now(), match.endsAt) - match.data.hideUntil)
	for owner in match.data.disguised do
		match.score(owner, PropHunt.hiderPoints(seconds))
	end
	for owner in table.clone(match.data.disguised) do
		reveal(match, owner)
	end
	return match.scores
end

return Pacala
