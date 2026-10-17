--!strict
-- Rulează toate testele e2e: pornește serverul (Boot), apoi fiecare *.spec din acest folder.
-- Folosit ca script de sarcină Open Cloud: `return require(game.ServerStorage.E2E.Runner)(only)`, unde `only` e
-- lista de spec-uri din lot (tools/cloud.py împarte suita: o sarcină Open Cloud are cel mult 5 minute).

local ServerScriptService = game:GetService("ServerScriptService")

local Spec = require(script.Parent.Spec)

return function(only: { string }?): Spec.Results
	local bootModule: any = ServerScriptService:WaitForChild("Server"):WaitForChild("Boot")
	local Boot = (require :: any)(bootModule)
	local services = Boot.start()
	task.wait(1) -- lasă serviciile să pornească (generarea lumii, vecinii NPC)
	-- Rezultatele nu depind de ora rulării: evenimentul de sâmbătă pornește doar din teste (forceStart)
	services.LiveEventService.setScheduled(false)
	local specs = {}
	for _, child in script.Parent:GetChildren() do
		if
			child:IsA("ModuleScript")
			and string.match(child.Name, "%.spec$")
			and (only == nil or table.find(only, child.Name) ~= nil)
		then
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
