--!strict
-- Geometria HUD-ului pe ecranele tactile (telefon, tabletă), calculată pur din mărimea ecranului și din
-- butonul de săritură al Roblox. Regulile (testate pe mai multe ecrane): nimic interactiv în zona
-- joystick-ului sau peste săritură, totul în ecran, fără suprapuneri, butoane de cel puțin 44 px.
-- Zonele Roblox vin din PlayerModule: DynamicThumbstick (stânga 40%, cele 2/3 de jos) și TouchJump.

export type Rect = { x: number, y: number, w: number, h: number }

export type TouchLayout = {
	compact: boolean,
	actions: { Rect }, -- rândul de butoane sus-stânga (ultimul e „Mai mult”)
	status: Rect, -- banii și ziua, sus-dreapta
	statusScale: number,
	info: Rect, -- vremea și evenimentul, sub stare
	jump: Rect,
	thumb: Rect,
	rage: Rect,
	pin: Rect,
	ammo: Rect, -- papucii și nervii, deasupra săriturii
	seeds: Rect, -- bara de semințe, banda liberă de jos
	toasts: Rect, -- notificările personale, deasupra benzii de semințe
	banners: Rect, -- anunțurile pentru tot serverul, sus la centru
	menu: Rect, -- meniul „Mai mult”, sub butonul lui
}

local HudLayout = {}

HudLayout.MIN_TOUCH = 44
HudLayout.TOUCH_ACTIONS = 5 -- Semințe, Beci, Ograda, Caietul, Mai mult
HudLayout.MENU_ITEMS = 3 -- Horă, Prieteni, Magazin
HudLayout.STATUS_SIZE = { w = 436, h = 64 } -- grupul banilor și al zilei la scara 1 (desktop)
local MARGIN = 8

-- Ecran mic, ca în PlayerModule: latura mică ≤ 500
function HudLayout.compact(w: number, h: number): boolean
	return math.min(w, h) <= 500
end

-- Butonul de săritură implicit (TouchJump), dacă nu-l putem citi din TouchGui
function HudLayout.defaultJump(w: number, h: number): Rect
	if HudLayout.compact(w, h) then
		return { x = w - 95, y = h - 90, w = 70, h = 70 }
	end
	return { x = w - 170, y = h - 210, w = 120, h = 120 }
end

-- Zona joystick-ului dinamic: unde începe o atingere de mers
function HudLayout.thumbZone(w: number, h: number): Rect
	if w < h then
		return { x = 0, y = h * 0.6, w = w, h = h * 0.4 }
	end
	return { x = 0, y = h / 3, w = w * 0.4, h = h * 2 / 3 }
end

function HudLayout.overlaps(a: Rect, b: Rect): boolean
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

function HudLayout.inside(a: Rect, w: number, h: number): boolean
	return a.x >= 0 and a.y >= 0 and a.x + a.w <= w and a.y + a.h <= h
end

function HudLayout.touch(
	w: number,
	h: number,
	jump: Rect?,
	actionCount: number,
	menuItems: number
): TouchLayout
	local compact = HudLayout.compact(w, h)
	local button = if compact then 46 else 60
	local gap = if compact then 6 else 8
	local actions = {}
	for index = 1, actionCount do
		table.insert(actions, { x = MARGIN + (index - 1) * (button + gap), y = 6, w = button, h = button })
	end
	local actionsRight = MARGIN + actionCount * (button + gap) - gap

	-- starea: scara dorită, micșorată dacă n-ar încăpea lângă rând
	local scale = if compact then 0.62 else 0.8
	local available = w - MARGIN - actionsRight - 2 * gap
	scale = math.min(scale, available / HudLayout.STATUS_SIZE.w)
	local statusW = HudLayout.STATUS_SIZE.w * scale
	local statusH = HudLayout.STATUS_SIZE.h * scale
	local status = { x = w - MARGIN - statusW, y = 6, w = statusW, h = statusH }
	local info = { x = status.x, y = status.y + statusH + 4, w = statusW, h = if compact then 20 else 26 }

	local jumpRect = jump or HudLayout.defaultJump(w, h)
	local thumb = HudLayout.thumbZone(w, h)
	local rageSize = if compact then 56 else 72
	local pinSize = if compact then 50 else 64
	local clusterGap = if compact then 12 else 14
	local centerY = jumpRect.y + jumpRect.h / 2
	local rage =
		{ x = jumpRect.x - clusterGap - rageSize, y = centerY - rageSize / 2, w = rageSize, h = rageSize }
	local pin = { x = rage.x - clusterGap - pinSize, y = centerY - pinSize / 2, w = pinSize, h = pinSize }
	local ammoH = if compact then 54 else 64
	local top = math.min(rage.y, pin.y, jumpRect.y)
	local ammo = { x = pin.x, y = top - clusterGap - ammoH, w = jumpRect.x + jumpRect.w - pin.x, h = ammoH }

	-- semințele: banda dintre joystick și apărare; dacă e prea îngustă, sub rândul de sus
	local seedH = if compact then 44 else 52
	local bandLeft = thumb.x + thumb.w + clusterGap
	local seeds = { x = bandLeft, y = h - MARGIN - seedH, w = pin.x - clusterGap - bandLeft, h = seedH }
	if seeds.w < 120 then
		seeds = { x = MARGIN, y = 6 + button + gap, w = status.x - gap - MARGIN, h = seedH }
	end
	-- notificările nu primesc atingeri: pot sta și peste zona joystick-ului, dar nu peste apărare
	local toastLeft = math.min(w * 0.22, bandLeft)
	local toasts = { x = toastLeft, y = h / 3, w = pin.x - clusterGap - toastLeft, h = 0 }
	toasts.h = math.min(seeds.y, ammo.y + ammo.h) - 8 - toasts.y

	local bannerTop = math.max(actions[1].y + button, info.y + info.h) + gap
	local banners =
		{ x = MARGIN, y = bannerTop, w = w - 2 * MARGIN, h = math.min(120, ammo.y - gap - bannerTop) }

	local more = actions[#actions]
	local menu = { x = more.x, y = more.y + more.h + gap, w = 210, h = menuItems * (button + gap) + gap }

	return {
		compact = compact,
		actions = actions,
		status = status,
		statusScale = scale,
		info = info,
		jump = jumpRect,
		thumb = thumb,
		rage = rage,
		pin = pin,
		ammo = ammo,
		seeds = seeds,
		toasts = toasts,
		banners = banners,
		menu = menu,
	}
end

-- Lățimea cutiei de apărare pe desktop: încape rândul de papuci (+ textul „Papuci: n/n”)
function HudLayout.defenseBoxWidth(maxAmmo: number): number
	local slipper = if maxAmmo > 3 then 36 else 44
	return math.max(212, 20 + maxAmmo * (slipper + 6) + 60)
end

return HudLayout
