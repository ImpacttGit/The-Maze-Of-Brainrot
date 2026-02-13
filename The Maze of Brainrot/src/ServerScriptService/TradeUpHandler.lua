--[[
    TradeUpHandler.lua
    ==================
    Server Script — handles the Trade-Up Machine in the Hub.
    
    Creates a physical machine with ProximityPrompt. When interacted with,
    opens the trade-up UI on client. Server validates and executes trade-ups.
    
    Dependencies:
        - PlayerManager
        - TradeUpService
        - LootService
        - RemoteEvents
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local TradeUpService = require(Modules.Services.TradeUpService)
local LootService = require(Modules.Services.LootService)
local RarityConfig = require(Modules.Data.RarityConfig)
local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))

local PlayerManager = require(ServerScriptService:WaitForChild("PlayerManager"))

--------------------------------------------------------------------------------
-- Create Trade-Up Machine in the Hub
--------------------------------------------------------------------------------

local MACHINE_NAME = "TradeUpMachine"

local function createTradeUpMachine()
    if Workspace:FindFirstChild(MACHINE_NAME) then return end

    local machine = Instance.new("Part")
    machine.Name = MACHINE_NAME
    machine.Size = Vector3.new(6, 6, 6)
    machine.Position = Vector3.new(-25, 3, -20) -- Matches LobbyBuilder visual
    machine.Anchored = true
    machine.CanCollide = true
    machine.Transparency = 1 -- Invisible hitbox
    machine.Parent = Workspace

    -- Prompt
    local prompt = Instance.new("ProximityPrompt")
    prompt.ObjectText = "Trade-Up Machine"
    prompt.ActionText = "Open Trade-Up"
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.Parent = machine

    -- Note: LobbyBuilder creates the visual machine, billboard, and lights
    
    -- Connect prompt
    prompt.Triggered:Connect(function(player)
        -- Send inventory data then open trade-up UI
        sendTradeUpData(player)
        Remotes.OpenTradeUp:FireClient(player)
    end)

    print("[TradeUpHandler] Created Trade-Up Interaction Point at " .. tostring(machine.Position))
end

--------------------------------------------------------------------------------
-- Send trade-up-eligible data to client
-- Groups items by ItemId and shows counts
--------------------------------------------------------------------------------

function sendTradeUpData(player: Player)
    if not PlayerManager then return end

    local inventory = PlayerManager.getInventory(player)
    if not inventory then return end

    local items = inventory:getAllItems()
    local serialized = {}
    for _, item in ipairs(items) do
        table.insert(serialized, {
            UniqueId = item.UniqueId,
            ItemId = item.ItemId,
            DisplayName = item.DisplayName,
            Rarity = item.Rarity,
            FragmentValue = item.FragmentValue,
        })
    end

    Remotes.InventoryData:FireClient(player, serialized)
end

--------------------------------------------------------------------------------
-- Handle Trade-Up Request
-- Client sends: { itemId = string, uniqueIds = { string } (5 IDs) }
--------------------------------------------------------------------------------

Remotes.RequestTradeUp.OnServerEvent:Connect(function(player: Player, tradeData: any)
    if not PlayerManager then return end

    if typeof(tradeData) ~= "table" then
        Remotes.TradeUpResult:FireClient(player, false, nil, "Invalid request")
        return
    end

    local uniqueIds = tradeData.uniqueIds
    if typeof(uniqueIds) ~= "table" or #uniqueIds ~= 5 then
        Remotes.TradeUpResult:FireClient(player, false, nil, "Need exactly 5 items")
        return
    end

    -- Get player's inventory
    local inventory = PlayerManager.getInventory(player)
    if not inventory then
        Remotes.TradeUpResult:FireClient(player, false, nil, "No inventory")
        return
    end

    -- Gather the 5 items
    local items = {}
    for _, uid in ipairs(uniqueIds) do
        if typeof(uid) ~= "string" then
            Remotes.TradeUpResult:FireClient(player, false, nil, "Invalid item ID")
            return
        end
        local item = inventory:getItem(uid)
        if not item then
            Remotes.TradeUpResult:FireClient(player, false, nil, "Item not found: " .. uid)
            return
        end
        table.insert(items, item)
    end

    -- Validate trade-up eligibility
    local canTrade, reason = TradeUpService.canTradeUp(items)
    if not canTrade then
        Remotes.TradeUpResult:FireClient(player, false, nil, reason)
        return
    end

    -- Execute trade-up: remove 5 items, generate 1 new item of next rarity
    local sourceRarity = items[1].Rarity
    local nextTier = RarityConfig.getNextTier(sourceRarity)
    if not nextTier then
        Remotes.TradeUpResult:FireClient(player, false, nil, "No higher tier available")
        return
    end

    -- Remove the 5 items
    for _, item in ipairs(items) do
        PlayerManager.removeItem(player, item.UniqueId)
    end

    -- Generate the new item
    local newItem = LootService.generateItem(nextTier)

    -- Add to inventory
    local added = PlayerManager.addItem(player, newItem)
    if not added then
        -- Inventory full after removing 5? Shouldn't happen, but safeguard
        Remotes.TradeUpResult:FireClient(player, false, nil, "Inventory full!")
        return
    end

    -- Fire result to client
    Remotes.TradeUpResult:FireClient(player, true, {
        ItemId = newItem.ItemId,
        DisplayName = newItem.DisplayName,
        Rarity = newItem.Rarity,
        FragmentValue = newItem.FragmentValue,
    }, "Trade-up successful!")

    print("[TradeUpHandler] " .. player.Name .. " traded up 5x " .. items[1].DisplayName ..
        " → " .. newItem.DisplayName .. " (" .. newItem.Rarity .. ")")
end)

--------------------------------------------------------------------------------
-- Initialize
--------------------------------------------------------------------------------

createTradeUpMachine()
print("[TradeUpHandler] Initialized")

local TradeUpHandler = {}
return TradeUpHandler
