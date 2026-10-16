--!strict
-- Primul script de pe client (ReplicatedFirst): înlocuiește ecranul de încărcare Roblox cu al nostru.

local ReplicatedFirst = game:GetService("ReplicatedFirst")

ReplicatedFirst:RemoveDefaultLoadingScreen()
require(script.LoadingScreen).play()
