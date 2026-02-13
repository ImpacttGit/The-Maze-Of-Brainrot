--[[
    LootSpawner.lua
    ===============
    Server Script — spawns physical loot items within a generated maze.
    
    Creates visible Part models with rarity-colored outlines, name tags,
    and ProximityPrompts for player pickup.
    
    Dependencies:
        - LootService (item generation)
        - RarityConfig (outline colors)
        - MazeGenerator (spawn node positions)
        - MazeConfig (loot counts)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local LootService = require(Modules.Services.LootService)
local RarityConfig = require(Modules.Data.RarityConfig)
local MazeConfig = require(Modules.Data.MazeConfig)

local HttpService = game:GetService("HttpService")

local LootSpawner = {}

--------------------------------------------------------------------------------
-- INTERNAL: Create a single loot Part in the world
--------------------------------------------------------------------------------

function LootSpawner.createLootPart(itemInstance: any, spawnCFrame: CFrame, folder: Folder): Part
    local rarityTier = RarityConfig.Tiers[itemInstance.Rarity]

    -- Base part (small collectible-looking box)
    local part = Instance.new("Part")
    part.Name = "Loot_" .. itemInstance.ItemId
    part.Size = Vector3.new(2, 2, 2)
    part.CFrame = spawnCFrame
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.SmoothPlastic
    part.Color = rarityTier.OutlineColor
    part.Shape = Enum.PartType.Block
    part.Parent = folder

    -- Store item data as Attributes (server reads these on pickup)
    local lootId = itemInstance.LootId or HttpService:GenerateGUID(false)
    part:SetAttribute("LootId", lootId)
    part:SetAttribute("ItemId", itemInstance.ItemId)
    part:SetAttribute("DisplayName", itemInstance.DisplayName)
    part:SetAttribute("Rarity", itemInstance.Rarity)
    part:SetAttribute("FragmentValue", itemInstance.FragmentValue or 0)
    part:SetAttribute("IsFollower", itemInstance.IsFollower)

    -- Rarity outline glow (SelectionBox)
    local selectionBox = Instance.new("SelectionBox")
    selectionBox.Adornee = part
    selectionBox.Color3 = rarityTier.OutlineColor
    selectionBox.LineThickness = 0.05
    selectionBox.SurfaceTransparency = 0.7
    selectionBox.SurfaceColor3 = rarityTier.OutlineColor
    selectionBox.Parent = part

    -- Billboard name tag
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 180, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = false
    billboard.MaxDistance = 30
    billboard.Parent = part

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.6, 0)
    nameLabel.Position = UDim2.new(0, 0, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = itemInstance.DisplayName
    nameLabel.TextColor3 = rarityTier.OutlineColor
    nameLabel.TextSize = 14
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextStrokeTransparency = 0.5
    nameLabel.Parent = billboard

    local rarityLabel = Instance.new("TextLabel")
    rarityLabel.Size = UDim2.new(1, 0, 0.4, 0)
    rarityLabel.Position = UDim2.new(0, 0, 0.6, 0)
    rarityLabel.BackgroundTransparency = 1
    rarityLabel.Text = itemInstance.Rarity
    rarityLabel.TextColor3 = rarityTier.OutlineColor
    rarityLabel.TextSize = 10
    rarityLabel.Font = Enum.Font.GothamMedium
    rarityLabel.TextStrokeTransparency = 0.7
    rarityLabel.Parent = billboard

    -- ProximityPrompt for pickup
    local prompt = Instance.new("ProximityPrompt")
    prompt.ObjectText = itemInstance.DisplayName
    prompt.ActionText = "Pick Up"
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 8
    prompt.Parent = part

    -- Slow rotation animation
    task.spawn(function()
        while part and part.Parent do
            part.CFrame = part.CFrame * CFrame.Angles(0, math.rad(1), 0)
            task.wait(0.03)
        end
    end)

    -- LEGENDARY: Extra gold effects
    if itemInstance.Rarity == "Legendary" then
        local goldLight = Instance.new("PointLight")
        goldLight.Brightness = 3
        goldLight.Range = 25
        goldLight.Color = Color3.fromRGB(255, 215, 0)
        goldLight.Parent = part

        -- Gold shimmer particles
        local particles = Instance.new("ParticleEmitter")
        particles.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0))
        particles.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.3),
            NumberSequenceKeypoint.new(1, 0),
        })
        particles.Lifetime = NumberRange.new(0.5, 1.5)
        particles.Rate = 20
        particles.Speed = NumberRange.new(1, 3)
        particles.SpreadAngle = Vector2.new(180, 180)
        particles.LightEmission = 1
        particles.Parent = part
    end

    -- EPIC: Purple glow
    if itemInstance.Rarity == "Epic" then
        local purpleLight = Instance.new("PointLight")
        purpleLight.Brightness = 2
        purpleLight.Range = 15
        purpleLight.Color = Color3.fromRGB(163, 53, 238)
        purpleLight.Parent = part
    end

    -- RARE: Subtle blue glow
    if itemInstance.Rarity == "Rare" then
        local blueLight = Instance.new("PointLight")
        blueLight.Brightness = 1
        blueLight.Range = 10
        blueLight.Color = Color3.fromRGB(0, 120, 255)
        blueLight.Parent = part
    end

    return part
end

--------------------------------------------------------------------------------
-- PUBLIC: Spawn loot items throughout a maze
-- @param mazeFolder — the maze Folder in Workspace
-- @param grid — the maze grid from MazeGenerator
-- @param origin — the maze world origin
-- @param luckMultiplier — optional luck from game pass
-- @return { itemInstances }, { lootParts }
--------------------------------------------------------------------------------

function LootSpawner.spawnLoot(mazeFolder: Folder, grid: any, origin: Vector3, luckMultiplier: number?): ({ any }, { Part })
    -- Determine loot count
    local count = math.random(MazeConfig.MinLootSpawns, MazeConfig.MaxLootSpawns)

    -- Get spawn positions from the maze
    local MazeGenerator = require(game:GetService("ServerScriptService"):WaitForChild("MazeGenerator"))
    local spawnNodes = MazeGenerator.getSpawnNodes(grid, origin, count)

    -- Generate items via LootService
    local items = LootService.generateLootTable(#spawnNodes, luckMultiplier)

    -- Create a sub-folder for loot inside the maze folder
    local lootFolder = Instance.new("Folder")
    lootFolder.Name = "Loot"
    lootFolder.Parent = mazeFolder

    -- Spawn each item at its position
    local lootParts = {}
    for i, itemInstance in ipairs(items) do
        local spawnCFrame = spawnNodes[i]
        if spawnCFrame then
            local part = LootSpawner.createLootPart(itemInstance, spawnCFrame, lootFolder)
            table.insert(lootParts, part)
        end
    end

    print("[LootSpawner] Spawned " .. #lootParts .. " loot items in " .. mazeFolder.Name)
    return items, lootParts
end

return LootSpawner
