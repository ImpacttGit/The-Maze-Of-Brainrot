--[[
    PlayerManager.lua
    =================
    Server Script — manages per-player state for The Maze of Brainrot.
    
    Responsibilities:
        - Initialize inventory + playerData on PlayerAdded
        - Create leaderstats (Fragments shown on leaderboard)
        - Fire remote updates to client HUD on data changes
        - Expose API for other server scripts to read/modify player state
        - Clean up on PlayerRemoving
    
    Dependencies:
        - InventoryService (Phase 1)
        - FragmentService (Phase 1)
        - RemoteEvents
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

-- Wait for modules to be available
local Modules = ReplicatedStorage:WaitForChild("Modules")
local InventoryService = require(Modules.Services.InventoryService)
local FragmentService = require(Modules.Services.FragmentService)
local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))

local PlayerManager = {}

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local MAX_INVENTORY_SLOTS = 99  -- Total inventory capacity
local MAZE_BACKPACK_SLOTS = 5   -- Backpack limit while in the maze

--------------------------------------------------------------------------------
-- In-memory player data store
-- { [UserId] = { playerData, inventory, player } }
--------------------------------------------------------------------------------

local PlayerDataStore = {}
local playersInMaze = {} -- { [UserId] = true } tracks who is currently in the maze

--------------------------------------------------------------------------------
-- DataStore
--------------------------------------------------------------------------------

local DATA_STORE_NAME = "PlayerData_v1"
local AUTO_SAVE_INTERVAL = 300 -- 5 minutes
local MAX_RETRIES = 3

local playerDataStore = nil
pcall(function()
    playerDataStore = DataStoreService:GetDataStore(DATA_STORE_NAME)
end)

-- Save player data to DataStore (fragments + Legendary items only)
local function savePlayerData(player: Player)
    if not playerDataStore then return end

    local entry = PlayerDataStore[player.UserId]
    if not entry then return end

    local legendaryItems = {}
    local allItems = entry.inventory:getAllItems()
    for _, item in ipairs(allItems) do
        if item.Rarity == "Legendary" then
            table.insert(legendaryItems, {
                UniqueId = item.UniqueId,
                ItemId = item.ItemId,
                DisplayName = item.DisplayName,
                Rarity = item.Rarity,
                FragmentValue = item.FragmentValue,
                IsFollower = item.IsFollower,
            })
        end
    end

    local saveData = {
        fragments = entry.playerData.fragments,
        legendaryItems = legendaryItems,
    }

    for attempt = 1, MAX_RETRIES do
        local success, err = pcall(function()
            playerDataStore:SetAsync(tostring(player.UserId), saveData)
        end)
        if success then
            print("[PlayerManager] Saved data for " .. player.Name)
            return
        else
            warn("[PlayerManager] Save failed (attempt " .. attempt .. "): " .. tostring(err))
            if attempt < MAX_RETRIES then task.wait(1) end
        end
    end
end

-- Load player data from DataStore
local function loadPlayerData(player: Player): (number, { any })
    if not playerDataStore then return 0, {} end

    local fragments = 0
    local legendaryItems = {}

    for attempt = 1, MAX_RETRIES do
        local success, result = pcall(function()
            return playerDataStore:GetAsync(tostring(player.UserId))
        end)
        if success then
            if result then
                fragments = result.fragments or 0
                legendaryItems = result.legendaryItems or {}
            end
            return fragments, legendaryItems
        else
            warn("[PlayerManager] Load failed (attempt " .. attempt .. "): " .. tostring(result))
            if attempt < MAX_RETRIES then task.wait(1) end
        end
    end

    return fragments, legendaryItems
end

--------------------------------------------------------------------------------
-- INTERNAL: Send HUD updates to the client
--------------------------------------------------------------------------------

local function pushFragmentUpdate(player: Player, playerData: any)
    local balance = FragmentService.getBalance(playerData)
    Remotes.UpdateFragments:FireClient(player, balance)

    -- Also update the leaderstats IntValue
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local fragmentsStat = leaderstats:FindFirstChild("Fragments")
        if fragmentsStat then
            fragmentsStat.Value = balance
        end
    end
end

local function getEffectiveMaxSlots(player: Player): number
    if playersInMaze[player.UserId] then
        return MAZE_BACKPACK_SLOTS
    end
    return MAX_INVENTORY_SLOTS
end

