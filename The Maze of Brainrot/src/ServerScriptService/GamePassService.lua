--[[
    GamePassService.lua
    ===================
    Server Module — checks game pass ownership and applies persistent buffs.
    
    Game Pass IDs are placeholders (0) until real IDs are created in Creator Hub.
    Replace PASS_IDS values with real IDs when ready.
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))

local GamePassService = {}

--------------------------------------------------------------------------------
-- Pass Definitions (replace 0 with real IDs from Creator Hub)
--------------------------------------------------------------------------------

local PASS_IDS = {
    SpeedBoost = 0,        -- Permanent +4 WalkSpeed
    UpgradedFlashlight = 0, -- 2x battery, brighter beam
    LootLuck = 0,          -- 1.5x rare/epic spawn chance
}

local PASS_INFO = {
    {
        id = "SpeedBoost",
        name = "⚡ Speed Demon",
        description = "Permanent +4 WalkSpeed in the maze. Outrun anything!",
        price = "250 R$",
        icon = "⚡",
    },
    {
        id = "UpgradedFlashlight",
        name = "🔦 Mega Flashlight",
        description = "2x battery life, brighter beam, slower drain.",
        price = "200 R$",
        icon = "🔦",
    },
    {
        id = "LootLuck",
        name = "🍀 Lucky Looter",
        description = "1.5x chance to find Rare, Epic & Legendary items!",
        price = "350 R$",
        icon = "🍀",
    },
}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

-- { [UserId] = { SpeedBoost = true, UpgradedFlashlight = false, ... } }
local playerPasses = {}

--------------------------------------------------------------------------------
-- Check pass ownership
--------------------------------------------------------------------------------

local function checkPasses(player: Player)
    local owned = {}

    for passKey, passId in pairs(PASS_IDS) do
        if passId > 0 then
            local success, hasPass = pcall(function()
                return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
            end)
            owned[passKey] = success and hasPass or false
        else
            owned[passKey] = false -- Placeholder ID
        end
    end

    playerPasses[player.UserId] = owned
    return owned
end

--------------------------------------------------------------------------------
-- Apply buffs based on owned passes
--------------------------------------------------------------------------------

local function applyBuffs(player: Player)
    local owned = playerPasses[player.UserId]
    if not owned then return end

    -- Speed boost
    if owned.SpeedBoost then
        local character = player.Character
        if character then
            local humanoid = character:FindFirstChildWhichIsA("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = humanoid.WalkSpeed + 4
            end
        end
    end

    -- Send owned passes to client
    Remotes.GamePassOwned:FireClient(player, owned)
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function GamePassService.hasPass(player: Player, passKey: string): boolean
    local owned = playerPasses[player.UserId]
    return owned and owned[passKey] or false
end

function GamePassService.getPassInfo(): { any }
    return PASS_INFO
end

function GamePassService.getLootLuckMultiplier(player: Player): number
    if GamePassService.hasPass(player, "LootLuck") then
        return 1.5
    end
    return 1.0
end

function GamePassService.getFlashlightDrainMultiplier(player: Player): number
    if GamePassService.hasPass(player, "UpgradedFlashlight") then
        return 0.5 -- Half drain rate
    end
    return 1.0
end

--------------------------------------------------------------------------------
-- Player connections
--------------------------------------------------------------------------------

Players.PlayerAdded:Connect(function(player)
    checkPasses(player)

    player.CharacterAdded:Connect(function()
        task.wait(1)
        applyBuffs(player)
    end)

    -- Apply immediately if character exists
    if player.Character then
        applyBuffs(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    playerPasses[player.UserId] = nil
end)

-- Handle mid-session purchases
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
    if wasPurchased then
        checkPasses(player)
        applyBuffs(player)
        print("[GamePassService] " .. player.Name .. " purchased a game pass!")
    end
end)

-- Client request for pass info
Remotes.CheckGamePasses.OnServerEvent:Connect(function(player)
    local owned = playerPasses[player.UserId] or checkPasses(player)
    Remotes.GamePassOwned:FireClient(player, owned)
end)

print("[GamePassService] Initialized (placeholder IDs — replace with real pass IDs)")

return GamePassService
