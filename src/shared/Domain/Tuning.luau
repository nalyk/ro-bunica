--!strict
-- Valorile de echilibru reglabile live (Roblox Configs și Experiments; TuningService): lista albă cu
-- limite, validarea și aplicarea. Două niveluri:
--   „server”: lumea comună (ziua, furtul, Bunica) — scrise direct în tabelele din Config, pe ambele părți;
--   „player”: per jucător (papucul) — citite cu `playerValue`, ca să poată fi testate A/B pe jucători.
-- O valoare greșită (tip, limite, întreg) se respinge; jocul rămâne pe valoarea din cod.

export type Spec = { path: string, min: number, max: number, int: boolean?, scope: "server" | "player" }

local Tuning = {}

Tuning.SPEC = {
	-- papucul (pe jucător: ținta experimentelor A/B)
	slipper_maxAmmo = { path = "Defense.slipper.maxAmmo", min = 1, max = 6, int = true, scope = "player" },
	slipper_regenSeconds = { path = "Defense.slipper.regenSeconds", min = 1, max = 6, scope = "player" },
	-- Bunica din ogradă
	bunica_suspicionPerSecond = {
		path = "Defense.bunicaNpc.suspicionPerSecond",
		min = 0.1,
		max = 1,
		scope = "server",
	},
	bunica_throwIntervalSeconds = {
		path = "Defense.bunicaNpc.throwIntervalSeconds",
		min = 1.5,
		max = 6,
		scope = "server",
	},
	slipper_stunSeconds = { path = "Defense.slipper.stunSeconds", min = 0.5, max = 3, scope = "server" },
	-- furtul
	raid_victimShieldSeconds = { path = "Raid.victimShieldSeconds", min = 20, max = 180, scope = "server" },
	raid_maxStealsPerVictimPerNight = {
		path = "Raid.maxStealsPerVictimPerNight",
		min = 1,
		max = 4,
		int = true,
		scope = "server",
	},
	raid_defenseRewardShare = { path = "Raid.defenseRewardShare", min = 0.2, max = 1, scope = "server" },
	raid_newPlayerProtectionSeconds = {
		path = "Raid.newPlayerProtectionSeconds",
		min = 300,
		max = 1800,
		scope = "server",
	},
	-- ziua și noaptea
	day_daySeconds = { path = "DayNight.daySeconds", min = 180, max = 480, int = true, scope = "server" },
	day_nightSeconds = { path = "DayNight.nightSeconds", min = 120, max = 300, int = true, scope = "server" },
	-- economia
	economy_offlineRate = { path = "Economy.offlineRate", min = 0.05, max = 0.3, scope = "server" },
} :: { [string]: Spec }

local function valid(spec: Spec, value: unknown): boolean
	if type(value) ~= "number" or value ~= value then
		return false
	end
	if spec.int and math.floor(value) ~= value then
		return false
	end
	return value >= spec.min and value <= spec.max
end

-- Valorile acceptate și cheile respinse (necunoscute sau în afara limitelor)
function Tuning.validate(values: { [string]: unknown }): ({ [string]: number }, { string })
	local ok: { [string]: number } = {}
	local rejected: { string } = {}
	for key, value in values do
		local spec = Tuning.SPEC[key]
		if spec and valid(spec, value) then
			ok[key] = value :: number
		else
			table.insert(rejected, key)
		end
	end
	table.sort(rejected)
	return ok, rejected
end

-- Scrie valorile de server în tabelele config (`configs.Defense`, `configs.Raid`...)
function Tuning.apply(configs: { [string]: any }, values: { [string]: number })
	for key, value in values do
		local spec = Tuning.SPEC[key]
		if spec and spec.scope == "server" and valid(spec, value) then
			local parts = string.split(spec.path, ".")
			local node = configs[parts[1]]
			for i = 2, #parts - 1 do
				node = node and node[parts[i]]
			end
			if type(node) == "table" then
				node[parts[#parts]] = value
			end
		end
	end
end

-- Valoarea pe jucător (din Configs/Experiments), sau cea din cod dacă lipsește ori e greșită
function Tuning.playerValue(values: { [string]: unknown }, key: string, default: number): number
	local spec = Tuning.SPEC[key]
	local value = values[key]
	return if spec and valid(spec, value) then value :: number else default
end

return Tuning
