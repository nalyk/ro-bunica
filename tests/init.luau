--!nocheck
-- Harness de teste Lune: rulează fiecare tests/*.spec.luau.
-- Emulează `script` și `require(instanță)` peste sistemul de fișiere, ca modulele din
-- src/shared să ruleze neschimbate. Rulare: `lune run tests` (opțional un filtru: `lune run tests Economy`).

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local stdio = require("@lune/stdio")

local ROOTS = {
	Shared = "src/shared",
	Server = "src/server",
}

-- Tipuri de date Roblox disponibile modulelor testate
local DATATYPES = {}
for _, name in { "Vector3", "Vector2", "CFrame", "Color3", "UDim", "UDim2", "NumberRange", "Enum" } do
	DATATYPES[name] = (roblox :: any)[name]
end

local moduleCache: { [string]: any } = {}
local makeNode

-- Index sincron al fișierelor (fs din Lune cedează controlul, deci nu poate fi folosit în metamethod-uri)
local FILES: { [string]: boolean } = {}
local DIRS: { [string]: boolean } = {}
local function indexDir(path: string)
	DIRS[path] = true
	for _, entry in fs.readDir(path) do
		local full = path .. "/" .. entry
		if fs.isDir(full) then
			indexDir(full)
		else
			FILES[full] = true
		end
	end
end
for _, root in ROOTS do
	indexDir(root)
end

local function resolveFile(path: string): string?
	if FILES[path .. ".luau"] then
		return path .. ".luau"
	elseif DIRS[path] and FILES[path .. "/init.luau"] then
		return path .. "/init.luau"
	end
	return nil
end

local function exists(path: string): boolean
	return FILES[path .. ".luau"] == true or DIRS[path] == true
end

local function dirname(path: string): string
	return string.match(path, "^(.*)/[^/]+$") or path
end

local function basename(path: string): string
	return string.match(path, "([^/]+)$") or path
end

local customRequire

-- Un nod fals care se comportă ca o instanță Roblox pentru navigare: script.Parent.X
function makeNode(path: string)
	local node = { __path = path }
	return setmetatable(node, {
		__index = function(_, key)
			if key == "Parent" then
				-- Pentru un fișier `X/init.luau`, scriptul e chiar folderul X
				return makeNode(dirname(path))
			elseif key == "Name" then
				return basename(path)
			elseif key == "FindFirstChild" then
				return function(_, name)
					local childPath = path .. "/" .. name
					return if exists(childPath) then makeNode(childPath) else nil
				end
			elseif key == "WaitForChild" then
				return function(self, name)
					return self[name]
				end
			end
			local childPath = path .. "/" .. key
			if not exists(childPath) then
				error(string.format("%s is not a valid member of %s", tostring(key), path), 2)
			end
			return makeNode(childPath)
		end,
		__tostring = function()
			return path
		end,
	})
end

function customRequire(target)
	local path = if type(target) == "table" and rawget(target, "__path") then target.__path else nil
	if not path then
		error("require() în teste acceptă doar noduri de tip script.X", 2)
	end
	local file = resolveFile(path)
	if not file then
		error("Modul inexistent: " .. path, 2)
	end
	if moduleCache[file] ~= nil then
		return moduleCache[file]
	end
	local source = fs.readFile(file)
	local env = { script = makeNode(path), require = customRequire }
	for name, value in DATATYPES do
		env[name] = value
	end
	local chunk = luau.load(source, { debugName = file, environment = env })
	local result = chunk()
	moduleCache[file] = result
	return result
end

-- Mini framework de teste
local results = { passed = 0, failed = 0, failures = {} }
local currentPrefix = {}

local function deepEqual(a, b): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function fmt(value): string
	if type(value) == "table" then
		local ok, encoded = pcall(function()
			return require("@lune/serde").encode("json", value)
		end)
		return if ok then encoded else tostring(value)
	end
	return tostring(value)
end

local function expect(actual)
	local function fail(message: string)
		error(message, 3)
	end
	local matchers = {}
	function matchers.toBe(expected)
		if actual ~= expected then
			fail(string.format("așteptat %s, primit %s", fmt(expected), fmt(actual)))
		end
	end
	function matchers.toEqual(expected)
		if not deepEqual(actual, expected) then
			fail(string.format("așteptat %s, primit %s", fmt(expected), fmt(actual)))
		end
	end
	function matchers.toBeCloseTo(expected: number, epsilon: number?)
		if math.abs(actual - expected) > (epsilon or 1e-6) then
			fail(string.format("așteptat ≈%s, primit %s", fmt(expected), fmt(actual)))
		end
	end
	function matchers.toBeTruthy()
		if not actual then
			fail("așteptat truthy, primit " .. fmt(actual))
		end
	end
	function matchers.toBeFalsy()
		if actual then
			fail("așteptat falsy, primit " .. fmt(actual))
		end
	end
	function matchers.toBeNil()
		if actual ~= nil then
			fail("așteptat nil, primit " .. fmt(actual))
		end
	end
	function matchers.toBeGreaterThan(expected: number)
		if not (actual > expected) then
			fail(string.format("așteptat > %s, primit %s", fmt(expected), fmt(actual)))
		end
	end
	function matchers.toBeLessThan(expected: number)
		if not (actual < expected) then
			fail(string.format("așteptat < %s, primit %s", fmt(expected), fmt(actual)))
		end
	end
	function matchers.toThrow(pattern: string?)
		local ok, err = pcall(actual)
		if ok then
			fail("așteptat să arunce o eroare")
		elseif pattern and not string.find(tostring(err), pattern, 1, true) then
			fail(string.format("eroarea '%s' nu conține '%s'", tostring(err), pattern))
		end
	end
	return matchers
end

local function describe(name: string, fn: () -> ())
	table.insert(currentPrefix, name)
	fn()
	table.remove(currentPrefix)
end

local function it(name: string, fn: () -> ())
	local fullName = table.concat(currentPrefix, " › ") .. " › " .. name
	local ok, err = pcall(fn)
	if ok then
		results.passed += 1
	else
		results.failed += 1
		table.insert(results.failures, { name = fullName, err = tostring(err) })
	end
end

-- Descoperire și rulare
local filter = process.args[1]
local specs = {}
for _, entry in fs.readDir("tests") do
	if string.match(entry, "%.spec%.luau$") and (not filter or string.find(entry, filter, 1, true)) then
		table.insert(specs, entry)
	end
end
table.sort(specs)

for _, spec in specs do
	local file = "tests/" .. spec
	local env = { describe = describe, it = it, expect = expect, require = customRequire }
	for rootName, rootPath in ROOTS do
		env[rootName] = makeNode(rootPath)
	end
	for name, value in DATATYPES do
		env[name] = value
	end
	local ok, err = pcall(function()
		luau.load(fs.readFile(file), { debugName = file, environment = env })()
	end)
	if not ok then
		results.failed += 1
		table.insert(results.failures, { name = spec .. " (încărcare)", err = tostring(err) })
	end
end

for _, failure in results.failures do
	print(stdio.color("red") .. "✗ " .. failure.name .. stdio.color("reset"))
	print("    " .. failure.err)
end
print(string.format("\n%d trecute, %d picate (%d fișiere)", results.passed, results.failed, #specs))
process.exit(if results.failed == 0 then 0 else 1)
