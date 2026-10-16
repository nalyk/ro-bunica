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
	["creature.Mamaligator"] = {
		assetId = 113637658530694,
		palette = {},
		ink = nil,
		size = Vector3.new(3.5, 5.0, 4.573),
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
	["world.Casa"] = {
		assetId = 126439630205540,
		palette = {},
		ink = nil,
		size = Vector3.new(18.96, 13.0, 18.829),
	},
	["world.Gard"] = {
		assetId = 132083824665869,
		palette = {},
		ink = nil,
		size = Vector3.new(13.06, 4.0, 0.808),
	},
	["world.Poarta"] = {
		assetId = 113958077903414,
		palette = {},
		ink = nil,
		size = Vector3.new(14.527, 8.0, 3.429),
	},
	["world.Fantana"] = {
		assetId = 88631495273280,
		palette = {},
		ink = nil,
		size = Vector3.new(9.915, 10.0, 5.821),
	},
	["world.Pedestal"] = {
		assetId = 82233070263864,
		palette = {},
		ink = nil,
		size = Vector3.new(4.06, 0.9, 4.239),
	},
	["world.Beci"] = {
		assetId = 89037383262498,
		palette = {},
		ink = nil,
		size = Vector3.new(5.578, 2.4, 5.956),
	},
	["world.Nuc"] = {
		assetId = 81696330778131,
		palette = {},
		ink = nil,
		size = Vector3.new(15.41, 18.0, 13.007),
	},
	["world.Visin"] = {
		assetId = 122193919030075,
		palette = {},
		ink = nil,
		size = Vector3.new(9.162, 11.0, 8.077),
	},
	["world.FloareaSoarelui"] = {
		assetId = 104346566196090,
		palette = {},
		ink = nil,
		size = Vector3.new(3.406, 6.0, 3.334),
	},
	["world.Raft"] = {
		assetId = 71439724980182,
		palette = {},
		ink = nil,
		size = Vector3.new(4.106, 2.0, 1.475),
	},
	["world.Tabla"] = {
		assetId = 96079570460892,
		palette = {},
		ink = nil,
		size = Vector3.new(11.226, 2.6, 1.418),
	},
	["char.Bunica"] = { assetId = 100490284919264, palette = {}, ink = nil, size = Vector3.new(0, 6.2, 0) },
	["world.GardLow"] = {
		assetId = 121405013072093,
		palette = {},
		ink = nil,
		size = Vector3.new(13.0, 4.0, 0.765),
	},
	["world.PedestalLow"] = {
		assetId = 76355402229697,
		palette = {},
		ink = nil,
		size = Vector3.new(4.188, 0.9, 4.349),
	},
	["world.RaftLow"] = {
		assetId = 76203266407974,
		palette = {},
		ink = nil,
		size = Vector3.new(4.125, 2.0, 1.446),
	},
} :: { [string]: Art })
