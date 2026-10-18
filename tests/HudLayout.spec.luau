local HudLayout = require(Shared.Domain.HudLayout)

-- Ecrane reale (puncte GUI, landscape, fără bara Roblox de sus)
local SCREENS = {
	{ name = "iPhone SE", w = 667, h = 339 },
	{ name = "iPhone 14", w = 844, h = 354 },
	{ name = "Android mic", w = 800, h = 324 },
	{ name = "Galaxy", w = 915, h = 376 },
	{ name = "Android îngust", w = 640, h = 324 },
	{ name = "tabletă", w = 1024, h = 732 },
}

local function interactive(layout: any): { any }
	local list = {}
	for _, rect in layout.actions do
		table.insert(list, rect)
	end
	for _, rect in { layout.status, layout.rage, layout.pin, layout.seeds } do
		table.insert(list, rect)
	end
	return list
end

describe("HudLayout.touch", function()
	for _, screen in SCREENS do
		it(screen.name .. ": nimic interactiv peste săritură sau în zona joystick-ului", function()
			local layout = HudLayout.touch(screen.w, screen.h, nil, 5, 4)
			for _, rect in interactive(layout) do
				expect(HudLayout.overlaps(rect, layout.jump)).toBe(false)
				expect(HudLayout.overlaps(rect, layout.thumb)).toBe(false)
			end
			expect(HudLayout.overlaps(layout.ammo, layout.jump)).toBe(false)
			-- capsula mesajelor: lată cât să se citească, sus, fără să acopere nimic din HUD
			expect(layout.notice.w >= 300).toBe(true)
			expect(HudLayout.inside(layout.notice, screen.w, screen.h)).toBe(true)
			expect(layout.notice.y + layout.notice.h <= screen.h * 0.42).toBe(true)
			local hud = {
				layout.rage,
				layout.pin,
				layout.ammo,
				layout.seeds,
				layout.jump,
				layout.status,
				layout.info,
			}
			for _, rect in layout.actions do
				table.insert(hud, rect)
			end
			for _, rect in hud do
				expect(HudLayout.overlaps(layout.notice, rect)).toBe(false)
			end
		end)
		it(screen.name .. ": totul în ecran, fără suprapuneri, butoane de minimum 44 px", function()
			local layout = HudLayout.touch(screen.w, screen.h, nil, 5, 4)
			local all = interactive(layout)
			table.insert(all, layout.ammo)
			table.insert(all, layout.info)
			for i, a in all do
				expect(HudLayout.inside(a, screen.w, screen.h)).toBe(true)
				for j = i + 1, #all do
					expect(HudLayout.overlaps(a, all[j])).toBe(false)
				end
			end
			for _, rect in { layout.rage, layout.pin, layout.actions[1] } do
				expect(math.min(rect.w, rect.h) >= HudLayout.MIN_TOUCH).toBe(true)
			end
			expect(layout.seeds.w >= 120).toBe(true)
			expect(layout.statusScale >= 0.5).toBe(true)
		end)
	end

	for _, screen in SCREENS do
		it(
			screen.name
				.. ": busola sus, între butoane și bani: lată de citit, de atins, fără suprapuneri",
			function()
				local layout = HudLayout.touch(screen.w, screen.h, nil, 5, 4)
				local compass = layout.compass
				expect(compass.w >= HudLayout.COMPASS_MIN_W).toBe(true)
				expect(compass.h >= HudLayout.MIN_TOUCH).toBe(true)
				expect(HudLayout.inside(compass, screen.w, screen.h)).toBe(true)
				local others =
					{ layout.status, layout.info, layout.notice, layout.jump, layout.thumb, layout.ammo }
				for _, rect in layout.actions do
					table.insert(others, rect)
				end
				for _, rect in others do
					expect(HudLayout.overlaps(compass, rect)).toBe(false)
				end
				expect(layout.statusScale >= 0.5).toBe(true)
			end
		)
	end

	for _, screen in SCREENS do
		it(
			screen.name .. ": tabela de scor a mini-jocurilor, sub mesaje, fără să acopere HUD-ul",
			function()
				local layout = HudLayout.touch(screen.w, screen.h, nil, 5, 4)
				local board = layout.scoreboard
				expect(board ~= nil).toBe(true)
				expect(HudLayout.inside(board, screen.w, screen.h)).toBe(true)
				expect(board.h >= 24 and board.w >= 280).toBe(true)
				expect(board.y + board.h <= screen.h * 0.5).toBe(true)
				local hud = {
					layout.rage,
					layout.pin,
					layout.ammo,
					layout.seeds,
					layout.jump,
					layout.status,
					layout.info,
					layout.notice,
				}
				for _, rect in layout.actions do
					table.insert(hud, rect)
				end
				for _, rect in hud do
					expect(HudLayout.overlaps(board, rect)).toBe(false)
				end
			end
		)
	end

	for _, screen in SCREENS do
		it(screen.name .. ": butonul mesajelor rapide, de deget, fără suprapuneri", function()
			local layout = HudLayout.touch(screen.w, screen.h, nil, 5, 4)
			local quick = layout.quick
			expect(quick ~= nil).toBe(true)
			expect(math.min(quick.w, quick.h) >= HudLayout.MIN_TOUCH).toBe(true)
			expect(HudLayout.inside(quick, screen.w, screen.h)).toBe(true)
			local others = {
				layout.rage,
				layout.pin,
				layout.ammo,
				layout.seeds,
				layout.jump,
				layout.status,
				layout.info,
				layout.notice,
				layout.scoreboard,
				layout.thumb,
			}
			for _, rect in layout.actions do
				table.insert(others, rect)
			end
			for _, rect in others do
				expect(HudLayout.overlaps(quick, rect)).toBe(false)
			end
		end)
	end

	it("folosește săritura reală când o primește", function()
		local jump = { x = 500, y = 200, w = 72, h = 72 }
		local layout = HudLayout.touch(667, 339, jump, 5, 4)
		expect(layout.jump).toBe(jump)
		expect(layout.rage.x + layout.rage.w <= jump.x).toBe(true)
	end)

	it("cutia de apărare pe desktop încape până la 5 papuci", function()
		expect(HudLayout.defenseBoxWidth(3) >= 212).toBe(true)
		-- 5 papuci de 36 cu spațiu de 6, textul „Papuci: 5/5” (60) și marginile
		expect(HudLayout.defenseBoxWidth(5) >= 20 + 5 * 42 + 60).toBe(true)
	end)
end)
