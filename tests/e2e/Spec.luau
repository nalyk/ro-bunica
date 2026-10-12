--!strict
-- Mini framework de teste pentru rularea în motorul Roblox (Open Cloud Luau Execution).

export type Results = { passed: number, failed: number, failures: { string } }

local Spec = {}

local results: Results = { passed = 0, failed = 0, failures = {} }
local prefix: { string } = {}

function Spec.describe(name: string, fn: () -> ())
	table.insert(prefix, name)
	fn()
	table.remove(prefix)
end

function Spec.it(name: string, fn: () -> ())
	local full = table.concat(prefix, " › ") .. " › " .. name
	local ok, err = pcall(fn :: any)
	if ok then
		results.passed += 1
		print("✓ " .. full)
	else
		results.failed += 1
		table.insert(results.failures, full .. ": " .. tostring(err))
		print("✗ " .. full .. ": " .. tostring(err))
	end
end

function Spec.expect(actual: any)
	local m = {}
	function m.toBe(expected: any)
		if actual ~= expected then
			error(string.format("așteptat %s, primit %s", tostring(expected), tostring(actual)), 2)
		end
	end
	function m.toBeTruthy()
		if not actual then
			error("așteptat truthy, primit " .. tostring(actual), 2)
		end
	end
	function m.toBeGreaterThan(expected: number)
		if not (actual > expected) then
			error(string.format("așteptat > %s, primit %s", tostring(expected), tostring(actual)), 2)
		end
	end
	function m.toBeCloseTo(expected: number, epsilon: number?)
		if math.abs(actual - expected) > (epsilon or 1e-3) then
			error(string.format("așteptat ≈%s, primit %s", tostring(expected), tostring(actual)), 2)
		end
	end
	return m
end

-- Așteaptă până când condiția e adevărată sau expiră timpul.
function Spec.waitFor(condition: () -> boolean, timeout: number?): boolean
	local deadline = os.clock() + (timeout or 10)
	while os.clock() < deadline do
		if condition() then
			return true
		end
		task.wait(0.1)
	end
	return condition()
end

function Spec.results(): Results
	return results
end

return Spec
