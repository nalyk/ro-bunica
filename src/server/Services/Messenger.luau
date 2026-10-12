--!strict
-- Mesaje către jucători. Textul se compune pe client, în limba fiecăruia, din cheie + argumente.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local Messenger = {}

-- Argumentele care sunt chei de text (de exemplu "creature.X") se traduc pe client.
-- Le marcăm cu prefixul "@" ca să nu fie confundate cu nume de jucători.
function Messenger.key(key: string): string
	return "@" .. key
end

function Messenger.notify(player: Player?, key: string, args: { any }?)
	if player and player.Parent == Players then
		Net.get("Notify"):FireClient(player, key, args)
	end
end

function Messenger.announce(key: string, args: { any }?)
	Net.get("Announce"):FireAllClients(key, args)
end

return Messenger
