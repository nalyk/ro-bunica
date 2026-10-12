--!strict
-- Papucul: muniție cu reîncărcare, traiectorie balistică și detecția loviturii.

export type Ammo = {
	ammo: number,
	regenStart: number, -- momentul de la care curge reîncărcarea următorului papuc
}

local Slipper = {}

function Slipper.newAmmo(max: number, now: number): Ammo
	return { ammo = max, regenStart = now }
end

function Slipper.updateAmmo(state: Ammo, now: number, max: number, regenSeconds: number)
	if state.ammo >= max then
		state.ammo = max
		state.regenStart = now
		return
	end
	while state.ammo < max and now - state.regenStart >= regenSeconds do
		state.ammo += 1
		state.regenStart += regenSeconds
	end
	if state.ammo >= max then
		state.regenStart = now
	end
end

-- Consumă un papuc dacă există. Întoarce false dacă nu mai e muniție.
function Slipper.consume(state: Ammo, now: number, max: number, regenSeconds: number): boolean
	Slipper.updateAmmo(state, now, max, regenSeconds)
	if state.ammo < 1 then
		return false
	end
	state.ammo -= 1
	return true
end

-- Viteza inițială ca proiectilul să ajungă în `target` sub gravitație, la viteza `speed`.
-- Ținta e limitată la `maxRange` de la origine.
function Slipper.launchVelocity(
	origin: Vector3,
	target: Vector3,
	speed: number,
	gravity: number,
	maxRange: number
): Vector3
	local offset = target - origin
	local distance = offset.Magnitude
	if distance < 1e-3 then
		return Vector3.new(0, 0, -speed)
	end
	if distance > maxRange then
		offset = offset.Unit * maxRange
		distance = maxRange
	end
	local flightTime = distance / speed
	return offset / flightTime + Vector3.new(0, gravity * flightTime / 2, 0)
end

function Slipper.positionAt(origin: Vector3, velocity: Vector3, gravity: number, t: number): Vector3
	return origin + velocity * t + Vector3.new(0, -0.5 * gravity * t * t, 0)
end

-- Distanța de la punctul `p` la segmentul [a, b].
function Slipper.segmentDistance(a: Vector3, b: Vector3, p: Vector3): number
	local ab = b - a
	local lengthSquared = ab:Dot(ab)
	if lengthSquared < 1e-9 then
		return (p - a).Magnitude
	end
	local t = math.clamp((p - a):Dot(ab) / lengthSquared, 0, 1)
	return (p - (a + ab * t)).Magnitude
end

-- Lovește proiectilul ținta pe segmentul parcurs într-un pas?
function Slipper.hits(
	a: Vector3,
	b: Vector3,
	targetCenter: Vector3,
	hitRadius: number,
	targetRadius: number
): boolean
	return Slipper.segmentDistance(a, b, targetCenter) <= hitRadius + targetRadius
end

return Slipper
