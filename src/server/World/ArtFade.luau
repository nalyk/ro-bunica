--!strict
-- Estomparea pieselor din ogradă (piedestale, straturi) blocate. Când piesa are un model sculptat
-- (ObjectValue „Art”, pus de WorldBuilder), piesa rămâne coliziune invizibilă și se estompează modelul,
-- pornind de la transparența inițială a fiecărei piese (piesele ascunse ale șablonului rămân ascunse).

local ArtFade = {}

function ArtFade.set(part: BasePart, fade: number)
	local link = part:FindFirstChild("Art") :: ObjectValue?
	local art = link and link.Value
	if not art then
		part.Transparency = fade
		return
	end
	part.Transparency = 1
	for _, d in art:GetDescendants() do
		if d:IsA("BasePart") then
			local stored = d:GetAttribute("BaseTransparency")
			local base: number = if type(stored) == "number" then stored else d.Transparency
			d:SetAttribute("BaseTransparency", base)
			d.Transparency = 1 - (1 - base) * (1 - fade)
		end
	end
end

-- Leagă modelul sculptat de piesa pe care o acoperă (pentru ArtFade.set)
function ArtFade.link(part: BasePart, art: Model)
	local link = Instance.new("ObjectValue")
	link.Name = "Art"
	link.Value = art
	link.Parent = part
end

return ArtFade
