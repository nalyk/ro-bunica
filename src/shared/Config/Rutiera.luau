--!strict
-- Rutiera (microbuzul galben al satului): un circuit în 150 s pe toate drumurile, cu oprire la centru și la
-- fiecare ogradă (Domain/Rutiera). Nu urci cu o creatură furată în brațe.

return table.freeze({
	period = 150,
	dwell = 4, -- secunde de oprire în fiecare stație
	boardDistance = 16, -- cât de aproape trebuie să fii ca să urci
	seats = 8,
	sideOffset = 3.5, -- pe dreapta drumului
	size = Vector3.new(7, 7.5, 17),
	color = Color3.fromRGB(246, 196, 40),
})
