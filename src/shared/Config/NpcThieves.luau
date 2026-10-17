--!strict
-- Vecinii NPC care fură noaptea: noaptea are tensiune și pentru cine joacă singur.
-- Hoțul e un bot cu regulile furtului de la jucători (papucul, Bunica, alarma, limitele) și duce creatura
-- pe piedestalul vecinului, de unde jucătorul o poate fura înapoi.

return table.freeze({
	-- încercări pe noapte după câți jucători reali sunt pe server (indexul = numărul de jucători; peste = 0)
	attemptsByPlayers = table.freeze({ 3, 2, 2, 1, 1 }),
	firstDelay = table.freeze({ 20, 40 }), -- secunde după căderea nopții
	betweenDelay = table.freeze({ 35, 55 }),
	maxRarityOrder = 3, -- fură doar Comun, Rar sau Epic (Legendarele și peste nu)
	activeWindowSeconds = 90, -- jucătorul s-a mișcat în ultimele 90 s (cine e AFK nu e jefuit de boți)
	walkSpeed = 12, -- mai încet decât un jucător (16)
	approachSeconds = 45, -- dacă nu ajunge la creatură în atât, renunță
	-- timpul de cărat: drumul în linie dreaptă / viteza cu creatura × asta (drumul real trece prin două porți
	-- și ocolește casa până la beci) + o rezervă; mai mult timp înseamnă și mai multe șanse la papuc
	carrySlack = 2.6,
	carryExtraSeconds = 20,
	look = "Hotoman",
})
