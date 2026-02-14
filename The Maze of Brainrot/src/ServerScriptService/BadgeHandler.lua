--[[
    BadgeHandler.lua
    ================
    Server Script — Helper module for awarding badges.
    
    Handles checking if a player already owns a badge before awarding it
    to prevent API warnings. Runs asynchronously.
    
    Dependencies:
        - BadgeService
        - BadgeConfig
]]

local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local BadgeConfig = require(Modules.Data.BadgeConfig)

local BadgeHandler = {}

-- Award a badge by its config key (e.g. "Intern")
function BadgeHandler.award(player: Player, badgeKey: string)
    local badgeId = BadgeConfig.Badges[badgeKey]
    if not badgeId then
        warn("[BadgeHandler] Unknown badge key: " .. tostring(badgeKey))
        return
    end
    
    task.spawn(function()
        -- 1. Check if they have it
        local success, hasBadge = pcall(function()
            return BadgeService:UserHasBadgeAsync(player.UserId, badgeId)
        end)
        
        if not success then
             warn("[BadgeHandler] Failed to check badge ownership for " .. player.Name)
             return
        end
        
        if hasBadge then return end -- Already owned
        
        -- 2. Award it
        local awardSuccess, result = pcall(function()
            return BadgeService:AwardBadge(player.UserId, badgeId)
        end)
        
        if awardSuccess then
            print("[BadgeHandler] Awarded '" .. badgeKey .. "' to " .. player.Name)
        else
            warn("[BadgeHandler] Failed to award " .. badgeKey .. ": " .. tostring(result))
        end
    end)
end

return BadgeHandler
