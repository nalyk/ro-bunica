--!strict
-- Labirintul din lanul de porumb: un arbore de acoperire pe grilă (căutare în adâncime cu seed fix), deci orice
-- celulă se poate atinge și există un singur drum între oricare două. Trecerile se țin pe muchiile E și S.

export type Maze =
	{ width: number, height: number, east: { [number]: boolean }, south: { [number]: boolean } }

local Maze = {}

local function id(maze: Maze, x: number, y: number): number
	return (y - 1) * maze.width + x
end

function Maze.generate(width: number, height: number, seed: number): Maze
	local maze: Maze = { width = width, height = height, east = {}, south = {} }
	-- LCG propriu (nu Random): același labirint în teste și în joc, pe orice platformă
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	local function pick(n: number): number
		state = (state * 48271) % 2147483647
		return state % n + 1
	end
	local visited: { [number]: boolean } = { [id(maze, 1, 1)] = true }
	local stack = { { 1, 1 } }
	while #stack > 0 do
		local top = stack[#stack]
		local x, y = top[1], top[2]
		local options = {}
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local nx, ny = x + d[1], y + d[2]
			if nx >= 1 and nx <= width and ny >= 1 and ny <= height and not visited[id(maze, nx, ny)] then
				table.insert(options, { nx, ny })
			end
		end
		if #options == 0 then
			table.remove(stack)
		else
			local chosen = options[pick(#options)]
			local nx, ny = chosen[1], chosen[2]
			if nx > x then
				maze.east[id(maze, x, y)] = true
			elseif nx < x then
				maze.east[id(maze, nx, ny)] = true
			elseif ny > y then
				maze.south[id(maze, x, y)] = true
			else
				maze.south[id(maze, nx, ny)] = true
			end
			visited[id(maze, nx, ny)] = true
			table.insert(stack, chosen)
		end
	end
	return maze
end

-- Trecere din celula (x, y) spre direcția dată ("N", "S", "E", "W")?
function Maze.open(maze: Maze, x: number, y: number, direction: string): boolean
	if direction == "E" then
		return x < maze.width and maze.east[id(maze, x, y)] == true
	elseif direction == "W" then
		return x > 1 and maze.east[id(maze, x - 1, y)] == true
	elseif direction == "S" then
		return y < maze.height and maze.south[id(maze, x, y)] == true
	else
		return y > 1 and maze.south[id(maze, x, y - 1)] == true
	end
end

return Maze
