--!strict
-- Șotronul (solo, 45 s, pe uliță lângă magazin): 8 pătrate desenate cu cretă. Se aprinde o secvență (2 s),
-- apoi sari pe pătrate în aceeași ordine. Fiecare tură reușită lungește secvența cu un pas; greșeala oprește
-- runda. Scorul = ture reușite; recordul serverului apare pe avizier.

local Kit = require(script.Parent.Parent.Happenings.Kit)
local Records = require(script.Parent.Parent.Records)

local Sotron = {}

Sotron.SQUARES = 8
local SIZE = 4
local SHOW = 2 -- secundele în care se vede secvența
local CHALK = Color3.fromRGB(235, 235, 225)
local LIT = Color3.fromRGB(255, 210, 60)

local function squareAt(match: any, i: number): CFrame
	-- două coloane de câte 4, ca șotronul desenat pe asfalt, în fața locului
	local row, col = (i - 1) // 2, (i - 1) % 2
	return match.arena * CFrame.new((col - 0.5) * (SIZE + 0.6), 0, -14 - row * (SIZE + 0.6))
end

local function setLit(match: any, index: number?)
	for i, part in match.data.squares :: { BasePart } do
		part.Color = if i == index then LIT else CHALK
		part.Material = if i == index then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
end

local function nextRound(match: any)
	local rng: Random = match.data.rng
	table.insert(match.data.sequence, rng:NextInteger(1, Sotron.SQUARES))
	match.data.progress = 0
	match.data.showUntil = os.clock() + SHOW + #match.data.sequence * 0.15
	match.data.inside = nil
end

function Sotron.setup(match: any)
	match.data.rng = Random.new()
	match.data.squares = {}
	for i = 1, Sotron.SQUARES do
		local cf = squareAt(match, i)
		local p = cf.Position
		local part = Instance.new("Part")
		part.Name = "Patrat" .. i
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.Size = Vector3.new(SIZE, 0.1, SIZE)
		part.CFrame = CFrame.new(p.X, Kit.groundY(p.X, p.Z) + 0.06, p.Z) * cf.Rotation
		part.Color = CHALK
		part.Parent = match.folder
		table.insert(match.data.squares, part)
	end
	match.data.sequence = {}
	nextRound(match)
	match.publish({})
end

function Sotron.sequence(match: any): { number }
	return match.data.sequence
end

-- Pătratul pe care stă acum jucătorul (sau nil)
local function standingOn(match: any, owner: any): number?
	local root = Kit.root(owner)
	if not root then
		return nil
	end
	for i, part in match.data.squares :: { BasePart } do
		local p = part.CFrame:PointToObjectSpace(root.Position)
		if math.abs(p.X) <= SIZE / 2 and math.abs(p.Z) <= SIZE / 2 then
			return i
		end
	end
	return nil
end

function Sotron.tick(match: any, _dt: number)
	local owner = match.players[1]
	if not owner or match.data.over then
		return
	end
	local now = os.clock()
	local sequence = match.data.sequence
	if now < match.data.showUntil then
		-- arată secvența: câte un pătrat aprins pe rând
		local step = math.floor((match.data.showUntil - now) / (SHOW / #sequence))
		setLit(match, sequence[#sequence - math.clamp(step, 0, #sequence - 1)])
		return
	end
	setLit(match, nil)
	local on = standingOn(match, owner)
	if on == match.data.inside then
		return
	end
	match.data.inside = on
	if not on then
		return
	end
	local expected = sequence[match.data.progress + 1]
	if on ~= expected then
		match.data.over = true -- greșeală: runda se oprește
		match.finish()
		return
	end
	match.data.progress += 1
	if match.data.progress >= #sequence then
		match.score(owner, 1)
		match.publish({})
		nextRound(match)
	end
end

function Sotron.finish(match: any): { [number]: number }
	local owner = match.players[1]
	if owner then
		Records.submit("Sotron", owner, match.scores[owner.userId] or 0)
	end
	return match.scores
end

return Sotron
