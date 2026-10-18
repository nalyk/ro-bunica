--!strict
-- Titlurile de deasupra numelui: orice personaj cu atributul „Title” primește o etichetă (tradusă local).

local Players = game:GetService("Players")

local ClientState = require(script.Parent.ClientState)

local TitleController = {}

local function decorate(character: Model)
	local function refresh()
		local old = character:FindFirstChild("TitleLabel")
		if old then
			old:Destroy()
		end
		local id = character:GetAttribute("Title")
		local head = character:FindFirstChild("Head") :: BasePart?
		if typeof(id) ~= "string" or not head then
			return
		end
		local gui = Instance.new("BillboardGui")
		gui.Name = "TitleLabel"
		gui.Size = UDim2.fromOffset(200, 26)
		gui.StudsOffset = Vector3.new(0, 2.9, 0)
		gui.MaxDistance = 80
		gui.Adornee = head
		gui.Parent = character
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = Color3.fromRGB(255, 215, 90)
		label.TextStrokeTransparency = 0.3
		label.Text = "★ " .. ClientState.t("title." .. id)
		label.Parent = gui
	end
	character:GetAttributeChangedSignal("Title"):Connect(refresh)
	task.defer(refresh)
end

function TitleController.start()
	local function watch(player: Player)
		if player.Character then
			decorate(player.Character)
		end
		player.CharacterAdded:Connect(decorate)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
end

return TitleController
