--[[
    MazeGenerator.lua
    =================
    Server Script — procedural maze generation using Recursive Backtracking (DFS).
    
    Generates a grid-based maze with Backrooms-aesthetic parts:
    floors, walls, ceiling, fluorescent lights with random flickering.
    
    API:
        MazeGenerator.generate(player) → mazeFolder, startCFrame, exitCFrame
        MazeGenerator.destroy(mazeFolder)
        MazeGenerator.getSpawnNodes(grid, mazeOrigin, count) → {CFrame}
    
    Dependencies:
        - MazeConfig
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local MazeConfig = require(Modules.Data.MazeConfig)

local MazeGenerator = {}

-- Track per-player maze index to offset each maze in world space
local playerMazeIndex = 0

--------------------------------------------------------------------------------
-- INTERNAL: Cell grid representation
-- Each cell: { visited = bool, walls = { N, S, E, W } }
--------------------------------------------------------------------------------

local DIRECTIONS = {
    N = { dx = 0,  dz = -1, opposite = "S" },
    S = { dx = 0,  dz = 1,  opposite = "N" },
    E = { dx = 1,  dz = 0,  opposite = "W" },
    W = { dx = -1, dz = 0,  opposite = "E" },
}

local DIR_KEYS = { "N", "S", "E", "W" }

local function createGrid(width: number, height: number)
    local grid = {}
    for x = 1, width do
        grid[x] = {}
        for z = 1, height do
            grid[x][z] = {
                visited = false,
                walls = { N = true, S = true, E = true, W = true },
                x = x,
                z = z,
            }
        end
    end
    return grid
end

local function isInBounds(x: number, z: number, width: number, height: number): boolean
    return x >= 1 and x <= width and z >= 1 and z <= height
end

--------------------------------------------------------------------------------
-- INTERNAL: Recursive Backtracking DFS
--------------------------------------------------------------------------------

local function generateMazeGrid(width: number, height: number)
    local grid = createGrid(width, height)
    local stack = {}

    -- Start at (1, 1)
    local startCell = grid[1][1]
    startCell.visited = true
    table.insert(stack, startCell)

    while #stack > 0 do
        local current = stack[#stack]

        -- Collect unvisited neighbors
        local neighbors = {}
        for _, dirKey in ipairs(DIR_KEYS) do
            local dir = DIRECTIONS[dirKey]
            local nx = current.x + dir.dx
            local nz = current.z + dir.dz
            if isInBounds(nx, nz, width, height) then
                local neighbor = grid[nx][nz]
                if not neighbor.visited then
                    table.insert(neighbors, { cell = neighbor, dir = dirKey })
                end
            end
        end

        if #neighbors > 0 then
            -- Pick random neighbor
            local chosen = neighbors[math.random(1, #neighbors)]
            local neighbor = chosen.cell
            local dirKey = chosen.dir
            local dir = DIRECTIONS[dirKey]

            -- Remove walls between current and neighbor
            current.walls[dirKey] = false
            neighbor.walls[dir.opposite] = false

            neighbor.visited = true
            table.insert(stack, neighbor)
        else
            -- Backtrack
            table.remove(stack, #stack)
        end
    end

    return grid
end

--------------------------------------------------------------------------------
-- INTERNAL: Find the farthest cell from start using BFS (for exit placement)
--------------------------------------------------------------------------------

local function findFarthestCell(grid, width: number, height: number, startX: number, startZ: number)
    local visited = {}
    local queue = {}
    local farthest = { x = startX, z = startZ, dist = 0 }

    local key = startX .. "_" .. startZ
    visited[key] = true
    table.insert(queue, { x = startX, z = startZ, dist = 0 })

    while #queue > 0 do
        local current = table.remove(queue, 1)
        local cell = grid[current.x][current.z]

        if current.dist > farthest.dist then
            farthest = current
        end

        for _, dirKey in ipairs(DIR_KEYS) do
            if not cell.walls[dirKey] then
                local dir = DIRECTIONS[dirKey]
                local nx = current.x + dir.dx
                local nz = current.z + dir.dz
                local nKey = nx .. "_" .. nz

                if isInBounds(nx, nz, width, height) and not visited[nKey] then
                    visited[nKey] = true
                    table.insert(queue, { x = nx, z = nz, dist = current.dist + 1 })
                end
            end
        end
    end

    return farthest.x, farthest.z
end

--------------------------------------------------------------------------------
-- INTERNAL: Convert grid cell coordinates to world position
--------------------------------------------------------------------------------

local function cellToWorldPos(cellX: number, cellZ: number, origin: Vector3): Vector3
    local ts = MazeConfig.TileSize
    local worldX = origin.X + (cellX - 1) * ts + ts / 2
    local worldZ = origin.Z + (cellZ - 1) * ts + ts / 2
    return Vector3.new(worldX, origin.Y, worldZ)
end

--------------------------------------------------------------------------------
-- INTERNAL: Build 3D parts from the grid
--------------------------------------------------------------------------------

local function buildMazeParts(grid, width: number, height: number, origin: Vector3, folder: Folder)
    local ts = MazeConfig.TileSize
    local wh = MazeConfig.WallHeight
    local wt = MazeConfig.WallThickness
    local ft = MazeConfig.FloorThickness

    for x = 1, width do
        for z = 1, height do
            local cell = grid[x][z]
            local center = cellToWorldPos(x, z, origin)

            -- FLOOR
            local floor = Instance.new("Part")
            floor.Name = "Floor_" .. x .. "_" .. z
            floor.Size = Vector3.new(ts, ft, ts)
            floor.Position = center + Vector3.new(0, ft / 2, 0)
            floor.Anchored = true
            floor.Material = MazeConfig.FloorMaterial
            floor.Color = MazeConfig.FloorColor
            floor.TopSurface = Enum.SurfaceType.Smooth
            floor.BottomSurface = Enum.SurfaceType.Smooth
            floor.Parent = folder

            -- CEILING
            local ceiling = Instance.new("Part")
            ceiling.Name = "Ceiling_" .. x .. "_" .. z
            ceiling.Size = Vector3.new(ts, ft, ts)
            ceiling.Position = center + Vector3.new(0, wh + ft / 2, 0)
            ceiling.Anchored = true
            ceiling.Material = MazeConfig.CeilingMaterial
            ceiling.Color = MazeConfig.CeilingColor
            ceiling.TopSurface = Enum.SurfaceType.Smooth
            ceiling.BottomSurface = Enum.SurfaceType.Smooth
            ceiling.Transparency = 0
            ceiling.Parent = folder

            -- WALLS (only build if wall exists)
            -- North wall (Z-)
            if cell.walls.N then
                local wall = Instance.new("Part")
                wall.Name = "Wall_N_" .. x .. "_" .. z
                wall.Size = Vector3.new(ts, wh, wt)
                wall.Position = center + Vector3.new(0, wh / 2 + ft, -ts / 2 + wt / 2)
                wall.Anchored = true
                wall.Material = MazeConfig.WallMaterial
                wall.Color = MazeConfig.WallColor
                wall.Parent = folder
            end

            -- South wall (Z+)
            if cell.walls.S then
                local wall = Instance.new("Part")
                wall.Name = "Wall_S_" .. x .. "_" .. z
                wall.Size = Vector3.new(ts, wh, wt)
                wall.Position = center + Vector3.new(0, wh / 2 + ft, ts / 2 - wt / 2)
                wall.Anchored = true
                wall.Material = MazeConfig.WallMaterial
                wall.Color = MazeConfig.WallColor
                wall.Parent = folder
            end

            -- West wall (X-)
            if cell.walls.W then
                local wall = Instance.new("Part")
                wall.Name = "Wall_W_" .. x .. "_" .. z
                wall.Size = Vector3.new(wt, wh, ts)
                wall.Position = center + Vector3.new(-ts / 2 + wt / 2, wh / 2 + ft, 0)
                wall.Anchored = true
                wall.Material = MazeConfig.WallMaterial
                wall.Color = MazeConfig.WallColor
                wall.Parent = folder
            end

            -- East wall (X+)
            if cell.walls.E then
                local wall = Instance.new("Part")
                wall.Name = "Wall_E_" .. x .. "_" .. z
                wall.Size = Vector3.new(wt, wh, ts)
                wall.Position = center + Vector3.new(ts / 2 - wt / 2, wh / 2 + ft, 0)
                wall.Anchored = true
                wall.Material = MazeConfig.WallMaterial
                wall.Color = MazeConfig.WallColor
                wall.Parent = folder
            end

            -- CEILING LIGHTS (every N cells)
            if (x - 1) % MazeConfig.LightSpacing == 0 and (z - 1) % MazeConfig.LightSpacing == 0 then
                local lightPart = Instance.new("Part")
                lightPart.Name = "Light_" .. x .. "_" .. z
                lightPart.Size = Vector3.new(4, 0.5, 2)
                lightPart.Position = center + Vector3.new(0, wh + ft - 0.25, 0)
                lightPart.Anchored = true
                lightPart.Material = Enum.Material.Neon
                lightPart.Color = MazeConfig.LightColor
                lightPart.Parent = folder

                local pointLight = Instance.new("PointLight")
                pointLight.Brightness = MazeConfig.LightBrightness
                pointLight.Range = MazeConfig.LightRange
                pointLight.Color = MazeConfig.LightColor
                pointLight.Parent = lightPart

                -- Random flicker for some lights
                if math.random() < MazeConfig.FlickerChance then
                    task.spawn(function()
                        while lightPart and lightPart.Parent do
                            local interval = MazeConfig.FlickerMinInterval +
                                math.random() * (MazeConfig.FlickerMaxInterval - MazeConfig.FlickerMinInterval)
                            task.wait(interval)

                            if lightPart and lightPart.Parent then
                                -- Toggle light
                                pointLight.Enabled = not pointLight.Enabled
                                lightPart.Material = pointLight.Enabled
                                    and Enum.Material.Neon
                                    or Enum.Material.SmoothPlastic
                                lightPart.Color = pointLight.Enabled
                                    and MazeConfig.LightColor
                                    or Color3.fromRGB(80, 80, 70)
                            end
                        end
                    end)
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- INTERNAL: Create exit elevator part in the farthest cell
--------------------------------------------------------------------------------

local function createExitElevator(exitX: number, exitZ: number, origin: Vector3, folder: Folder): Part
    local center = cellToWorldPos(exitX, exitZ, origin)

    local exitPart = Instance.new("Part")
    exitPart.Name = "MazeExit"
    exitPart.Size = Vector3.new(6, 10, 6)
    exitPart.Position = center + Vector3.new(0, 6, 0)
    exitPart.Anchored = true
    exitPart.CanCollide = false
    exitPart.Transparency = 0.5
    exitPart.BrickColor = BrickColor.new("Bright green")
    exitPart.Material = Enum.Material.Neon
    exitPart.Parent = folder

    -- ProximityPrompt for extraction
    local prompt = Instance.new("ProximityPrompt")
    prompt.ObjectText = "Exit Elevator"
    prompt.ActionText = MazeConfig.ExitPromptText
    prompt.HoldDuration = 1.5
    prompt.MaxActivationDistance = 12
    prompt.Parent = exitPart

    -- Proximity-based hum sound (louder as you approach)
    local exitSound = Instance.new("Sound")
    exitSound.Name = "ExitHum"
    exitSound.SoundId = "rbxassetid://1846677817" -- Electrical hum/drone
    exitSound.Looped = true
    exitSound.Volume = 1
    exitSound.RollOffMode = Enum.RollOffMode.Linear
    exitSound.RollOffMinDistance = 8
    exitSound.RollOffMaxDistance = 100
    exitSound.Playing = true
    exitSound.Parent = exitPart

    -- Green glow beacon
    local exitLight = Instance.new("PointLight")
    exitLight.Brightness = 1.5
    exitLight.Range = 18
    exitLight.Color = Color3.fromRGB(0, 255, 100)
    exitLight.Parent = exitPart

    return exitPart
end

--------------------------------------------------------------------------------
-- PUBLIC: Generate a new maze for a player
-- @return mazeFolder, startCFrame, exitCFrame, grid
--------------------------------------------------------------------------------

function MazeGenerator.generate(player: Player)
    local width = MazeConfig.GridWidth
    local height = MazeConfig.GridHeight

    -- Calculate unique origin for this maze instance
    playerMazeIndex += 1
    local origin = MazeConfig.MazeOriginBase + Vector3.new(
        playerMazeIndex * MazeConfig.PlayerMazeSpacing, 0, 0
    )

    -- Generate the grid
    local grid = generateMazeGrid(width, height)

    -- Find exit position (farthest from start)
    local exitX, exitZ = findFarthestCell(grid, width, height, 1, 1)

    -- Create folder to hold all maze parts
    local folder = Instance.new("Folder")
    folder.Name = "Maze_" .. player.Name .. "_" .. playerMazeIndex
    folder.Parent = Workspace

    -- Build 3D geometry
    buildMazeParts(grid, width, height, origin, folder)

    -- Create exit elevator
    local exitPart = createExitElevator(exitX, exitZ, origin, folder)

    -- Calculate spawn positions
    local startPos = cellToWorldPos(1, 1, origin)
    local startCFrame = CFrame.new(startPos + Vector3.new(0, 3, 0))

    local exitPos = cellToWorldPos(exitX, exitZ, origin)
    local exitCFrame = CFrame.new(exitPos + Vector3.new(0, 3, 0))

    print("[MazeGenerator] Generated " .. width .. "x" .. height ..
        " maze for " .. player.Name .. " at " .. tostring(origin))

    return folder, startCFrame, exitCFrame, grid, origin
end

--------------------------------------------------------------------------------
-- PUBLIC: Destroy a maze and all its parts
--------------------------------------------------------------------------------

function MazeGenerator.destroy(mazeFolder: Folder)
    if mazeFolder and mazeFolder.Parent then
        print("[MazeGenerator] Destroying maze: " .. mazeFolder.Name)
        mazeFolder:Destroy()
    end
end

--------------------------------------------------------------------------------
-- PUBLIC: Get random spawn positions for loot within the maze
-- Picks random cells and returns floor-level CFrames
-- @param grid — the maze grid from generate()
-- @param origin — the maze world origin
-- @param count — number of spawn nodes to generate
-- @return { CFrame }
--------------------------------------------------------------------------------

function MazeGenerator.getSpawnNodes(grid, origin: Vector3, count: number): { CFrame }
    local width = MazeConfig.GridWidth
    local height = MazeConfig.GridHeight
    local nodes = {}
    local usedCells = {}

    -- Don't spawn loot in the start cell (1,1) or exit cell
    usedCells["1_1"] = true

    local attempts = 0
    while #nodes < count and attempts < count * 10 do
        attempts += 1
        local rx = math.random(1, width)
        local rz = math.random(1, height)
        local key = rx .. "_" .. rz

        if not usedCells[key] then
            usedCells[key] = true
            local pos = cellToWorldPos(rx, rz, origin)
            local spawnCFrame = CFrame.new(pos + Vector3.new(0, MazeConfig.LootHeightOffset, 0))
            table.insert(nodes, spawnCFrame)
        end
    end

    return nodes
end

return MazeGenerator
