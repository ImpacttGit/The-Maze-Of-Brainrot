--[[
    Boot_Maze.server.lua
    ====================
    Auto-running Script — bootstraps the maze and combat systems.
    Also handles inventory data requests and item dropping.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))

print("[Boot_Maze] Starting maze systems...")

-- ElevatorService pulls in MazeGenerator, LootSpawner, EntityManager, 
-- DeathHandler, and PlayerManager as dependencies
local ElevatorService = require(ServerScriptService:WaitForChild("ElevatorService"))
print("[Boot_Maze] ElevatorService loaded ✓")

-- LootPickupHandler handles pickup validation
local LootPickupHandler = require(ServerScriptService:WaitForChild("LootPickupHandler"))
print("[Boot_Maze] LootPickupHandler loaded ✓")

local PlayerManager = require(ServerScriptService:WaitForChild("PlayerManager"))
local LootSpawner = require(ServerScriptService:WaitForChild("LootSpawner"))
local ItemDatabase = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Data"):WaitForChild("ItemDatabase"))

--------------------------------------------------------------------------------
-- Inventory Data Request Handler
-- Client presses G → fires RequestInventoryData → we send back the list
--------------------------------------------------------------------------------

Remotes.RequestInventoryData.OnServerEvent:Connect(function(player)
    local items = PlayerManager.getInventoryList(player)
    Remotes.InventoryData:FireClient(player, items)
end)

--------------------------------------------------------------------------------
-- Drop Item Handler
--------------------------------------------------------------------------------

Remotes.RequestDropItem.OnServerEvent:Connect(function(player, uniqueId: string)
    if not uniqueId or typeof(uniqueId) ~= "string" then
        Remotes.DropItemResult:FireClient(player, false, "Invalid item")
        return
    end

    local inventory = PlayerManager.getInventory(player)
    if not inventory then
        Remotes.DropItemResult:FireClient(player, false, "No inventory")
        return
    end

    local item = inventory:getItem(uniqueId)
    if not item then
        Remotes.DropItemResult:FireClient(player, false, "Item not found")
        return
    end

    local removed = PlayerManager.removeItem(player, uniqueId)
    if not removed then
        Remotes.DropItemResult:FireClient(player, false, "Failed to remove item")
        return
    end

    -- Spawn physical loot part at player's feet
    local character = player.Character
    if character then
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local droppedFolder = Workspace:FindFirstChild("DroppedLoot")
            if not droppedFolder then
                droppedFolder = Instance.new("Folder")
                droppedFolder.Name = "DroppedLoot"
                droppedFolder.Parent = Workspace
            end

            local dropCFrame = hrp.CFrame * CFrame.new(0, -2, -3)
            local itemData = {
                ItemId = removed.ItemId,
                DisplayName = removed.DisplayName,
                Rarity = removed.Rarity,
                FragmentValue = removed.FragmentValue or 0,
                IsFollower = removed.IsFollower,
            }
            LootSpawner.createLootPart(itemData, dropCFrame, droppedFolder)
        end
    end

    Remotes.DropItemResult:FireClient(player, true, "Dropped " .. removed.DisplayName)

    local items = PlayerManager.getInventoryList(player)
    Remotes.InventoryData:FireClient(player, items)

    print("[Boot_Maze] " .. player.Name .. " dropped " .. removed.DisplayName)
end)

--------------------------------------------------------------------------------
-- Equip Item Handler (Epic power-ups — consumed on use)
-- Client clicks EQUIP → fires RequestEquipItem(uniqueId)
-- Server validates, removes item, fires ApplyPowerUp to client
--------------------------------------------------------------------------------

Remotes.RequestEquipItem.OnServerEvent:Connect(function(player, uniqueId: string)
    if not uniqueId or typeof(uniqueId) ~= "string" then
        Remotes.EquipItemResult:FireClient(player, false, "Invalid item")
        return
    end

    -- Must be in maze to use power-ups
    if not PlayerManager.isInMaze(player) then
        Remotes.EquipItemResult:FireClient(player, false, "Can only use power-ups in the maze!")
        return
    end

    local inventory = PlayerManager.getInventory(player)
    if not inventory then
        Remotes.EquipItemResult:FireClient(player, false, "No inventory")
        return
    end

    local item = inventory:getItem(uniqueId)
    if not item then
        Remotes.EquipItemResult:FireClient(player, false, "Item not found")
        return
    end

    -- Look up the item definition to get PowerUp data
    local itemDef = ItemDatabase.getItem(item.ItemId)
    if not itemDef or not itemDef.PowerUp then
        Remotes.EquipItemResult:FireClient(player, false, "This item has no power-up!")
        return
    end

    -- Remove item from inventory (consumed)
    local removed = PlayerManager.removeItem(player, uniqueId)
    if not removed then
        Remotes.EquipItemResult:FireClient(player, false, "Failed to equip")
        return
    end

    -- Fire power-up data to client
    Remotes.EquipItemResult:FireClient(player, true, "Activated " .. removed.DisplayName .. "!")
    Remotes.ApplyPowerUp:FireClient(player, itemDef.PowerUp, removed.DisplayName)

    -- Refresh inventory
    local items = PlayerManager.getInventoryList(player)
    Remotes.InventoryData:FireClient(player, items)

    print("[Boot_Maze] " .. player.Name .. " equipped " .. removed.DisplayName .. " (" .. itemDef.PowerUp.Type .. ")")
end)

print("[Boot_Maze] All maze systems loaded ✓")
