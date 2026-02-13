--[[
    DailyRewardService.lua
    ======================
    Server Script — manages daily reward streaks and claims.
    
    Logic:
    - Checks last claim time on join.
    - If 22h passed since last claim, reward is available.
    - If 48h passed since last claim, streak resets to 0.
    - Rewards cycle through 7 days (Fragments, Items).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerManager = require(ServerScriptService:WaitForChild("PlayerManager"))
local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))
-- Assuming LootService is in ReplicatedStorage/Modules/Services based on previous context
local Modules = ReplicatedStorage:WaitForChild("Modules")
local LootService = require(Modules:WaitForChild("Services"):WaitForChild("LootService"))

local DailyRewardService = {}

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local REWARD_CYCLE = {
    { Day = 1, Type = "Fragments", Amount = 100, Rarity = "Common" },
    { Day = 2, Type = "Fragments", Amount = 200, Rarity = "Common" },
    { Day = 3, Type = "Fragments", Amount = 350, Rarity = "Uncommon" },
    { Day = 4, Type = "Item", Rarity = "Common" },
    { Day = 5, Type = "Fragments", Amount = 500, Rarity = "Rare" },
    { Day = 6, Type = "Item", Rarity = "Rare" },
    { Day = 7, Type = "Item", Rarity = "Epic" }, -- Big reward
}

local CLAIM_COOLDOWN = 22 * 3600 -- 22 hours (allow some leeway)
local STREAK_RESET_TIME = 48 * 3600 -- 48 hours

--------------------------------------------------------------------------------
-- Core Logic
--------------------------------------------------------------------------------

local function getPlayerData(player)
    return PlayerManager.getBuffer(player) or PlayerManager.getData(player) -- adapt based on PlayerManager API
    -- Actually PlayerManager.getData(player) returns { playerData = ... } wrapper usually?
    -- No, PlayerManager.getBuffer returns the raw table
end

local function checkDailyReward(player)
    -- Just send current state
    local entry = PlayerManager.getDataWrapper(player) -- Need internal access or public API?
    -- PlayerManager local API usually not exposed via bindable, but since this is ServerScriptService, we can require it.
    -- PlayerManager.getData(player) isn't public in the file I read earlier?
    -- Wait, looking at PlayerManager code I wrote earlier:
    -- It has `function PlayerManager.getData(player)` returning `PlayerDataStore[userId]`.
    -- So `entry.playerData`.
    
    local entry = PlayerManager.getData(player)
    if not entry then return end
    
    local data = entry.playerData.dailyRewardData or {}
    local lastClaim = data.lastClaimTime or 0
    local streak = data.streak or 0
    local now = os.time()
    
    -- Check for streak break
    if now - lastClaim > STREAK_RESET_TIME and lastClaim > 0 then
        streak = 0 -- Reset streak if missed a day
        data.streak = 0
        -- Save this reset?
        -- We'll save on claim. Display 0 streak for now.
    end
    
    local timeSince = now - lastClaim
    local canClaim = timeSince >= CLAIM_COOLDOWN
    
    -- Next reward index (1-7)
    local dayIndex = (streak % #REWARD_CYCLE) + 1
    
    Remotes.DailyRewardData:FireClient(player, {
        streak = streak,
        lastClaimTime = lastClaim,
        canClaim = canClaim,
        nextRewardDay = dayIndex,
        rewardCycle = REWARD_CYCLE
    })
end

local function claimReward(player)
    local entry = PlayerManager.getData(player)
    if not entry then return end
    
    local data = entry.playerData.dailyRewardData or {}
    local lastClaim = data.lastClaimTime or 0
    local streak = data.streak or 0
    local now = os.time()
    
    if now - lastClaim < CLAIM_COOLDOWN then
        return -- Cooldown not met
    end
    
    if now - lastClaim > STREAK_RESET_TIME and lastClaim > 0 then
        streak = 0
        data.streak = 0
    end
    
    local dayIndex = (streak % #REWARD_CYCLE) + 1
    local reward = REWARD_CYCLE[dayIndex]
    
    -- Grant reward
    if reward.Type == "Fragments" then
        PlayerManager.addFragments(player, reward.Amount)
    elseif reward.Type == "Item" then
        -- Generate random item of rarity
        -- Mock loot table for LootService
        local mockTable = {
            RarityWeights = { [reward.Rarity] = 100 }
        }
        local item = LootService.generateItem(mockTable)
        PlayerManager.addItem(player, item)
    end
    
    -- Update data
    data.streak = streak + 1
    data.lastClaimTime = now
    
    entry.playerData.dailyRewardData = data
    -- PlayerManager auto-saves periodically
    
    -- Notify client
    checkDailyReward(player) -- Push update
end

--------------------------------------------------------------------------------
-- Connections
--------------------------------------------------------------------------------

Players.PlayerAdded:Connect(function(player)
    task.wait(2) -- Wait for data load
    checkDailyReward(player)
end)

Remotes.DailyRewardClaim.OnServerEvent:Connect(claimReward)

return DailyRewardService
