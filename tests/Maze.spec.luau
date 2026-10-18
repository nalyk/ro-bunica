local Maze = require(Shared.Domain.Maze)

local function reachable(maze: any): number
	local seen = { [1] = true }
	local queue = { { 1, 1 } }
	local count = 1
	while #queue > 0 do
		local cell = table.remove(queue, 1)
		local x, y = cell[1], cell[2]
		for _, d in { { 1, 0, "E" }, { -1, 0, "W" }, { 0, 1, "S" }, { 0, -1, "N" } } do
			local nx, ny = x + d[1], y + d[2]
			if
				nx >= 1
				and nx <= maze.width
				and ny >= 1
				and ny <= maze.height
				and Maze.open(maze, x, y, d[3])
			then
				local id = (ny - 1) * maze.width + nx
				if not seen[id] then
					seen[id] = true
					count += 1
					table.insert(queue, { nx, ny })
				end
			end
		end
	end
	return count
end

describe("Maze", function()
	it("toate celulele se pot atinge (arbore: exact w·h − 1 treceri)", function()
		local maze = Maze.generate(9, 9, 42)
		expect(reachable(maze)).toBe(81)
		local openings = 0
		for y = 1, 9 do
			for x = 1, 9 do
				if Maze.open(maze, x, y, "E") then
					openings += 1
				end
				if Maze.open(maze, x, y, "S") then
					openings += 1
				end
			end
		end
		expect(openings).toBe(80)
	end)
	it("e simetric: E din (x,y) e același cu W din (x+1,y)", function()
		local maze = Maze.generate(7, 5, 3)
		for y = 1, 5 do
			for x = 1, 6 do
				expect(Maze.open(maze, x, y, "E")).toBe(Maze.open(maze, x + 1, y, "W"))
			end
		end
	end)
	it("e determinist pe seed și diferă între seed-uri", function()
		local a, b, c = Maze.generate(9, 9, 42), Maze.generate(9, 9, 42), Maze.generate(9, 9, 43)
		local same, differs = true, false
		for y = 1, 9 do
			for x = 1, 9 do
				same = same and Maze.open(a, x, y, "E") == Maze.open(b, x, y, "E")
				differs = differs or Maze.open(a, x, y, "E") ~= Maze.open(c, x, y, "E")
			end
		end
		expect(same).toBe(true)
		expect(differs).toBe(true)
	end)
	it("marginea e închisă", function()
		local maze = Maze.generate(5, 5, 1)
		for i = 1, 5 do
			expect(Maze.open(maze, 1, i, "W")).toBe(false)
			expect(Maze.open(maze, 5, i, "E")).toBe(false)
			expect(Maze.open(maze, i, 1, "N")).toBe(false)
			expect(Maze.open(maze, i, 5, "S")).toBe(false)
		end
	end)
end)
