--!strict
-- Bunica stă în fața casei sculptate, nu sub streașină: capul ei nu intră în acoperiș (raportat de om).

return function(Spec: any, services: { [string]: any })
	local describe, it, expect = Spec.describe, Spec.it, Spec.expect
	local PlotService = services.PlotService
	local BunicaService = services.BunicaService

	describe("Bunica în fața casei", function()
		it("în fiecare ogradă, creștetul Bunicii e în afara volumului casei", function()
			local checked = 0
			for _, plot in PlotService.plots do
				local house: Model? = nil
				for _, child in plot.geometry.model:GetChildren() do
					if child:IsA("Model") and child:GetAttribute("ArtKey") == "world.Casa" then
						house = child
					end
				end
				local _, head = BunicaService.rigFor(plot.index)
				if house and head then
					checked += 1
					local box, size = house:GetBoundingBox()
					-- creștetul și fața/ceafa capului, cu o margine
					for _, offset in
						{ Vector3.new(0, head.Size.Y / 2, 0), Vector3.new(0, 0, head.Size.Z / 2 + 0.3) }
					do
						local p = box:PointToObjectSpace(head.Position + offset)
						local inside = math.abs(p.X) < size.X / 2
							and math.abs(p.Y) < size.Y / 2
							and math.abs(p.Z) < size.Z / 2
						if inside then
							print(
								string.format(
									"[e2e] ograda %d: capul Bunicii în casă la %s",
									plot.index,
									tostring(p)
								)
							)
						end
						expect(inside).toBe(false)
					end
				end
			end
			expect(checked > 0).toBe(true)
		end)
	end)
end