local function pushInventoryUpdate(player: Player, inventory: any)
    local count = inventory:getCount()
    Remotes.UpdateInventory:FireClient(player, count, getEffectiveMaxSlots(player))
end

local function pushBatteryUpdate(player: Player, batteryPercent: number)
    Remotes.UpdateBattery:FireClient(player, batteryPercent)
end

--------------------------------------------------------------------------------
-- Player Initialization
--------------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
    -- Load saved data
    local savedFragments, savedLegendaries = loadPlayerData(player)

    -- Create the player data table (used by FragmentService)
    local playerData = {
        fragments = savedFragments,
    }

    -- Create a fresh inventory and restore Legendaries
    local inventory = InventoryService.new()
    for _, item in ipairs(savedLegendaries) do
        inventory:addItem(item)
    end

    -- Store in our in-memory dictionary
    PlayerDataStore[player.UserId] = {
        playerData = playerData,
        inventory = inventory,
        player = player,
    }

    -- Create leaderstats folder for the Roblox leaderboard
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local fragmentsStat = Instance.new("IntValue")
    fragmentsStat.Name = "Fragments"
    fragmentsStat.Value = savedFragments
    fragmentsStat.Parent = leaderstats

    -- Push initial HUD state to client (slight delay so client scripts load)
    task.spawn(function()
        task.wait(1)
        if player.Parent then -- Player might have left
            pushFragmentUpdate(player, playerData)
            pushInventoryUpdate(player, inventory)
            pushBatteryUpdate(player, 100) -- Full battery on join
        end
    end)

    print("[PlayerManager] Initialized data for " .. player.Name ..
        " (Fragments: " .. savedFragments .. ", Legendaries: " .. #savedLegendaries .. ")")
end

--------------------------------------------------------------------------------
-- Player Cleanup
--------------------------------------------------------------------------------

local function onPlayerRemoving(player: Player)
    local entry = PlayerDataStore[player.UserId]
    if entry then
        savePlayerData(player)
        print("[PlayerManager] Cleaned up data for " .. player.Name)
    end
    PlayerDataStore[player.UserId] = nil
end

--------------------------------------------------------------------------------
-- Connect events
--------------------------------------------------------------------------------

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle players who joined before this script ran (Studio fast-start)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end

-- Auto-save loop (every 5 minutes)
task.spawn(function()
    while true do
        task.wait(AUTO_SAVE_INTERVAL)
        for _, player in ipairs(Players:GetPlayers()) do
            task.spawn(savePlayerData, player)
        end
        print("[PlayerManager] Auto-save complete for " .. #Players:GetPlayers() .. " players")
    end
end)

--------------------------------------------------------------------------------
-- PUBLIC API (for other server scripts to use)
--------------------------------------------------------------------------------

-- Get the raw data entry for a player
function PlayerManager.getData(player: Player): any?
    local entry = PlayerDataStore[player.UserId]
    return entry and entry.playerData or nil
end

-- Get the Inventory object for a player
function PlayerManager.getInventory(player: Player): any?
    local entry = PlayerDataStore[player.UserId]
    return entry and entry.inventory or nil
end

-- Get the max inventory capacity
function PlayerManager.getMaxSlots(player: Player?): number
    if player and playersInMaze[player.UserId] then
        return MAZE_BACKPACK_SLOTS
    end
    return MAX_INVENTORY_SLOTS
end

-- Track maze state for backpack limits
function PlayerManager.setInMaze(player: Player, inMaze: boolean)
    playersInMaze[player.UserId] = inMaze or nil
    -- Push updated inventory display with new capacity
    local entry = PlayerDataStore[player.UserId]
    if entry then
        pushInventoryUpdate(player, entry.inventory)
    end
end

function PlayerManager.isInMaze(player: Player): boolean
    return playersInMaze[player.UserId] == true
end

-- Get a list of all items for client display
function PlayerManager.getInventoryList(player: Player): { any }
    local entry = PlayerDataStore[player.UserId]
    if not entry then return {} end

    local items = entry.inventory:getAllItems()
    local list = {}
    for _, item in ipairs(items) do
        table.insert(list, {
            UniqueId = item.UniqueId,
            ItemId = item.ItemId,
            DisplayName = item.DisplayName,
            Rarity = item.Rarity,
            FragmentValue = item.FragmentValue,
        })
    end
    return list
end

-- Add fragments and push update to client
function PlayerManager.addFragments(player: Player, amount: number): number?
    local entry = PlayerDataStore[player.UserId]
    if not entry then return nil end

    local newBalance = FragmentService.addFragments(entry.playerData, amount)
    pushFragmentUpdate(player, entry.playerData)
    return newBalance
end

-- Spend fragments and push update to client
function PlayerManager.spendFragments(player: Player, amount: number): boolean
    local entry = PlayerDataStore[player.UserId]
    if not entry then return false end

    local success = FragmentService.spendFragments(entry.playerData, amount)
    if success then
        pushFragmentUpdate(player, entry.playerData)
    end
    return success
end

-- Add an item to the player's inventory
function PlayerManager.addItem(player: Player, itemInstance: any): boolean
    local entry = PlayerDataStore[player.UserId]
    if not entry then return false end

    -- Check capacity (uses backpack limit if in maze)
    local maxSlots = getEffectiveMaxSlots(player)
    if entry.inventory:getCount() >= maxSlots then
        warn("[PlayerManager] Inventory full for " .. player.Name .. " (" .. maxSlots .. " slots)")
        return false
    end

    local added = entry.inventory:addItem(itemInstance)
    if added then
        pushInventoryUpdate(player, entry.inventory)
    end
    return added
end

-- Remove an item from the player's inventory
function PlayerManager.removeItem(player: Player, uniqueId: string): any?
    local entry = PlayerDataStore[player.UserId]
    if not entry then return nil end

    local item = entry.inventory:removeItem(uniqueId)
    if item then
        pushInventoryUpdate(player, entry.inventory)
    end
    return item
end

-- Sell an item: remove from inventory, add fragment value
function PlayerManager.sellItem(player: Player, uniqueId: string): (number, boolean)
    local entry = PlayerDataStore[player.UserId]
    if not entry then return 0, false end

    local item = entry.inventory:getItem(uniqueId)
    if not item then return 0, false end

    local earned, success = FragmentService.sellItem(entry.playerData, item)
    if success then
        entry.inventory:removeItem(uniqueId)
        pushFragmentUpdate(player, entry.playerData)
        pushInventoryUpdate(player, entry.inventory)
    end
    return earned, success
end

-- Sell ALL non-Legendary items at once (atomic bulk operation)
function PlayerManager.sellAllItems(player: Player): (number, number)
    local entry = PlayerDataStore[player.UserId]
    if not entry then return 0, 0 end

    local allItems = entry.inventory:getAllItems()
    local totalEarned = 0
    local soldCount = 0

    -- First pass: calculate total and collect ids to remove
    local toRemove = {}
    for _, item in ipairs(allItems) do
        if item.Rarity ~= "Legendary" then
            local value = item.FragmentValue or 0
            totalEarned += value
            soldCount += 1
            table.insert(toRemove, item.UniqueId)
        end
    end

    -- Second pass: remove all items and add fragments in one go
    if soldCount > 0 then
        for _, uid in ipairs(toRemove) do
            entry.inventory:removeItem(uid)
        end
        FragmentService.addFragments(entry.playerData, totalEarned)
        pushFragmentUpdate(player, entry.playerData)
        pushInventoryUpdate(player, entry.inventory)
    end

    return totalEarned, soldCount
end

-- Clear non-legendary items (called on death)
function PlayerManager.onPlayerDeath(player: Player): { any }
    local entry = PlayerDataStore[player.UserId]
    if not entry then return {} end

    local removed = entry.inventory:clearNonLegendary()
    pushInventoryUpdate(player, entry.inventory)
    return removed
end

-- Update flashlight battery and push to client
function PlayerManager.setBattery(player: Player, percent: number)
    -- Battery state is transient — no need to persist
    pushBatteryUpdate(player, math.clamp(percent, 0, 100))
end

-- Make the module accessible to other server scripts via a BindableFunction
-- (Alternative: other scripts can require() this ModuleScript directly)
local ApiBindable = Instance.new("BindableFunction")
ApiBindable.Name = "PlayerManagerAPI"
ApiBindable.Parent = game:GetService("ServerScriptService")
ApiBindable.OnInvoke = function(action, ...)
    if PlayerManager[action] then
        return PlayerManager[action](...)
    end
    warn("[PlayerManager] Unknown API action: " .. tostring(action))
    return nil
end

return PlayerManager
