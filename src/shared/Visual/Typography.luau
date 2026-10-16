--!strict
-- Fonturile jocului. Nunito: rotunjit, prietenos și (testat în Studio, 2026-10-16) cu toate literele de care
-- avem nevoie: ș ț ă î â și chirilice. FredokaOne, LuckiestGuy, DenkOne nu au „ș ț”, deci literele
-- apăreau dintr-un font de rezervă, mai subțire.

local NUNITO = "rbxasset://fonts/families/Nunito.json"

return table.freeze({
	-- Doar Regular vine cu clientul; celelalte grosimi se descarcă. Cu Black (900) Studio sub Wine îngheța
	-- tot procesul (bisecție 2026-10-16), deci folosim Bold, testat.
	display = Font.new(NUNITO, Enum.FontWeight.Bold), -- titluri, cifre, butoane (plus contur)
	strong = Font.new(NUNITO, Enum.FontWeight.Bold),
	body = Font.new(NUNITO, Enum.FontWeight.Regular), -- texte lungi, bule de dialog
})
