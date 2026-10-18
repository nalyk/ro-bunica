--!strict
-- Mesajele rapide (fără chat liber, pentru toți copiii, inclusiv cei sub 9 ani care n-au chat): 12 fraze,
-- fiecare cu un emoji. Textul e în Strings („quick.<id>”), în toate cele 5 limbi.

export type Message = { id: string, emoji: string }

return table.freeze({
	list = {
		{ id = "hora", emoji = "💃" },
		{ id = "help", emoji = "🆘" },
		{ id = "run", emoji = "🏃" },
		{ id = "bravo", emoji = "👏" },
		{ id = "thief", emoji = "🦹" },
		{ id = "trade", emoji = "🔁" },
		{ id = "fishing", emoji = "🎣" },
		{ id = "thanks", emoji = "🙏" },
		{ id = "haha", emoji = "😂" },
		{ id = "coming", emoji = "👟" },
		{ id = "tomorrow", emoji = "👋" },
		{ id = "bunica", emoji = "👵" },
	} :: { Message },
	cooldown = 2, -- secunde între două mesaje
	bubbleSeconds = 4,
})
