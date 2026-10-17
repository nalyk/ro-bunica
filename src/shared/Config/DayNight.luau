--!strict
-- Ciclul zi/noapte. Furturile sunt permise doar noaptea.

return table.freeze({
	daySeconds = 240, -- 4 min: furtul e deschis 43% din timp (era 33% la 6 min)
	nightSeconds = 180,
	transitionSeconds = 3, -- momentul vizual de trecere
})
