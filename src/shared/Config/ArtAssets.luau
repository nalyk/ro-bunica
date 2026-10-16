--!strict
-- GENERAT de tools/art.py — nu edita de mână.
-- Modelele din art/: asset-ul încărcat, culorile sloturilor (MeshPart-uri numite după slot),
-- conturul („ink”) și mărimea. Lipsa unei chei = jocul folosește forma procedurală.

export type Art = { assetId: number, palette: { [string]: Color3 }, ink: Color3?, size: Vector3 }

return table.freeze({
	["creature.CartofelAgent"] = {
		assetId = 101455736790877,
		palette = {},
		ink = nil,
		size = Vector3.new(3.597, 4.0, 2.373),
	},
	["creature.ArdeiasIute"] = {
		assetId = 91778905031014,
		palette = {},
		ink = nil,
		size = Vector3.new(2.052, 4.0, 3.023),
	},
	["creature.CovrigSkater"] = {
		assetId = 86820505541891,
		palette = {},
		ink = nil,
		size = Vector3.new(3.551, 4.0, 2.17),
	},
	["creature.GogoasaNinja"] = {
		assetId = 109720620070039,
		palette = {},
		ink = nil,
		size = Vector3.new(4.675, 4.5, 3.096),
	},
	["creature.CeapaTurbo"] = {
		assetId = 100176165623637,
		palette = {},
		ink = nil,
		size = Vector3.new(3.448, 4.5, 2.968),
	},
	["creature.StrugurelFurios"] = {
		assetId = 136869326640536,
		palette = {},
		ink = nil,
		size = Vector3.new(3.548, 4.5, 2.909),
	},
	["creature.PepeneBoxer"] = {
		assetId = 126353718233028,
		palette = {},
		ink = nil,
		size = Vector3.new(4.254, 5.0, 3.518),
	},
	["creature.SarmalinaBallerina"] = {
		assetId = 101739650950607,
		palette = {},
		ink = nil,
		size = Vector3.new(3.436, 5.0, 3.232),
	},
	["creature.BranzoiSumo"] = {
		assetId = 135436137426014,
		palette = {},
		ink = nil,
		size = Vector3.new(4.833, 5.5, 3.177),
	},
	["creature.PlacintonioBombardino"] = {
		assetId = 97858374299046,
		palette = {},
		ink = nil,
		size = Vector3.new(7.042, 5.5, 5.786),
	},
	["creature.ColtunasPirat"] = {
		assetId = 102399163916647,
		palette = {},
		ink = nil,
		size = Vector3.new(4.134, 5.5, 2.509),
	},
	["creature.CozonacRobot"] = {
		assetId = 124316993687533,
		palette = {},
		ink = nil,
		size = Vector3.new(4.917, 6.0, 2.699),
	},
	["creature.DovleacDJ"] = {
		assetId = 138458223048660,
		palette = {},
		ink = nil,
		size = Vector3.new(4.726, 6.0, 4.434),
	},
	["creature.Papucel"] = {
		assetId = 114552589034664,
		palette = {},
		ink = nil,
		size = Vector3.new(4.388, 3.2, 4.758),
	},
	["creature.Martisorel"] = {
		assetId = 87830607716052,
		palette = {},
		ink = nil,
		size = Vector3.new(3.914, 5.5, 3.111),
	},
	["creature.RetetaSecreta"] = {
		assetId = 80428205584362,
		palette = {},
		ink = nil,
		size = Vector3.new(5.665, 6.5, 2.685),
	},
	["char.Bunica"] = { assetId = 100490284919264, palette = {}, ink = nil, size = Vector3.new(0, 6.2, 0) },
} :: { [string]: Art })
