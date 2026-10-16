--!strict
-- Ce straturi muzicale cântă acum, din starea jocului. Pur și testat; dirijorul (client) doar execută.

local MusicState = {}

export type Input = {
	phase: string, -- "Day" | "Night"
	now: number,
	alarmUntil: number, -- hoț în ogradă (Alarm) până la acest moment
	chaseUntil: number, -- jucătorul a aruncat papucul / urmărește hoțul
	dancing: boolean, -- personajul propriu dansează hora
	dancers: number, -- câți dansează acum în vatră
}

export type Mix = { [string]: number } -- strat → volum țintă (0..1)

MusicState.LAYERS = { "zi", "noapte", "pericol", "urmarire" }
MusicState.HORA_TEMPOS = { 120, 132, 144, 156 }

-- Hora accelerează cu fiecare dansator în plus (ca o horă adevărată care „se încinge”)
function MusicState.horaTempo(dancers: number): number
	local tempos = MusicState.HORA_TEMPOS
	return tempos[math.clamp(dancers, 1, #tempos)]
end

function MusicState.mix(input: Input): (Mix, number?)
	if input.dancing then
		return { zi = 0, noapte = 0, pericol = 0, urmarire = 0 }, MusicState.horaTempo(input.dancers)
	end
	local night = input.phase == "Night"
	local chase = input.now < input.chaseUntil
	local danger = input.now < input.alarmUntil
	local mix = {
		zi = if night then 0 else 1,
		noapte = if night then 1 else 0,
		pericol = if danger and not chase then 0.9 else 0,
		urmarire = if chase then 0.9 else 0,
	}
	return mix, nil
end

return MusicState
