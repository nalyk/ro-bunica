--!strict
-- Muma Pădurii iese din codru (noaptea, rar): un mini-boss comic cu 40 de vieți. Râde și aruncă cu conuri de
-- brad lente (se văd venind; cine e prins rămâne o clipă amețit). Un papuc îi ia o viață, făcălețul trei.
-- Cine îi dă ultima lovitură ia o sămânță Epic; ceilalți, podiumul după lovituri. Pleacă singură după 120 s.

local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Kit = require(script.Parent.Kit)
local PlotService = require(script.Parent.Parent.Services.PlotService)
local SlipperService = require(script.Parent.Parent.Services.SlipperService)
local StateService = require(script.Parent.Parent.Services.StateService)
local Messenger = require(script.Parent.Parent.Services.Messenger)

local MumaPadurii = {}

MumaPadurii.HEALTH = 40
local DAMAGE = { Slipper = 1, RollingPin = 3 }
local SPEED = 4
local CONE_EVERY = 3.5
local CONE_FLIGHT = 1.8 -- lent: se fuge ușor
local CONE_RADIUS = 3.5
local ROAM = 60 -- cât se îndepărtează de codru

local function healthText(ctx: any): string
	return string.format("🌲 %d / %d", ctx.data.health, MumaPadurii.HEALTH)
end

function MumaPadurii.start(ctx: any)
	local exit = ctx.site.Position
	local sites = workspace:FindFirstChild("Village") and workspace.Village:FindFirstChild("Sites")
	local marker = sites and sites:FindFirstChild("codru") and sites.codru:FindFirstChild("Iesire", true)
	if marker and marker:IsA("BasePart") then
		exit = marker.Position
	end
	local muma = Kit.figure(
		"MumaPadurii",
		CFrame.new(exit.X, Kit.groundY(exit.X, exit.Z), exit.Z),
		Color3.fromRGB(60, 90, 50),
		ctx.folder,
		Color3.fromRGB(40, 60, 30)
	)
	muma:ScaleTo(1.8)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(180, 50)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 11, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 300
	gui.Adornee = muma.PrimaryPart :: BasePart
	gui.Parent = muma
	local label = Instance.new("TextLabel")
	label.Name = "Viata"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(180, 255, 140)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	ctx.data.muma = muma
	ctx.data.label = label
	ctx.data.health = MumaPadurii.HEALTH
	ctx.data.home = exit
	ctx.data.hits = {}
	ctx.data.order = {}
	ctx.data.nextCone = os.clock() + 4
	ctx.data.goal = exit
	label.Text = healthText(ctx)
	SlipperService.registerTarget(muma, function(thrower, kind)
		if ctx.data.health <= 0 then
			return
		end
		local owner = thrower and PlotService.getOwnerOfActor(thrower)
		ctx.data.health = math.max(0, ctx.data.health - (DAMAGE[kind] or 1))
		label.Text = healthText(ctx)
		if owner then
			ctx.participate(owner)
			ctx.data.hits[owner] = (ctx.data.hits[owner] or 0) + (DAMAGE[kind] or 1)
			if not table.find(ctx.data.order, owner) then
				table.insert(ctx.data.order, owner)
			end
		end
		if ctx.data.health <= 0 then
			ctx.data.finisher = owner
			ctx.finish()
		end
	end, 4)
end

function MumaPadurii.health(ctx: any): number
	return ctx.data.health
end

local function throwCone(ctx: any, from: Vector3, to: Vector3)
	local cone = Instance.new("Part")
	cone.Name = "Con"
	cone.Size = Vector3.new(0.9, 1.4, 0.9)
	cone.Color = Color3.fromRGB(120, 80, 40)
	cone.Material = Enum.Material.Wood
	cone.Anchored = true
	cone.CanCollide = false
	cone.CanQuery = false
	cone.CanTouch = false
	cone.Position = from
	cone.Parent = ctx.folder
	local landing = Vector3.new(to.X, Kit.groundY(to.X, to.Z) + 0.6, to.Z)
	local up = TweenService:Create(
		cone,
		TweenInfo.new(CONE_FLIGHT / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Position = (from + landing) / 2 + Vector3.new(0, 14, 0),
		}
	)
	local down = TweenService:Create(
		cone,
		TweenInfo.new(CONE_FLIGHT / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			Position = landing,
		}
	)
	up.Completed:Connect(function()
		down:Play()
	end)
	down.Completed:Connect(function()
		for _, owner in ctx.owners() do
			local root = Kit.root(owner)
			if
				root
				and Vector3.new(root.Position.X - landing.X, 0, root.Position.Z - landing.Z).Magnitude
					<= CONE_RADIUS
			then
				Kit.slow(owner, "cone", 0.3, 1.5)
				if owner.player then
					Messenger.notify(owner.player, "happening.coneHit")
				end
			end
		end
		task.delay(0.6, function()
			cone:Destroy()
		end)
	end)
	up:Play()
end

function MumaPadurii.tick(ctx: any, dt: number)
	local muma: Model = ctx.data.muma
	if not muma.Parent or ctx.data.health <= 0 then
		return
	end
	local position = muma:GetPivot().Position
	local target = Kit.nearest(ctx.owners(), position, 120)
	-- se plimbă spre cel mai apropiat jucător, dar nu pleacă departe de codru
	local goal: Vector3 = ctx.data.home
	if target then
		local root = Kit.root(target)
		if root then
			local toward = root.Position - ctx.data.home
			goal = ctx.data.home + Vector3.new(toward.X, 0, toward.Z).Unit * math.min(ROAM, toward.Magnitude)
		end
	end
	local step = Vector3.new(goal.X - position.X, 0, goal.Z - position.Z)
	if step.Magnitude > 3 then
		local to = position + step.Unit * math.min(step.Magnitude, SPEED * dt)
		to = Vector3.new(to.X, Kit.groundY(to.X, to.Z), to.Z)
		Kit.glide(muma, CFrame.lookAt(to, to + step.Unit), dt)
	end
	if target and os.clock() >= ctx.data.nextCone then
		ctx.data.nextCone = os.clock() + CONE_EVERY
		local root = Kit.root(target)
		if root then
			throwCone(ctx, position + Vector3.new(0, 8, 0), root.Position)
			ctx.data.label.Text = "Hi-hi-hi! " .. healthText(ctx)
			task.delay(1.2, function()
				if ctx.data.label.Parent then
					ctx.data.label.Text = healthText(ctx)
				end
			end)
		end
	end
end

function MumaPadurii.stop(ctx: any): { [any]: number }
	SlipperService.unregisterTarget(ctx.data.muma)
	local finisher = ctx.data.finisher
	if finisher then
		local epics = {}
		for _, creature in Creatures.list do
			if creature.rarity == "Epic" then
				table.insert(epics, creature.id)
			end
		end
		if #epics > 0 then
			local seed = epics[math.random(1, #epics)]
			finisher.profile.seeds[seed] = (finisher.profile.seeds[seed] or 0) + 1
			StateService.markDirty(finisher.player)
			if finisher.player then
				Messenger.notify(
					finisher.player,
					"happening.mumaSeed",
					{ Messenger.key("creature." .. seed) }
				)
			end
			ctx.data.reward = seed
		end
	end
	return Kit.placements(ctx.data.hits, ctx.data.order)
end

return MumaPadurii
