--[[
    LootPickupHandler.lua
    =====================
    Server Script — validates and processes loot pickups from clients.
    
    Per-player loot: each loot part can be picked up once per player.
    The part stays in the world so other players can still collect it.
    When a player picks up loot, the part is hidden only for that player
    via the HideLootForPlayer remote.
    
    Dependencies:
        - PlayerManager (inventory management)
        - RarityConfig (for pickup effects data)
        - RemoteEvents
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local RarityConfig = require(Modules.Data.RarityConfig)
local ItemDatabase = require(Modules.Data.ItemDatabase)
local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))

local ServerScriptService = game:GetService("ServerScriptService")
local PlayerManager = require(ServerScriptService:WaitForChild("PlayerManager"))

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local MAX_PICKUP_DISTANCE = 20 -- Maximum studs to collect (anti-cheat)

--------------------------------------------------------------------------------
-- Per-player pickup tracking
-- collectedBy[lootPartId] = { [userId] = true }
--------------------------------------------------------------------------------

local collectedBy = {}

--------------------------------------------------------------------------------
-- INTERNAL: Validate pickup request
--------------------------------------------------------------------------------

local function validatePickup(player: Player, lootPart: Part): (boolean, string?)

    -- Check part exists
    if not lootPart or not lootPart.Parent then
        return false, "Item no longer exists"
    end

    -- Check this player hasn't already collected it
    local lootId = lootPart:GetAttribute("LootId")
    if lootId and collectedBy[lootId] and collectedBy[lootId][player.UserId] then
        return false, "Already collected"
    end

    -- Check player character exists
    local character = player.Character
    if not character then
        return false, "No character"
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return false, "No HumanoidRootPart"
    end

    -- Check distance (anti-cheat)
    local distance = (hrp.Position - lootPart.Position).Magnitude
    if distance > MAX_PICKUP_DISTANCE then
        return false, "Too far away"
    end

    -- Check item has required attributes
    if not lootPart:GetAttribute("ItemId") or not lootPart:GetAttribute("LootId") then
        return false, "Invalid loot item"
    end

    return true, nil
end

--------------------------------------------------------------------------------
-- INTERNAL: Process a valid pickup (per-player)
--------------------------------------------------------------------------------

local function processPickup(player: Player, lootPart: Part)
    local lootId = lootPart:GetAttribute("LootId")

    -- Mark as collected for this player
    if not collectedBy[lootId] then
        collectedBy[lootId] = {}
    end
    collectedBy[lootId][player.UserId] = true

    -- Reconstruct the item instance from Part attributes
    local itemId = lootPart:GetAttribute("ItemId")
    local itemDef = ItemDatabase.getItem(itemId)

    local itemInstance = {
        UniqueId = lootId .. "_" .. tostring(player.UserId), -- Unique per player
        ItemId = itemId,
        DisplayName = lootPart:GetAttribute("DisplayName"),
        Rarity = lootPart:GetAttribute("Rarity"),
        FragmentValue = lootPart:GetAttribute("FragmentValue"),
        IsFollower = lootPart:GetAttribute("IsFollower"),
        PowerUp = itemDef and itemDef.PowerUp or nil,
    }

    -- Try to add to inventory
    local added = PlayerManager.addItem(player, itemInstance)
    if not added then
        -- Inventory full — undo collection mark
        collectedBy[lootId][player.UserId] = nil
        Remotes.LootPickupResult:FireClient(player, false, "Inventory full!", nil)
        return
    end

    -- Hide the loot part for this player only
    Remotes.HideLootForPlayer:FireClient(player, lootPart)

    -- Notify client with item data for HUD notification
    Remotes.LootPickupResult:FireClient(player, true, "Picked up " .. itemInstance.DisplayName, {
        ItemId = itemInstance.ItemId,
        DisplayName = itemInstance.DisplayName,
        Rarity = itemInstance.Rarity,
        FragmentValue = itemInstance.FragmentValue,
    })

    print("[LootPickupHandler] " .. player.Name .. " picked up " ..
        itemInstance.DisplayName .. " (" .. itemInstance.Rarity .. ")")
end

--------------------------------------------------------------------------------
-- Listen for LootPickup remote from clients
--------------------------------------------------------------------------------

Remotes.LootPickup.OnServerEvent:Connect(function(player: Player, lootPart: any)
    if not lootPart or not lootPart:IsA("BasePart") then
        Remotes.LootPickupResult:FireClient(player, false, "Invalid pickup target", nil)
        return
    end

    local valid, errMsg = validatePickup(player, lootPart)
    if not valid then
        Remotes.LootPickupResult:FireClient(player, false, errMsg, nil)
        return
    end

    processPickup(player, lootPart)
end)

--------------------------------------------------------------------------------
-- Handle ProximityPrompt triggers directly (server-side detection)
--------------------------------------------------------------------------------

local function onPromptTriggered(prompt: ProximityPrompt, player: Player)
    local lootPart = prompt.Parent
    if not lootPart or not lootPart:IsA("BasePart") then return end
    if not lootPart:GetAttribute("ItemId") then return end

    local valid, errMsg = validatePickup(player, lootPart)
    if not valid then
        Remotes.LootPickupResult:FireClient(player, false, errMsg, nil)
        return
    end

    processPickup(player, lootPart)
end

-- Connect to all existing and future ProximityPrompts in Workspace
Workspace.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("ProximityPrompt") then
        task.wait() -- Let attributes load
        local parent = descendant.Parent
        if parent and parent:GetAttribute("ItemId") then
            descendant.Triggered:Connect(function(player)
                onPromptTriggered(descendant, player)
            end)
        end
    end
end)

--------------------------------------------------------------------------------
-- Cleanup tracking when maze is destroyed
--------------------------------------------------------------------------------

Workspace.DescendantRemoving:Connect(function(descendant)
    if descendant:IsA("BasePart") then
        local lootId = descendant:GetAttribute("LootId")
        if lootId and collectedBy[lootId] then
            collectedBy[lootId] = nil
        end
    end
end)

print("[LootPickupHandler] Initialized")

local LootPickupHandler = {}
return LootPickupHandler
