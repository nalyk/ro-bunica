--!strict
-- Starea locală a jucătorului (primită de la server) și traducerea textelor.

local LocalizationService = game:GetService("LocalizationService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Strings = require(Shared.Strings)

local ClientState = {}

ClientState.state = {} :: { [string]: any }
ClientState.shopStock = {} :: { [string]: number }
ClientState.shopRestockAt = 0
ClientState.selectedSeed = nil :: string?

local listeners: { () -> () } = {}
local shopListeners: { () -> () } = {}

local language = Strings.languageFor(LocalizationService.RobloxLocaleId)

function ClientState.language(): string
	return language
end

-- Argumentele cu prefix „@” sunt chei de text și se traduc.
function ClientState.t(key: string, args: { any }?): string
	local translated: { any }? = nil
	if args then
		translated = {}
		for index, value in args do
			if type(value) == "string" and string.sub(value, 1, 1) == "@" then
				(translated :: { any })[index] = Strings.get(language, string.sub(value, 2))
			else
				(translated :: { any })[index] = value
			end
		end
	end
	return Strings.get(language, key, translated)
end

-- Numele afișat al unei creaturi, cu mutația și mărimea în ordinea limbii (`fmt.creature`)
function ClientState.creatureName(id: string, size: string?, mutation: string?, name: string?): string
	local text = ClientState.t("fmt.creature", {
		if mutation and mutation ~= "" then ClientState.t("mutation." .. mutation) else "",
		if size then ClientState.t("size." .. size) else "",
		name or ClientState.t("creature." .. id),
	})
	return (string.gsub(string.gsub(text, "%s+", " "), "^%s*(.-)%s*$", "%1"))
end

function ClientState.onChanged(callback: () -> ())
	table.insert(listeners, callback)
end

function ClientState.onShopChanged(callback: () -> ())
	table.insert(shopListeners, callback)
end

function ClientState.myPlot(): Model?
	local index = ClientState.state.plotIndex
	if not index then
		return nil
	end
	local village = workspace:FindFirstChild("Village")
	return if village then village:FindFirstChild("Plot" .. index) :: Model? else nil
end

function ClientState.start()
	Net.get("State").OnClientEvent:Connect(function(state)
		ClientState.state = state
		local seeds = state.seeds or {}
		if ClientState.selectedSeed and not seeds[ClientState.selectedSeed] then
			ClientState.selectedSeed = nil
		end
		for _, callback in listeners do
			task.spawn(callback)
		end
	end)
	Net.get("Shop").OnClientEvent:Connect(function(stock, restockAt)
		ClientState.shopStock = stock
		ClientState.shopRestockAt = restockAt
		for _, callback in shopListeners do
			task.spawn(callback)
		end
	end)
end

return ClientState
