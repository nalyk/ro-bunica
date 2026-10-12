--!strict
-- Reguli de furt și protecții.

return table.freeze({
	victimShieldSeconds = 60,
	maxStealsPerVictimPerNight = 2, -- apoi ograda e protejată până dimineață
	defenseRewardShare = 0.5, -- cine salvează o creatură primește această parte din prețul ei
	newPlayerProtectionSeconds = 20 * 60,
	promptMaxDistance = 10,
	depositRadius = 7,
	jumpPowerWhileCarrying = 0,
})
