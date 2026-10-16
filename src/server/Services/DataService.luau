--!strict
-- Încărcarea și salvarea profilurilor cu ProfileStore (blocare pe sesiune, autosave).
-- Celelalte servicii folosesc `onLoaded` și `onReleasing`; nu ating direct ProfileStore.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DataTemplate = require(Shared.Config.DataTemplate)
local Migrations = require(Shared.Domain.Migrations)
local ProfileStore = require(script.Parent.Parent.Packages.ProfileStore)

type Profile = DataTemplate.Profile

local STORE_NAME = "Bunica_Players_v1"

local DataService = {}

local store = ProfileStore.New(STORE_NAME, DataTemplate.new())
local profiles: { [Player]: any } = {}
local loadedCallbacks: { (Player, Profile) -> () } = {}
local releasingCallbacks: { (Player, Profile) -> () } = {}

local function runCallbacks(list: { (Player, Profile) -> () }, player: Player, data: Profile)
	for _, callback in list do
		local ok, err = pcall(callback :: any, player, data)
		if not ok then
			warn("[DataService] callback a eșuat:", err)
		end
	end
end

local function load(player: Player)
	local profile = store:StartSessionAsync("Player_" .. player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		player:Kick("Nu am putut încărca datele. Încearcă din nou.")
		return
	end
	profile:AddUserId(player.UserId)
	Migrations.reconcile(profile.Data)
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Sesiunea s-a încheiat. Intră din nou.")
	end)
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	profiles[player] = profile
	runCallbacks(loadedCallbacks, player, profile.Data)
end

local function release(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	runCallbacks(releasingCallbacks, player, profile.Data)
	profile.Data.lastSeen = os.time()
	profiles[player] = nil
	profile:EndSession()
end

function DataService.init()
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(release)
end

function DataService.start()
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
end

-- Datele vii ale jucătorului (nil până se încarcă).
function DataService.get(player: Player): Profile?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

-- Apelat când profilul e gata; și pentru jucătorii deja încărcați.
-- Salvează acum (după o cumpărare pe Robux, ca plata și efectul ei să nu se piardă la o cădere)
function DataService.save(player: Player)
	local profile = profiles[player]
	if profile then
		profile:Save()
	end
end

function DataService.onLoaded(callback: (Player, Profile) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile.Data)
	end
end

-- Apelat înainte de salvarea finală, cât profilul încă se poate modifica.
function DataService.onReleasing(callback: (Player, Profile) -> ())
	table.insert(releasingCallbacks, callback)
end

return DataService
