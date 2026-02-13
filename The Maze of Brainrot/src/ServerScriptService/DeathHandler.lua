--[[
    DeathHandler.lua
    ================
    Server Script — handles player death from entity contact.
    
    Called by EntityManager when an entity catches a player.
    
    Flow:
        1. Call PlayerManager.onPlayerDeath() to clear non-Legendary inventory
        2. Fire PlayerDied to client (triggers death screen)
        3. Wait 3 seconds
        4. Teleport player back to Hub
        5. Cleanup maze and entity via ElevatorService
    
    Dependencies:
        - PlayerManager
        - ElevatorService
        - EntityManager
        - RemoteEvents
        - MazeConfig
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local MazeConfig = require(Modules.Data.MazeConfig)
local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))

-- Direct requires (ElevatorService is lazy-loaded to avoid circular dependency)
local PlayerManager = require(ServerScriptService:WaitForChild("PlayerManager"))
local EntityManager = require(ServerScriptService:WaitForChild("EntityManager"))

local DeathHandler = {}

-- Prevent double-death processing
local processingDeath = {} -- { [UserId] = true }

--------------------------------------------------------------------------------
-- PUBLIC: Handle a player being killed by an entity
--------------------------------------------------------------------------------

local function executeDeath(player: Player)
    print("[DeathHandler] Executing final death for " .. player.Name)

    -- 1. Clear non-Legendary items from inventory
    local removedItems = PlayerManager.onPlayerDeath(player)

    local lostCount = #removedItems
    print("[DeathHandler] " .. player.Name .. " lost " .. lostCount .. " items")

    -- 2. Fire death event to client (triggers jumpscare/death screen)
    Remotes.PlayerDied:FireClient(player, {
        message = "YOU DIED",
        itemsLost = lostCount,
        entityName = "Unknown Entity", -- Could be passed in later
    })

    -- 3. Deactivate flashlight
    Remotes.EquipFlashlight:FireClient(player, false)

    -- 4. Wait for death screen to display
    task.wait(3)

    -- 5. Cleanup entity
    EntityManager.cleanup(player)

    -- 6. Teleport back to Hub (lazy-load to avoid circular dependency)
    local ElevatorService = require(ServerScriptService:WaitForChild("ElevatorService"))
    ElevatorService.forceExitMaze(player)

    -- 7. Notify client of return to hub
    Remotes.ReturnToHub:FireClient(player, "You lost " .. lostCount .. " items. Legendaries are safe.")

    processingDeath[player.UserId] = nil
    print("[DeathHandler] " .. player.Name .. " returned to Hub")
end

--------------------------------------------------------------------------------
-- PUBLIC: Handle a player being killed by an entity
--------------------------------------------------------------------------------

function DeathHandler.onEntityKill(player: Player)
    if not player or not player.Parent then return end
    if processingDeath[player.UserId] then return end
    processingDeath[player.UserId] = true

    print("[DeathHandler] " .. player.Name .. " was caught by an entity!")
    
    -- Attempt DBNO (Down But Not Out)
    local ReviveService = require(ServerScriptService:WaitForChild("ReviveService"))
    
    ReviveService.attemptDownPlayer(player, 
        function(victim)
            -- Final Death Callback
            executeDeath(victim)
        end,
        function(revivedPlayer)
            -- Revive Callback
            processingDeath[revivedPlayer.UserId] = nil
            print("[DeathHandler] " .. revivedPlayer.Name .. " revived. Death processing cleared.")
        end
    )
end

--------------------------------------------------------------------------------
-- Cleanup on player leave
--------------------------------------------------------------------------------

Players.PlayerRemoving:Connect(function(player)
    processingDeath[player.UserId] = nil
end)

print("[DeathHandler] Initialized")

return DeathHandler
