--!strict
-- Oina cu papuci (jocul vechi cu mingea, pe terenul școlii): echipa la bătaie lovește mingea și aleargă pe
-- culoar până la capăt și înapoi (1 punct); echipa la prindere aruncă papuci după alergător. Lovit = scos din
-- rundă (devine fantomă). La schimb, rolurile se inversează și cei scoși revin.

export type Team = "A" | "B"
export type State = {
	team: { [number]: Team },
	batting: Team,
	points: { A: number, B: number },
	out: { [number]: boolean },
}
export type Event = { kind: "run" | "hit", player: number, by: number? }

local Oina = {}

function Oina.new(players: { number }): State
	local team: { [number]: Team } = {}
	for i, id in players do
		team[id] = if i % 2 == 1 then "A" else "B"
	end
	return { team = team, batting = "A", points = { A = 0, B = 0 }, out = {} }
end

-- Aplică un eveniment. Întoarce true dacă a schimbat ceva.
function Oina.score(state: State, event: Event): boolean
	local team = state.team[event.player]
	if not team or team ~= state.batting or state.out[event.player] then
		return false
	end
	if event.kind == "run" then
		state.points[team] += 1
		return true
	end
	local by = event.by and state.team[event.by]
	if by and by ~= state.batting then
		state.out[event.player] = true
		return true
	end
	return false
end

function Oina.swap(state: State)
	state.batting = if state.batting == "A" then "B" else "A"
	table.clear(state.out)
end

-- Toți cei de la bătaie sunt scoși?
function Oina.allOut(state: State): boolean
	for id, team in state.team do
		if team == state.batting and not state.out[id] then
			return false
		end
	end
	return true
end

return Oina
