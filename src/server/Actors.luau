--!strict
-- Actorii: oricine se poate mișca prin sat și poate fura sau fi lovit.
-- Un actor e fie un jucător, fie un bot de pe server (hoțul din tutorial, testele e2e).
-- Furtul, papucul și Bunica lucrează doar cu actori, deci se comportă identic pentru ambele.

local Players = game:GetService("Players")

local Rig = require(script.Parent.Ai.Rig)
local SculptedRig = require(script.Parent.Ai.SculptedRig)
local Workspace = game:GetService("Workspace")

export type Actor = {
	id: number, -- UserId pentru jucători, negativ pentru boți
	name: string,
	player: Player?,
	character: Model?, -- doar pentru boți; la jucători se citește din Player.Character
	alive: boolean,
}

local Actors = {}

local byPlayer: { [Player]: Actor } = {}
local bots: { [Actor]: boolean } = {}
local removingCallbacks: { (Actor) -> () } = {}
local botCounter = 0

function Actors.forPlayer(player: Player): Actor
	local actor = byPlayer[player]
	if not actor then
		actor =
			{ id = player.UserId, name = player.DisplayName, player = player, character = nil, alive = true }
		byPlayer[player] = actor
	end
	return actor :: Actor
end

function Actors.isBot(actor: Actor): boolean
	return actor.player == nil
end

function Actors.characterOf(actor: Actor): Model?
	if actor.player then
		return actor.player.Character
	end
	return actor.character
end

function Actors.root(actor: Actor): BasePart?
	local character = Actors.characterOf(actor)
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

function Actors.humanoid(actor: Actor): Humanoid?
	local character = Actors.characterOf(actor)
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

-- Actorul poate acționa acum? (jucător încă pe server sau bot neeliminat, cu personaj viu)
function Actors.isActive(actor: Actor): boolean
	if not actor.alive then
		return false
	end
	if actor.player and actor.player.Parent ~= Players then
		return false
	end
	local humanoid = Actors.humanoid(actor)
	return humanoid ~= nil and humanoid.Health > 0
end

function Actors.all(): { Actor }
	local list = {}
	for _, player in Players:GetPlayers() do
		table.insert(list, Actors.forPlayer(player))
	end
	for bot in bots do
		table.insert(list, bot)
	end
	return list
end

-- Creează un bot la poziția dată (`at` = rădăcina). Fizica lui e deținută de server.
-- `look`: personajul sculptat (șablonul „char.<look>”, de exemplu „Hotoman”); fără el sau fără șablon, R15 simplu.
function Actors.createBot(name: string, at: CFrame, look: string?): Actor
	botCounter += 1
	local built = look
		and SculptedRig.build("char." .. look, name, at * CFrame.new(0, -SculptedRig.ROOT_HEIGHT, 0))
	local rig: Model
	if built then
		rig = built.rig
		rig:SetAttribute("Walks", true) -- mersul procedural pe client (StrideController)
		-- creatura cărată stă deasupra creștetului (personajele sculptate sunt mai înalte decât R15)
		local box, size = rig:GetBoundingBox()
		rig:SetAttribute("CarryHeight", box.Position.Y + size.Y / 2 - built.root.Position.Y + 0.8)
	else
		local description = Instance.new("HumanoidDescription")
		rig = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
		rig.Name = name
		Rig.useMotors(rig)
		rig:PivotTo(at)
	end
	rig.Parent = Workspace
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root:SetNetworkOwner(nil)
	end
	local actor: Actor = { id = -1000 - botCounter, name = name, player = nil, character = rig, alive = true }
	bots[actor] = true
	return actor
end

-- Cât de sus deasupra rădăcinii se cară o creatură furată: `default` pentru avatare, din model la cei sculptați.
function Actors.carryHeight(actor: Actor, default: number): number
	local character = Actors.characterOf(actor)
	local height = character and character:GetAttribute("CarryHeight")
	return if type(height) == "number" then height else default
end

function Actors.removeBot(actor: Actor)
	if not bots[actor] then
		return
	end
	actor.alive = false
	for _, callback in removingCallbacks do
		local ok, err = pcall(callback :: any, actor)
		if not ok then
			warn("[Actors] callback a eșuat:", err)
		end
	end
	bots[actor] = nil
	if actor.character then
		actor.character:Destroy()
	end
end

-- Apelat când un actor dispare (jucătorul iese sau botul e eliminat).
function Actors.onRemoving(callback: (Actor) -> ())
	table.insert(removingCallbacks, callback)
end

Players.PlayerRemoving:Connect(function(player)
	local actor = byPlayer[player]
	if actor then
		actor.alive = false
		for _, callback in removingCallbacks do
			local ok, err = pcall(callback :: any, actor)
			if not ok then
				warn("[Actors] callback a eșuat:", err)
			end
		end
		byPlayer[player] = nil
	end
end)

return Actors
