--!strict
-- Senzația loviturii („juice”). Doar la lovituri, niciodată la acțiuni de rutină.

return table.freeze({
	hitStopSeconds = 0.07, -- camera înghețată o clipă la impact
	fovPunch = 9, -- cu câte grade se strânge câmpul vizual
	fovRecoverSeconds = 0.25,
	shakeSlipper = 0.45,
	shakeHeavy = 0.8,
	shakeRadius = 80, -- doar jucătorii care văd lovitura simt efectul
	comicTextSeconds = 0.9,
	replaySpeed = 0.35, -- reluarea loviturii nopții, cu încetinitorul
	replayMinDistance = 12, -- loviturile de sub această distanță nu se reiau
})
