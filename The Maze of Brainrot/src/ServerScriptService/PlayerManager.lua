--[[
    PlayerManager.lua
    =================
    Server Script — manages per-player state for The Maze of Brainrot.
    
    Responsibilities:
        - Initialize inventory + playerData on PlayerAdded
        - Handle save/load via DataStoreService
        - Expose API for inventory management (add/remove/sell)
        - Manage XP, Level, and Prestige progression
    
    Dependencies:
        - InventoryService (class)
        - FragmentService (module)
        - RemoteEvents (ReplicatedStorage)
        - FollowerService (Server)
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local InventoryService = require(Modules.Services.InventoryService)
local FragmentService = require(Modules.Services.FragmentService)
local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))
local BadgeHandler = require(ServerScriptService:WaitForChild("BadgeHandler"))

local PlayerManager = {}

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local MAX_INVENTORY_SLOTS = 99  -- Total inventory capacity
local MAZE_BACKPACK_SLOTS = 5   -- Backpack limit while in the maze

--------------------------------------------------------------------------------
-- Progression Constants
--------------------------------------------------------------------------------

local MAX_LEVEL = 50
local XP_PER_LEVEL_BASE = 150 -- xp needed = level * 150

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

-- Save player data to DataStore
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
        xp = entry.playerData.xp,
        level = entry.playerData.level,
        prestige = entry.playerData.prestige,
        totalMazeRuns = entry.playerData.totalMazeRuns,
        dailyRewardData = entry.playerData.dailyRewardData,
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
local function loadPlayerData(player: Player): (any)
    if not playerDataStore then return {} end

    local data = {}

    for attempt = 1, MAX_RETRIES do
        local success, result = pcall(function()
            return playerDataStore:GetAsync(tostring(player.UserId))
        end)
        if success then
            data = result or {}
            return data
        else
            warn("[PlayerManager] Load failed (attempt " .. attempt .. "): " .. tostring(result))
            if attempt < MAX_RETRIES then task.wait(1) end
        end
    end

    return data
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

local function pushProgressionUpdate(player: Player, playerData: any)
    Remotes.UpdateXP:FireClient(player, playerData.xp, playerData.level, playerData.prestige)
    
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local levelStat = leaderstats:FindFirstChild("Level")
        if levelStat then levelStat.Value = playerData.level end
        
        local prestigeStat = leaderstats:FindFirstChild("Prestige")
        if prestigeStat then prestigeStat.Value = playerData.prestige end
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
    local savedData = loadPlayerData(player)
    local savedLegendaries = savedData.legendaryItems or {}

    -- Create the player data table
    local playerData = {
        fragments = savedData.fragments or 0,
        xp = savedData.xp or 0,
        level = savedData.level or 1,
        prestige = savedData.prestige or 0,
        totalMazeRuns = savedData.totalMazeRuns or 0,
        dailyRewardData = savedData.dailyRewardData or {},
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
    fragmentsStat.Value = playerData.fragments
    fragmentsStat.Parent = leaderstats

    local levelStat = Instance.new("IntValue")
    levelStat.Name = "Level"
    levelStat.Value = playerData.level
    levelStat.Parent = leaderstats

    local prestigeStat = Instance.new("IntValue")
    prestigeStat.Name = "Prestige"
    prestigeStat.Value = playerData.prestige
    prestigeStat.Parent = leaderstats

    -- Spawn followers if any
    local FollowerService = require(ServerScriptService:WaitForChild("FollowerService"))
    FollowerService.updateFollowers(player)

    -- Push initial HUD state to client (slight delay so client scripts load)
    task.spawn(function()
        task.wait(1)
        if player.Parent then -- Player might have left
            pushFragmentUpdate(player, playerData)
            pushInventoryUpdate(player, inventory)
            pushProgressionUpdate(player, playerData)
            pushBatteryUpdate(player, 100) -- Full battery on join
        end
    end)

    print("[PlayerManager] Initialized data for " .. player.Name)
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
            IsFollower = item.IsFollower,
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

-- Add XP and handle leveling
function PlayerManager.addXP(player: Player, amount: number)
    local entry = PlayerDataStore[player.UserId]
    if not entry then return end
    
    local data = entry.playerData
    if data.level >= MAX_LEVEL then return end -- Cap at max level
    
    data.xp = data.xp + amount
    
    -- Check for level up
    local xpNeeded = data.level * XP_PER_LEVEL_BASE
    if data.xp >= xpNeeded then
        data.xp = data.xp - xpNeeded
        data.level = data.level + 1
        
        Remotes.UpdateLevel:FireClient(player, data.level)
        print("[PlayerManager] " .. player.Name .. " leveled up to " .. data.level)
    end
    
    pushProgressionUpdate(player, data)
end

-- Increment maze run count
function PlayerManager.incrementMazeRuns(player: Player)
    local entry = PlayerDataStore[player.UserId]
    if entry then
        entry.playerData.totalMazeRuns = (entry.playerData.totalMazeRuns or 0) + 1
    end
end

-- Prestige: Reset level, keep items, increment prestige
function PlayerManager.prestige(player: Player): boolean
    local entry = PlayerDataStore[player.UserId]
    if not entry then return false end
    
    local data = entry.playerData
    if data.level < MAX_LEVEL then return false end
    
    data.level = 1
    data.xp = 0
    data.prestige = data.prestige + 1
    
    savePlayerData(player)
    pushProgressionUpdate(player, data)
    Remotes.PrestigeUp:FireClient(player, data.prestige)
    
    if data.prestige >= 1 then
        BadgeHandler.award(player, "OfficeLegend")
    end
    
    print("[PlayerManager] " .. player.Name .. " prestiged to tier " .. data.prestige)
    return true
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
        
        -- Update followers if new item is a Legendary follower
        if itemInstance.Rarity == "Legendary" then
            BadgeHandler.award(player, "LegendaryCollector")
            if itemInstance.IsFollower then
                local FollowerService = require(ServerScriptService:WaitForChild("FollowerService"))
                FollowerService.updateFollowers(player)
            end
        end
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
        
        -- Update followers if removed item was a Legendary follower
        if item.Rarity == "Legendary" and item.IsFollower then
            local FollowerService = require(ServerScriptService:WaitForChild("FollowerService"))
            FollowerService.updateFollowers(player)
        end
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
    
    -- Increment death count if tracked, etc.
    if entry.playerData.totalDeaths then
        entry.playerData.totalDeaths = entry.playerData.totalDeaths + 1
    end

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

-- Listen for client prestige request
Remotes.RequestPrestige.OnServerEvent:Connect(function(player)
    PlayerManager.prestige(player)
end)

return PlayerManager
