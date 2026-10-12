--!strict
-- Pornirea serverului: creează remote-urile, apoi init() și start() pe fiecare serviciu, în ordine.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

Net.setupServer()

local Services = script.Services
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

local loaded = {}
for _, name in ORDER do
	local module = Services:FindFirstChild(name)
	assert(module and module:IsA("ModuleScript"), "Serviciu lipsă: " .. name)
	loaded[name] = (require :: any)(module)
end
for _, name in ORDER do
	if loaded[name].init then
		loaded[name].init()
	end
end
for _, name in ORDER do
	if loaded[name].start then
		task.spawn(loaded[name].start)
	end
end
print("[Bunica] server pornit")
