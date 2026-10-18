--!strict
-- Regulile ascunselii (în porumb) și ale lui Păcală (deghizat în obiect din ogradă).

local PropHunt = {}

PropHunt.disguises = { "Galeata", "Oala", "Dovleac", "Butuc", "Claie" }
PropHunt.HIDE_SECONDS = 20 -- căutătorul stă cu ochii închiși
PropHunt.POINTS_EVERY = 10 -- ascunșii: un punct la fiecare 10 s
PropHunt.CATCH_POINTS = 3
PropHunt.LAUGH_POINTS = 2
PropHunt.LAUGH_COOLDOWN = 8
PropHunt.WRONG_HIT_SECONDS = 4 -- lovitura în obiectul greșit: runda se scurtează (bine pentru ascunși)
PropHunt.CUCU_EVERY = 8 -- fantomele (prinșii) fac „cucu” ca indiciu

function PropHunt.hiderPoints(secondsHidden: number): number
	return math.floor(secondsHidden / PropHunt.POINTS_EVERY)
end

function PropHunt.seekerPoints(caught: number): number
	return caught * PropHunt.CATCH_POINTS
end

-- Căutătorul rundei `round` (pe rând, ca să ajungă toți)
function PropHunt.pickSeeker(ids: { number }, round: number): number
	return ids[(round - 1) % #ids + 1]
end

return PropHunt
