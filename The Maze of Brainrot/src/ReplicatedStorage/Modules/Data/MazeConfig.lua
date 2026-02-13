--[[
    MazeConfig.lua
    ==============
    Configuration data for procedural maze generation.
    
    All maze dimensions, tile sizes, material choices, and spawn
    parameters are defined here. Frozen at runtime.
]]

local MazeConfig = {}

--------------------------------------------------------------------------------
-- Grid & Tile Dimensions
--------------------------------------------------------------------------------

MazeConfig.GridWidth = 10          -- Number of cells horizontally
MazeConfig.GridHeight = 10         -- Number of cells vertically
MazeConfig.TileSize = 20           -- Size of each cell in studs (X and Z)
MazeConfig.WallHeight = 14         -- Wall height in studs
MazeConfig.WallThickness = 2       -- Wall thickness in studs
MazeConfig.FloorThickness = 1      -- Floor slab thickness

--------------------------------------------------------------------------------
-- Materials & Colors (Dark / Gloomy / Industrial aesthetic)
--------------------------------------------------------------------------------

MazeConfig.FloorMaterial = Enum.Material.Concrete     -- Dirty concrete
MazeConfig.FloorColor = Color3.fromRGB(60, 55, 45)    -- Dark stained floor

MazeConfig.WallMaterial = Enum.Material.SmoothPlastic
MazeConfig.WallColor = Color3.fromRGB(70, 68, 60)     -- Grimy dark walls

MazeConfig.CeilingMaterial = Enum.Material.SmoothPlastic
MazeConfig.CeilingColor = Color3.fromRGB(40, 38, 35)  -- Nearly black ceiling

--------------------------------------------------------------------------------
-- Lighting (dim, failing fluorescent ceiling lights)
--------------------------------------------------------------------------------

MazeConfig.LightSpacing = 3         -- Place a light every N cells (sparser)
MazeConfig.LightBrightness = 0.35
MazeConfig.LightRange = 12
MazeConfig.LightColor = Color3.fromRGB(160, 140, 90) -- Sickly yellowish

-- Flicker settings (most lights flicker or are dead)
MazeConfig.FlickerChance = 0.6      -- 60% of lights will flicker
MazeConfig.FlickerMinInterval = 0.05 -- Very fast flickers
MazeConfig.FlickerMaxInterval = 3.0 -- Long dead periods

--------------------------------------------------------------------------------
-- Loot Spawning
--------------------------------------------------------------------------------

MazeConfig.MinLootSpawns = 8        -- Minimum items per maze
MazeConfig.MaxLootSpawns = 12       -- Maximum items per maze
MazeConfig.LootHeightOffset = 2     -- Studs above floor to float loot

--------------------------------------------------------------------------------
-- Maze Origin (where mazes generate in world space)
-- Each player gets their own maze offset to avoid overlap
--------------------------------------------------------------------------------

MazeConfig.MazeOriginBase = Vector3.new(500, 0, 500)   -- Base position
MazeConfig.PlayerMazeSpacing = 500  -- Studs between player maze instances

--------------------------------------------------------------------------------
-- Hub & Exit
--------------------------------------------------------------------------------

MazeConfig.HubSpawnPosition = Vector3.new(0, 5, 0) -- Return-to-hub position
MazeConfig.ExitPromptText = "Extract with Loot"

table.freeze(MazeConfig)
return MazeConfig
