--[[
    ReviveService.lua
    =================
    Server Service — Manages DBNO (Down But Not Out) state for multiplayer.
    
    Logic:
    - activeSessions variable tracks downed players.
    - When a player is "killed" (by entity or trap), if they have teammates, they go Downed.
    - Downed: immobolized, health bleeding out, visual cue.
    - Revive: Teammate holds E -> Player gets back up with 50 HP.
    - Bleedout: If timer hits 0, they actually die (Return to Lobby / Spectate).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))
local PartyService = require(ServerScriptService:WaitForChild("PartyService"))

local ReviveService = {}

local DOWNED_DURATION = 30 -- Seconds to revive
local REVIVE_DURATION = 3 -- Seconds to hold E
local REVIVE_HP = 50

local downedPlayers = {} -- { [UserId] = {expireTime, prompt, connection} }

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function cleanupDownedState(player)
    local data = downedPlayers[player.UserId]
    if data then
        if data.prompt then data.prompt:Destroy() end
        if data.attachment then data.attachment:Destroy() end
        downedPlayers[player.UserId] = nil
    end
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function ReviveService.isDowned(player)
    return downedPlayers[player.UserId] ~= nil
end

function ReviveService.attemptDownPlayer(player, finalDeathCallback, onReviveCallback)
    -- Check if player has living party members
    local partyMembers = PartyService.getPartyMembers(player)
    
    local hasTeammates = false
    if partyMembers and #partyMembers > 1 then
        -- Check if any OTHER party member is alive and not downed
        for _, member in ipairs(partyMembers) do
            if member ~= player 
               and member.Character 
               and member.Character:FindFirstChild("Humanoid")
               and member.Character.Humanoid.Health > 0 
               and not ReviveService.isDowned(member) then
                hasTeammates = true
                break
            end
        end
    end

    if not hasTeammates then
        -- No help coming -> instant death
        finalDeathCallback(player)
        return
    end

    -- TRIGGER DOWNED STATE
    if ReviveService.isDowned(player) then return end
    
    local char = player.Character
    local hum = char and char:FindFirstChild("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    if not (char and hum and hrp) then 
        finalDeathCallback(player)
        return 
    end

    print("[ReviveService] " .. player.Name .. " is DOWNED!")

    -- 1. Immobilize
    hum.WalkSpeed = 0
    hum.JumpPower = 0
    hum.Health = 5 -- Keep them technically alive
    
    -- Prevent jumping out of downed state?
    
    -- 2. Visuals (Red highlight?)
    Remotes.DownedState:FireClient(player, true) -- Need to add remote
    
    -- 3. Create Revive Prompt
    local attach = Instance.new("Attachment", hrp)
    attach.Name = "ReviveAttachment"
    attach.Position = Vector3.new(0, 1, 0)
    
    local prompt = Instance.new("ProximityPrompt")
    prompt.ObjectText = "Revive " .. player.Name
    prompt.ActionText = "Hold to Revive"
    prompt.HoldDuration = REVIVE_DURATION
    prompt.MaxActivationDistance = 8
    prompt.RequiresLineOfSight = false
    prompt.Parent = attach
    
    downedPlayers[player.UserId] = {
        expireTime = tick() + DOWNED_DURATION,
        prompt = prompt,
        attachment = attach,
        onRevive = onReviveCallback -- Store callback
    }

    -- 4. Connect Prompt
    prompt.Triggered:Connect(function(helper)
        ReviveService.revivePlayer(player)
    end)
    
    -- 5. Start Bleedout Loop
    task.spawn(function()
        local userId = player.UserId
        while downedPlayers[userId] do
            if tick() > downedPlayers[userId].expireTime then
                -- Bleedout complete -> Die
                cleanupDownedState(player)
                finalDeathCallback(player)
                break
            end
            
            -- Ensure health stays low but > 0
            if hum.Health <= 0 then
                -- They took extra damage?
                cleanupDownedState(player)
                finalDeathCallback(player)
                break
            end
            hum.Health = 5 
            
            task.wait(1)
        end
    end)
    
    -- 6. Animation? (Sit)
    hum.Sit = true
end

function ReviveService.revivePlayer(player)
    local data = downedPlayers[player.UserId]
    if not data then return end
    
    local onRevive = data.onRevive -- Retrieve callback
    
    cleanupDownedState(player)
    
    local char = player.Character
    local hum = char and char:FindFirstChild("Humanoid")
    
    if hum then
        hum.Health = REVIVE_HP
        hum.WalkSpeed = 16 -- Default
        hum.JumpPower = 50 -- Default
        hum.Sit = false
    end
    
    if onRevive then onRevive(player) end -- Call callback
    
    print("[ReviveService] " .. player.Name .. " was REVIVED!")
    Remotes.DownedState:FireClient(player, false)
end

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

Players.PlayerRemoving:Connect(function(player)
    cleanupDownedState(player)
end)

return ReviveService
