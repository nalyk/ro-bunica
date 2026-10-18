--!strict
-- Zdrobitul strugurilor (2–4 jucători, 60 s, la vie): fiecare stă în linul lui și apasă pe ritm (acțiunea
-- { press = timpul serverului văzut de client }). Pista de bătăi e aceeași pentru toți (Domain/Rhythm, seed
-- publicat); Perfect = 3, Bun = 1. Mustul din lin crește cu punctele.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rhythm = require(Shared.Domain.Rhythm)
local Kit = require(script.Parent.Parent.Happenings.Kit)
local Actors = require(script.Parent.Parent.Actors)

local Struguri = {}

Struguri.BPM = 110
local LATENCY = 0.35 -- cât poate întârzia o apăsare pe drum (peste: se ia momentul sosirii)

local function now(): number
	return workspace:GetServerTimeNow()
end

function Struguri.setup(match: any)
	local seed = math.random(1, 1000000)
	local duration = match.endsAt - match.startedAt
	match.data.seed = seed
	match.data.beats = Rhythm.track(seed, Struguri.BPM, duration)
	match.data.used = {} -- [owner] = { [beatIndex] = true }
	match.data.vats = {}
	for i, owner in match.players do
		local at = match.arena * CFrame.new((i - (#match.players + 1) / 2) * 7, 0, -10)
		local p = at.Position
		local base = Vector3.new(p.X, Kit.groundY(p.X, p.Z), p.Z)
		local vat = Instance.new("Part")
		vat.Name = "Lin" .. i
		vat.Shape = Enum.PartType.Cylinder
		vat.Size = Vector3.new(2.4, 5.4, 5.4)
		vat.CFrame = CFrame.new(base + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		vat.Color = Color3.fromRGB(120, 84, 52)
		vat.Material = Enum.Material.Wood
		vat.Anchored = true
		vat.CanCollide = false
		vat.Parent = match.folder
		local must = vat:Clone()
		must.Name = "Must" .. i
		must.Size = Vector3.new(0.2, 5, 5)
		must.CFrame = CFrame.new(base + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		must.Color = Color3.fromRGB(110, 30, 70)
		must.Material = Enum.Material.SmoothPlastic
		must.Parent = match.folder
		match.data.vats[owner] = { must = must, base = base }
		match.data.used[owner] = {}
		local character = owner.actor and Actors.characterOf(owner.actor)
		if character then
			character:PivotTo(CFrame.new(base + Vector3.new(0, 3.5, 0)))
		end
	end
	match.publish({ rhythm = { seed = seed, bpm = Struguri.BPM, startsAt = match.startedAt } })
end

function Struguri.beats(match: any): { number }
	return match.data.beats
end

function Struguri.action(match: any, owner: any, payload: any)
	if typeof(payload) ~= "table" or typeof(payload.press) ~= "number" or not match.data.used[owner] then
		return
	end
	local arrived = now() - match.startedAt
	-- clientul spune când a apăsat; nu-l credem mai mult decât permite drumul
	local pressed = math.clamp(payload.press - match.startedAt, arrived - LATENCY, arrived)
	local index = Rhythm.nearest(match.data.beats, pressed)
	if match.data.used[owner][index] then
		return -- o bătaie se ia o singură dată
	end
	local judgement = Rhythm.judge(match.data.beats[index], pressed)
	local points = Rhythm.points(judgement)
	if points > 0 then
		match.data.used[owner][index] = true
		match.score(owner, points)
		local vat = match.data.vats[owner]
		local level = math.min(1, (match.scores[owner.userId] or 0) / 120)
		vat.must.CFrame = CFrame.new(vat.base + Vector3.new(0, 0.5 + level * 1.6, 0))
			* CFrame.Angles(0, 0, math.pi / 2)
	end
end

return Struguri
