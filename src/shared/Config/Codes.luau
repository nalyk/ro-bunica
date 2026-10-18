--!strict
-- Codurile tantii de la magazin (Domain/Codes): pentru lansări, actualizări și comunitate. `expires` e în
-- secunde UTC (după aceea codul nu mai merge).

local Codes = require(script.Parent.Parent.Domain.Codes)

return table.freeze({
	{ code = "BUNICA", reward = { lei = 1000 }, expires = 1811808000 }, -- 1 iunie 2027
	{ code = "SATULVIU", reward = { lei = 2500 }, expires = 1811808000 },
	{ code = "HORA", reward = { seed = "StrugurelFurios" }, expires = 1798761600 }, -- 1 ianuarie 2027
	{ code = "PAPUCUL", reward = { lei = 750 }, expires = 1798761600 },
} :: { Codes.Code })
