--!strict
-- Primul minut: hoțul scriptat care face gluma de bază să se întâmple înaintea pragului de 60 s.

return table.freeze({
	thiefDelaySeconds = 25, -- după intrare; creatura de start eclozează la ~15 s
	thiefWalkSpeed = 9, -- încet, ca un copil să-l poată ochi
	aimAssistRadius = 25, -- aruncările în această rază pleacă spre hoț
	fallbackSeconds = 12, -- dacă jucătorul nu nimerește, Bunica aruncă sigur
	cleanupSeconds = 4, -- cât mai stă hoțul în scenă după lovitură
})
