--!strict
-- Ecranul pe care se așază interfața: Root (un Frame care umple ScreenGui-ul), modul (tactil sau desktop)
-- și butonul de săritură al Roblox citit din TouchGui. Geometria propriu-zisă e în Domain/HudLayout.
-- Pentru teste, `setOverride` micșorează Root la mărimea unui telefon și forțează modul tactil: HUD-ul din
-- Studio arată și se măsoară exact ca pe telefon.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local HudLayout = require(Shared.Domain.HudLayout)

export type Override = { size: Vector2, touch: boolean }

local Layout = {}

local gui: ScreenGui? = nil
local root: Frame? = nil
local override: Override? = nil
local callbacks: { () -> () } = {}
local signature = ""

function Layout.root(): Frame
	if root then
		return root
	end
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BunicaUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local frame = Instance.new("Frame")
	frame.Name = "Root"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = screenGui
	screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui, root = screenGui, frame
	return frame
end

function Layout.size(): Vector2
	return Layout.root().AbsoluteSize
end

-- Telefon sau tabletă: atingere fără mouse (un laptop cu ecran tactil și mouse rămâne pe desktop)
function Layout.isTouch(): boolean
	if override then
		return override.touch
	end
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

-- Butonul de săritură din TouchGui, în coordonatele Root (aliniate în colțul din dreapta-jos)
function Layout.jump(): HudLayout.Rect?
	if override then
		return nil
	end
	local touchGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		and (Players.LocalPlayer:FindFirstChildOfClass("PlayerGui") :: PlayerGui):FindFirstChild("TouchGui")
	local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame") :: Frame?
	local button = frame and frame:FindFirstChild("JumpButton") :: GuiObject?
	if not frame or not button or not button.Visible or button.AbsoluteSize.X <= 0 then
		return nil
	end
	local size = Layout.size()
	local relative = button.AbsolutePosition - frame.AbsolutePosition
	local fromRight = frame.AbsoluteSize.X - relative.X
	local fromBottom = frame.AbsoluteSize.Y - relative.Y
	return {
		x = size.X - fromRight,
		y = size.Y - fromBottom,
		w = button.AbsoluteSize.X,
		h = button.AbsoluteSize.Y,
	}
end

local function currentSignature(): string
	local size = Layout.size()
	local jump = Layout.jump()
	return string.format(
		"%d,%d,%s,%s",
		size.X,
		size.Y,
		tostring(Layout.isTouch()),
		if jump then string.format("%d,%d,%d", jump.x, jump.y, jump.w) else "-"
	)
end

local function check()
	local now = currentSignature()
	if now ~= signature then
		signature = now
		for _, callback in callbacks do
			task.spawn(callback)
		end
	end
end

-- Apelat la fiecare schimbare de așezare (mărimea ecranului, rotirea, modul, săritura); și imediat.
function Layout.onChanged(callback: () -> ())
	table.insert(callbacks, callback)
	task.spawn(callback)
end

-- Pentru teste: un ecran de telefon (mărime în puncte GUI) în colțul din stânga-sus; nil revine la normal.
function Layout.setOverride(value: Override?)
	override = value
	local frame = Layout.root()
	if value then
		frame.Size = UDim2.fromOffset(value.size.X, value.size.Y)
		frame.ClipsDescendants = true
	else
		frame.Size = UDim2.fromScale(1, 1)
		frame.ClipsDescendants = false
	end
	task.wait() -- AbsoluteSize se actualizează la cadrul următor
	check()
end

function Layout.override(): Override?
	return override
end

function Layout.start()
	local frame = Layout.root()
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		task.defer(check)
	end)
	-- săritura apare când personajul e gata (TouchGui) și se poate muta la rotire: o verificăm periodic
	task.spawn(function()
		while true do
			check()
			task.wait(1)
		end
	end)
	local _ = gui
end

return Layout
