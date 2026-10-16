--!strict
-- GENERAT de tools/loading.py upload — imaginile ecranului de încărcare (art/ui/loading).
-- Stă în ReplicatedFirst: rulează înainte ca restul jocului să existe pe client.

return {
	bg = { image = "rbxassetid://103474259719328", size = Vector2.new(1024, 576) },
	logo_en = { image = "rbxassetid://86390713523626", size = Vector2.new(1024, 450) },
	logo_ro = { image = "rbxassetid://92700095246639", size = Vector2.new(1024, 450) },
	bunica = { image = "rbxassetid://94262410637998", size = Vector2.new(655, 1024) },
	hotoman = { image = "rbxassetid://91438061616868", size = Vector2.new(630, 1024) },
	stitch = { image = "rbxassetid://77134673235801", size = Vector2.new(512, 120) },
	slipper = { image = "rbxassetid://113988371370098", size = Vector2.new(232, 232) },
	audio = "rbxassetid://94705666578776",
	regions = {
		["music.zi"] = { start = 0.0, length = 16.0 },
		["sfx.whoosh"] = { start = 124.9365, length = 0.45 },
		["sfx.pleosc"] = { start = 122.9865, length = 1.6 },
		["sfx.open"] = { start = 132.9565, length = 1.0 },
		["sfx.reward1"] = { start = 135.6565, length = 3.0 },
	},
}
