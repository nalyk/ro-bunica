--!strict
-- Pornirea serverului, ca modul: rulată de `init.server.luau` în joc și de testele e2e
-- (în sesiunile Open Cloud scripturile place-ului nu pornesc singure). Idempotentă.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local ORDER = {
	"DataService",
	"PlotService",
	"StateService",
	"CreatureService",
	"DayNightService",
	"WeatherService",
	"GardenService",
	"RaidService",
	"EconomyService",
	"ShopService",
	"SlipperService",
	"BunicaService",
}

local Boot = {}

local started = false
local services: { [string]: any } = {}

function Boot.start(): { [string]: any }
	if started then
		return services
	end
	started = true
	Net.setupServer()
	local folder = script.Parent.Services
	for _, name in ORDER do
		local module = folder:FindFirstChild(name)
		assert(module and module:IsA("ModuleScript"), "Serviciu lipsă: " .. name)
		services[name] = (require :: any)(module)
	end
	for _, name in ORDER do
		if services[name].init then
			services[name].init()
		end
	end
	for _, name in ORDER do
		if services[name].start then
			task.spawn(services[name].start)
		end
	end
	return services
end

return Boot
