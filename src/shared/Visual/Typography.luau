--!strict
-- Fonturile jocului. Nunito: rotunjit, prietenos și (testat în Studio, 2026-10-16) cu toate literele de care
-- avem nevoie: ș ț ă î â și chirilice. FredokaOne, LuckiestGuy, DenkOne nu au „ș ț”, deci literele
-- apăreau dintr-un font de rezervă, mai subțire.

local NUNITO = "rbxasset://fonts/families/Nunito.json"

return table.freeze({
	display = Font.new(NUNITO, Enum.FontWeight.Heavy), -- titluri, cifre, butoane
	strong = Font.new(NUNITO, Enum.FontWeight.ExtraBold),
	body = Font.new(NUNITO, Enum.FontWeight.Bold), -- texte lungi, bule de dialog
})
