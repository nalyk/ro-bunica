--!strict
-- Mesajele de pe ecran, printr-o coadă cu priorități (Domain/NoticeQueue, Config/Notices).
-- Pe ecran tactil e o singură capsulă, sus la centru, peste cer (HudLayout.notice):
--   - un mesaj odată; urgentul (hoțul, furtul) sare în față și întrerupe orice alt mesaj;
--   - mesajele identice se unesc („×3”), iar durata urmează timpul de citire;
--   - confirmările din panouri („quiet”) nu apar: monedele care zboară spun deja ce s-a întâmplat;
--   - capsula nu primește atingeri, deci nu încurcă jocul.
-- Pe desktop: urgentul și anunțurile sus (cel mult 2), mesajele personale jos (cel mult 3), cu aceeași coadă.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Notices = require(Shared.Config.Notices)
local NoticeQueue = require(Shared.Domain.NoticeQueue)
local HudLayout = require(Shared.Domain.HudLayout)
local ClientState = require(script.Parent.ClientState)
local Layout = require(script.Parent.Layout)
local Motion = require(script.Parent.Motion)
local Music = require(script.Parent.Music)
local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)

local NotifyController = {}

type Priority = NoticeQueue.Priority
type Shown = { notice: NoticeQueue.Notice, item: Frame, badge: TextLabel, ends: number }
type Surface = {
	name: string,
	container: Frame,
	queue: NoticeQueue.Queue,
	slots: number,
	showing: { Shown },
	textSize: number,
	maxWidth: number,
}

local SWATCH: { [Priority]: string } = {
	urgent = "ie",
	reward = "paper",
	hint = "paper",
	ambient = "sky",
	quiet = "paper",
}
local ICON: { [string]: string } = { ["notify.Alarm"] = "alarm", ["notify.NpcThiefComing"] = "alarm" }

local surfaces: { [string]: Surface } = {}
local touch = false
local order = 0

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function newSurface(name: string, slots: number, bottom: boolean): Surface
	local container = Instance.new("Frame")
	container.Name = "Notices_" .. name
	container.BackgroundTransparency = 1
	container.Active = false
	container.Parent = UI.screen()
	local layout = UI.list(container, Enum.FillDirection.Vertical, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = if bottom then Enum.VerticalAlignment.Bottom else Enum.VerticalAlignment.Top
	local surface: Surface = {
		name = name,
		container = container,
		queue = NoticeQueue.new(),
		slots = slots,
		showing = {},
		textSize = 20,
		maxWidth = 520,
	}
	surfaces[name] = surface
	return surface
end

-- Pastila unui mesaj: lățimea după text (până la `maxWidth`), text de mărime fixă rupt pe rânduri,
-- iconiță opțională și insigna „×n” pentru mesajele unite.
local function build(surface: Surface, notice: NoticeQueue.Notice): (Frame, TextLabel)
	local swatch = Theme.swatches[SWATCH[notice.priority]]
	local item = Instance.new("Frame")
	item.Name = "Notice"
	item.Active = false
	item.AutomaticSize = Enum.AutomaticSize.XY
	item.Size = UDim2.fromOffset(0, 0)
	item.BackgroundColor3 = swatch.base
	item.BackgroundTransparency = if notice.priority == "ambient" then 0.12 else 0
	item.Parent = surface.container
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, math.floor(surface.textSize * 0.9))
	corner.Parent = item
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.ink
	stroke.Thickness = if touch then 2 else Theme.stroke
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = item
	local padding = Instance.new("UIPadding")
	local vertical = math.floor(surface.textSize * 0.35)
	padding.PaddingTop = UDim.new(0, vertical)
	padding.PaddingBottom = UDim.new(0, vertical)
	padding.PaddingLeft = UDim.new(0, math.floor(surface.textSize * 0.8))
	padding.PaddingRight = UDim.new(0, math.floor(surface.textSize * 0.8))
	padding.Parent = item
	local row = UI.list(item, Enum.FillDirection.Horizontal, math.floor(surface.textSize * 0.4))
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	local iconName = ICON[notice.key]
	local icon = iconName
		and UI.icon(iconName, {
			Size = UDim2.fromOffset(surface.textSize * 1.5, surface.textSize * 1.5),
			LayoutOrder = 1,
		})
	if icon then
		icon.Parent = item
	end
	local label = UI.label({
		Name = "Text",
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Text = notice.text,
		TextScaled = false,
		TextSize = surface.textSize,
		TextWrapped = true,
		TextColor3 = swatch.text,
		LayoutOrder = 2,
		Parent = item,
	})
	local limit = Instance.new("UISizeConstraint")
	local reserved = (if icon then surface.textSize * 2 else 0) + surface.textSize * 3
	limit.MaxSize = Vector2.new(math.max(surface.maxWidth - reserved, 80), math.huge)
	limit.Parent = label
	if swatch.text == Theme.paper then
		local textStroke = Instance.new("UIStroke")
		textStroke.Color = swatch.dark
		textStroke.Thickness = 1.5
		textStroke.Parent = label
	end
	local badge = UI.label({
		Name = "Count",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, surface.textSize),
		Text = "",
		TextScaled = false,
		TextSize = math.floor(surface.textSize * 0.85),
		TextColor3 = swatch.text,
		Visible = false,
		LayoutOrder = 3,
		Parent = item,
	})
	return item, badge
end

local function setCount(shown: Shown)
	shown.badge.Text = "×" .. shown.notice.count
	shown.badge.Visible = shown.notice.count > 1
end

local function dismiss(surface: Surface, shown: Shown)
	local index = table.find(surface.showing, shown)
	if index then
		table.remove(surface.showing, index)
	end
	local item = shown.item
	Motion.scale(item, 0.85, Motion.presets.snappy)
	task.delay(0.12, function()
		item:Destroy()
	end)
