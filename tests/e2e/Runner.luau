--!strict
-- Rulează toate testele e2e: pornește serverul (Boot), apoi fiecare *.spec din acest folder.
-- Folosit ca script de sarcină Open Cloud: `return require(game.ServerStorage.E2E.Runner)()`.

local ServerScriptService = game:GetService("ServerScriptService")

local Spec = require(script.Parent.Spec)

return function(): Spec.Results
	local bootModule: any = ServerScriptService:WaitForChild("Server"):WaitForChild("Boot")
	local Boot = (require :: any)(bootModule)
	local services = Boot.start()
	task.wait(1) -- lasă serviciile să pornească (generarea lumii, vecinii NPC)
	local specs = {}
	for _, child in script.Parent:GetChildren() do
		if child:IsA("ModuleScript") and string.match(child.Name, "%.spec$") then
			table.insert(specs, child)
		end
	end
	table.sort(specs, function(a, b)
		return a.Name < b.Name
	end)
	for _, module in specs do
		local ok, err = pcall(function()
			((require :: any)(module))(Spec, services)
		end)
		if not ok then
			local results = Spec.results()
			results.failed += 1
			table.insert(results.failures, module.Name .. " (încărcare): " .. tostring(err))
		end
	end
	local results = Spec.results()
	print(string.format("[e2e] %d trecute, %d picate", results.passed, results.failed))
	return results
end
