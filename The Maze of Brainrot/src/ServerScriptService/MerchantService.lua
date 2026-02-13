--[[
    MerchantService.lua
    ===================
    Server Script — handles the Merchant NPC in the Hub.
    
    Creates a physical NPC with ProximityPrompt. When interacted with,
    sends inventory data to client for the sell UI.
    
    Also handles sell requests (single item and sell-all).
    
    Dependencies:
        - PlayerManager
        - FragmentService
        - RemoteEvents
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local RarityConfig = require(Modules.Data.RarityConfig)
local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))

local PlayerManager = require(ServerScriptService:WaitForChild("PlayerManager"))

--------------------------------------------------------------------------------
-- Create Merchant NPC in the Hub
--------------------------------------------------------------------------------

local MERCHANT_NAME = "Merchant"

local function createMerchantNPC()
    if Workspace:FindFirstChild(MERCHANT_NAME) then return end

    local npc = Instance.new("Part")
    npc.Name = MERCHANT_NAME
    npc.Size = Vector3.new(4, 8, 4)
    npc.Position = Vector3.new(-25, 4.5, 23) -- Matches LobbyBuilder visual
    npc.Anchored = true
    npc.CanCollide = true
    npc.Transparency = 1 -- Invisible hitbox
    npc.Parent = Workspace

    -- Prompt
    local prompt = Instance.new("ProximityPrompt")
    prompt.ObjectText = "Fragment Merchant"
    prompt.ActionText = "Open Shop"
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false -- Ensure accessible through counter
    prompt.Parent = npc

    -- Note: LobbyBuilder creates the visual NPC and Billboard
    print("[MerchantService] Created Merchant Interaction Point at " .. tostring(npc.Position))

    -- Connect prompt
    prompt.Triggered:Connect(function(player)
        sendInventoryData(player)
        Remotes.OpenMerchant:FireClient(player)
    end)

    print("[MerchantService] Created Merchant NPC at " .. tostring(npc.Position))
end

--------------------------------------------------------------------------------
-- Send player's inventory data to client
--------------------------------------------------------------------------------

function sendInventoryData(player: Player)
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
            IsFollower = item.IsFollower,
        })
    end

    Remotes.InventoryData:FireClient(player, serialized)
end

--------------------------------------------------------------------------------
-- Handle Sell Single Item
--------------------------------------------------------------------------------

Remotes.RequestSellItem.OnServerEvent:Connect(function(player: Player, uniqueId: string)
    if not PlayerManager then return end
    if typeof(uniqueId) ~= "string" then return end

    local earned, success = PlayerManager.sellItem(player, uniqueId)
    if success then
        Remotes.SellResult:FireClient(player, true, earned, "Item sold for " .. earned .. " fragments!")
        -- Refresh inventory data for the UI
        sendInventoryData(player)
    else
        Remotes.SellResult:FireClient(player, false, 0, "Cannot sell this item.")
    end
end)

--------------------------------------------------------------------------------
-- Handle Sell All (non-Legendary)
--------------------------------------------------------------------------------

Remotes.RequestSellAll.OnServerEvent:Connect(function(player: Player)
    if not PlayerManager then return end

    local totalEarned, soldCount = PlayerManager.sellAllItems(player)

    Remotes.SellResult:FireClient(player, true, totalEarned,
        "Sold " .. soldCount .. " items for " .. totalEarned .. " fragments!")

    -- Refresh inventory data
    sendInventoryData(player)

    print("[MerchantService] " .. player.Name .. " sold " .. soldCount .. " items for " .. totalEarned)
end)

--------------------------------------------------------------------------------
-- Handle general inventory data requests
--------------------------------------------------------------------------------

Remotes.RequestInventoryData.OnServerEvent:Connect(function(player: Player)
    sendInventoryData(player)
end)

--------------------------------------------------------------------------------
-- Initialize
--------------------------------------------------------------------------------

createMerchantNPC()
print("[MerchantService] Initialized")

local MerchantService = {}
return MerchantService