end

local function show(surface: Surface, notice: NoticeQueue.Notice)
	local item, badge = build(surface, notice)
	local shown: Shown = {
		notice = notice,
		item = item,
		badge = badge,
		ends = now() + NoticeQueue.duration(notice.text, notice.priority, NoticeQueue.waiting(surface.queue)),
	}
	setCount(shown)
	table.insert(surface.showing, shown)
	order += 1
	item.LayoutOrder = order -- ordinea în coloană urmează sosirea
	Motion.pop(item)
end

local function step()
	local t = now()
	for _, surface in surfaces do
		for index = #surface.showing, 1, -1 do
			local shown = surface.showing[index]
			if t >= shown.ends then
				dismiss(surface, shown)
			end
		end
		while #surface.showing < surface.slots do
			local notice = NoticeQueue.pop(surface.queue, t)
			if not notice then
				break
			end
			show(surface, notice)
		end
	end
end

-- Unde merge un mesaj de prioritatea dată (nil = nu se arată)
local function route(priority: Priority): Surface?
	if touch then
		return if priority == "quiet" then nil else surfaces.capsule
	end
	return if priority == "urgent" or priority == "ambient" then surfaces.top else surfaces.bottom
end

-- Pune un mesaj în coadă. Unul identic deja pe ecran crește contorul și stă puțin mai mult.
function NotifyController.notice(key: string, text: string, priority: Priority?)
	local level: Priority = priority or Notices.priority(key)
	local surface = route(level)
	if not surface then
		return
	end
	local t = now()
	for _, shown in surface.showing do
		if shown.notice.text == text then
			shown.notice.count += 1
			shown.ends = math.min(shown.ends + 1.2, t + 4)
			setCount(shown)
			Motion.pop(shown.item)
			return
		end
	end
	NoticeQueue.push(surface.queue, key, text, level, t)
	-- urgentul nu așteaptă: dacă toate locurile sunt ocupate, cel mai vechi mesaj neurgent pleacă acum
	if #surface.showing >= surface.slots and level == "urgent" then
		for _, shown in surface.showing do
			if NoticeQueue.interrupts(shown.notice, level) then
				dismiss(surface, shown)
				break
			end
		end
	end
	step()
end

-- Pentru panouri (schimbul): un mesaj deja tradus
function NotifyController.toast(text: string, priority: Priority?)
	NotifyController.notice("toast:" .. text, text, priority or "reward")
end

-- Pentru playtest: ce e pe ecran și ce așteaptă, pe fiecare suprafață
function NotifyController.debugState(): { [string]: any }
	local result = {}
	for name, surface in surfaces do
		local texts = {}
		local rects = {}
		for _, shown in surface.showing do
			table.insert(
				texts,
				shown.notice.text .. (if shown.notice.count > 1 then " ×" .. shown.notice.count else "")
			)
			local origin = UI.screen().AbsolutePosition
			local at = shown.item.AbsolutePosition - origin
			table.insert(
				rects,
				{ x = at.X, y = at.Y, w = shown.item.AbsoluteSize.X, h = shown.item.AbsoluteSize.Y }
			)
		end
		result[name] = {
			showing = texts,
			rects = rects,
			waiting = NoticeQueue.waiting(surface.queue),
			visible = surface.container.Visible,
		}
	end
	return result
end

local function applyLayout()
	local size = Layout.size()
	touch = Layout.isTouch()
	local capsule, top, bottom = surfaces.capsule, surfaces.top, surfaces.bottom
	capsule.container.Visible = touch
	top.container.Visible = not touch
	bottom.container.Visible = not touch
	if touch then
		local layout =
			HudLayout.touch(size.X, size.Y, Layout.jump(), HudLayout.TOUCH_ACTIONS, HudLayout.MENU_ITEMS)
		local rect = layout.notice
		capsule.container.Position = UDim2.fromOffset(rect.x, rect.y)
		capsule.container.Size = UDim2.fromOffset(rect.w, rect.h)
		capsule.textSize = if layout.compact then 15 else 18
		capsule.maxWidth = rect.w
	else
		top.container.AnchorPoint = Vector2.new(0.5, 0)
		top.container.Position = UDim2.new(0.5, 0, 0, 182)
		top.container.Size = UDim2.fromOffset(560, 140)
		bottom.container.AnchorPoint = Vector2.new(0.5, 1)
		bottom.container.Position = UDim2.new(0.5, 0, 1, -70)
		bottom.container.Size = UDim2.fromOffset(520, 220)
	end
	-- la schimbarea modului (rotire, test), suprafețele ascunse se golesc
	for _, surface in surfaces do
		if not surface.container.Visible then
			for index = #surface.showing, 1, -1 do
				dismiss(surface, surface.showing[index])
			end
			table.clear(surface.queue.items)
		end
	end
end

function NotifyController.start()
	newSurface("capsule", 1, false)
	newSurface("top", 2, false)
	newSurface("bottom", 3, true)
	Layout.onChanged(applyLayout)

	Net.get("Notify").OnClientEvent:Connect(function(key, args)
		NotifyController.notice(key, ClientState.t(key, args))
	end)
	Net.get("Announce").OnClientEvent:Connect(function(key, args)
		NotifyController.notice(key, ClientState.t(key, args))
	end)
	Net.get("Alarm").OnClientEvent:Connect(function()
		Music.alarm(25)
		Music.cue("alarm")
		NotifyController.notice("notify.Alarm", ClientState.t("notify.Alarm"), "urgent")
	end)
	task.spawn(function()
		while true do
			step()
			task.wait(0.1)
		end
	end)
end

return NotifyController
