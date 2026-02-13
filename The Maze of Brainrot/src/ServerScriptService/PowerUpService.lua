--[[
    PowerUpService.lua
    ==================
    Server Service — handles the usage of Epic Power-Up items.
    
    1. Listens for RequestEquipItem from client.
    2. Validates ownership and item type.
    3. Consumes item from inventory.
    4. Triggers server-side effects (e.g. Distraction).
    5. Fires ApplyPowerUp to client for visual/local effects.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))
local ItemDatabase = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Data"):WaitForChild("ItemDatabase"))

local PlayerManager = require(ServerScriptService:WaitForChild("PlayerManager"))
local EntityManager = require(ServerScriptService:WaitForChild("EntityManager"))

local PowerUpService = {}

--------------------------------------------------------------------------------
-- Power-Up Logic
--------------------------------------------------------------------------------

local function handleEquipRequest(player, uniqueId)
    local inventory = PlayerManager.getInventory(player)
    if not inventory then return end

    local item = inventory:getItem(uniqueId)
    if not item then
        Remotes.EquipItemResult:FireClient(player, false, "Item not found")
        return
    end

    -- Validate Item Type
    if item.Rarity ~= "Epic" then
        Remotes.EquipItemResult:FireClient(player, false, "Only Epic items can be used!")
        return
    end
    
    local dbItem = ItemDatabase.getItem(item.ItemId)
    if not dbItem or not dbItem.PowerUp then
        Remotes.EquipItemResult:FireClient(player, false, "This item has no power-up!")
        return
    end

    -- CONSUME ITEM
    local removedInfo = PlayerManager.removeItem(player, uniqueId)
    if not removedInfo then
        Remotes.EquipItemResult:FireClient(player, false, "Failed to consume item")
        return
    end

    -- TRIGGER EFFECTS
    local powerUp = dbItem.PowerUp
    print("[PowerUpService] " .. player.Name .. " used " .. item.DisplayName)

    -- 1. Server-Side Logic
    if powerUp.Type == "SoundDecoy" then
        if player.Character and player.Character.PrimaryPart then
            -- Trigger distraction at player's current location
            local position = player.Character.PrimaryPart.Position
            -- Distract entities
            EntityManager.triggerDistraction(player, position, powerUp.DecoyDuration or 10)
        end
    elseif powerUp.Type == "LightDisruption" then
        -- Optional: Could disable lights server-side here. 
        -- For now, we rely on client visuals, but we could fire to ALL clients if we wanted global blackout.
        -- Remotes.GlobalEffect:FireAllClients("LightDisrupt", ...)
    end

    -- 2. Client-Side Visuals/Logic
    Remotes.ApplyPowerUp:FireClient(player, powerUp, item.DisplayName)
    Remotes.EquipItemResult:FireClient(player, true, "Used " .. item.DisplayName)
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

function PowerUpService.init()
    Remotes.RequestEquipItem.OnServerEvent:Connect(function(player, uniqueId)
        handleEquipRequest(player, uniqueId)
    end)
    print("[PowerUpService] Initialized")
end

return PowerUpService
