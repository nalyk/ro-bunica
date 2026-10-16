--!strict
-- Tokenii vizuali ai interfeței (paleta din docs/PRESENTATION.md): hârtie de in, cerneală maro, roșu de ie,
-- grâu (monedă), viță (creștere), cer (zi), prună (noapte/rar). Fiecare culoare are o nuanță închisă
-- pentru „buza” 3D a butoanelor și una deschisă pentru lumina de sus.

local RGB = Color3.fromRGB

export type Swatch = { base: Color3, light: Color3, dark: Color3, text: Color3 }

local function swatch(base: Color3, light: Color3, dark: Color3, text: Color3): Swatch
	return table.freeze({ base = base, light = light, dark = dark, text = text })
end

local paper = RGB(255, 244, 222)
local ink = RGB(58, 34, 24)

return table.freeze({
	paper = paper,
	paperDeep = RGB(244, 226, 192),
	ink = ink,
	inkSoft = RGB(120, 84, 62),
	shadow = RGB(30, 16, 10),
	swatches = table.freeze({
		ie = swatch(RGB(215, 38, 61), RGB(242, 92, 106), RGB(140, 18, 36), paper),
		wheat = swatch(RGB(242, 179, 61), RGB(255, 214, 120), RGB(176, 112, 20), ink),
		vine = swatch(RGB(75, 174, 79), RGB(126, 212, 120), RGB(36, 110, 46), paper),
		sky = swatch(RGB(63, 167, 224), RGB(130, 205, 245), RGB(24, 100, 160), paper),
		plum = swatch(RGB(107, 63, 160), RGB(152, 112, 210), RGB(62, 30, 104), paper),
		paper = swatch(paper, RGB(255, 252, 244), RGB(214, 190, 150), ink),
		stone = swatch(RGB(150, 140, 130), RGB(190, 182, 172), RGB(95, 86, 78), paper),
	}),
	rarity = table.freeze({
		Common = RGB(170, 160, 150),
		Rare = RGB(63, 167, 224),
		Epic = RGB(152, 90, 220),
		Legendary = RGB(242, 179, 61),
		Mythic = RGB(215, 38, 61),
		Secret = RGB(30, 30, 40),
	}),
	stroke = 3, -- grosimea conturului (px), constantă pe tot UI-ul
	radius = 14,
	lip = 5, -- înălțimea „buzei” 3D a butoanelor (px)
})
