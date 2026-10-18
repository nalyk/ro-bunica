--!strict
-- Plăcintăria nebună: o plăcintă trece prin aluat, umplutură (brânză, varză sau vișine), cuptor și livrare.
-- Pașii se fac în ordine; livrarea contează doar pentru o comandă cu aceeași umplutură.

export type Pie = { stage: number, filling: string? }

local Recipe = {}

Recipe.ORDERS = { "Branza", "Varza", "Visine" }
Recipe.STEPS = { "Aluat", "Umplutura", "Cuptor", "Livrare" }

function Recipe.new(): Pie
	return { stage = 1, filling = nil }
end

function Recipe.next(pie: Pie): string
	return Recipe.STEPS[pie.stage] or "Gata"
end

-- Aplică un pas („Aluat”, „Umplutura:Varza”, „Cuptor”). Întoarce true dacă era pasul cerut.
function Recipe.apply(pie: Pie, step: string): boolean
	local expected = Recipe.next(pie)
	local kind, filling = string.match(step, "^(%a+):?(%a*)$")
	if kind ~= expected or expected == "Livrare" or expected == "Gata" then
		return false
	end
	if kind == "Umplutura" then
		if not filling or not table.find(Recipe.ORDERS, filling) then
			return false
		end
		pie.filling = filling
	end
	pie.stage += 1
	return true
end

-- Plăcinta coaptă se potrivește comenzii?
function Recipe.complete(order: string, pie: Pie): boolean
	return Recipe.next(pie) == "Livrare" and pie.filling == order
end

return Recipe
