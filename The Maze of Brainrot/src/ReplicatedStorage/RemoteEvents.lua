--[[
    RemoteEvents.lua
    ================
    Central registry for all RemoteEvents and RemoteFunctions.
    
    The GameRemotes folder and all remotes are defined in default.project.json
    so Rojo creates them automatically during sync. This module simply
    looks them up and exposes them for easy access.
    
    Usage:
        local Remotes = require(path.to.RemoteEvents)
        Remotes.UpdateFragments:FireClient(player, newBalance)  -- Server
        Remotes.UpdateFragments.OnClientEvent:Connect(fn)       -- Client
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = {}

--------------------------------------------------------------------------------
-- Remote names (for validation/documentation)
--------------------------------------------------------------------------------

local REMOTE_NAMES = {
    -- ===== Phase 2: HUD & Elevator =====
    "UpdateFragments",
    "UpdateInventory",
    "UpdateBattery",
    "RequestMazeEntry",
    "MazeEntryResult",

    -- ===== Phase 3: Loot & Flashlight =====
    "LootPickup",
    "LootPickupResult",
    "SpawnLootVisual",
    "EquipFlashlight",

    -- ===== Phase 4: Entities & Death =====
    "EntityPosition",
    "PlayerDied",
    "ReturnToHub",
    "CameraCheck",

    -- ===== Phase 5: Commerce =====
    "RequestSellItem",
    "RequestSellAll",
    "SellResult",
    "RequestTradeUp",
    "TradeUpResult",
    "OpenMerchant",
    "OpenTradeUp",
    "RequestInventoryData",
    "InventoryData",

    -- ===== Phase 6: Crates =====
    "RequestCratePurchase",
    "CrateResult",

    -- ===== Phase 7: Shared Loot & Inventory =====
    "HideLootForPlayer",
    "RequestDropItem",
    "DropItemResult",

    -- ===== Phase 8: Item Equip & Power-ups =====
    "RequestEquipItem",
    "EquipItemResult",
    "ApplyPowerUp",

    -- ===== Phase 9: XP, Levels & Prestige =====
    "UpdateXP",
    "UpdateLevel",
    "PrestigeUp",
    "RequestPrestige",

    -- ===== Phase 10: Game Passes =====
    "GamePassOwned",
    "CheckGamePasses",

    -- ===== Phase 11: Daily Rewards =====
    "DailyRewardClaim",
    "DailyRewardData",

    -- ===== Phase 12: Followers =====
    "SpawnFollower",
    "RemoveFollower",
}

--------------------------------------------------------------------------------
-- Look up remotes from the GameRemotes folder (created by Rojo project tree)
--------------------------------------------------------------------------------

local FOLDER_NAME = "GameRemotes"

print("[RemoteEvents] Looking up GameRemotes folder...")
local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 30)
assert(folder, "[RemoteEvents] GameRemotes folder not found in ReplicatedStorage! Check default.project.json and Rojo sync.")

for _, name in ipairs(REMOTE_NAMES) do
    local remote = folder:WaitForChild(name, 10)
    assert(remote, "[RemoteEvents] Could not find remote: " .. name .. " in GameRemotes folder")
    RemoteEvents[name] = remote
end

print("[RemoteEvents] All " .. #REMOTE_NAMES .. " remotes loaded successfully")

return RemoteEvents
