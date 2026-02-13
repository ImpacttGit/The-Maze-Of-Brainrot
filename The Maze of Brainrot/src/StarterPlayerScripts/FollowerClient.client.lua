--[[
    FollowerClient.client.lua
    =========================
    Client-side handling for Legendary Followers.
    Effect: Smoothly interpolates follower position behind player with a floating sine-wave effect.
    Relies on NetworkOwnership being passed from server.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))

local player = Players.LocalPlayer
local activeFollowers = {} -- { [Model] = { offsetIndex = number, itemId = string } }

--------------------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------------------

local LERP_ALPHA = 0.1 -- Smoothing factor (lower = smoother/slower)
local FLOAT_AMPLITUDE = 0.5
local FLOAT_SPEED = 2.0

--------------------------------------------------------------------------------
-- Render Loop
--------------------------------------------------------------------------------

RunService.RenderStepped:Connect(function(deltaTime)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local timeNow = tick()
    local floatY = math.sin(timeNow * FLOAT_SPEED) * FLOAT_AMPLITUDE

    for model, data in pairs(activeFollowers) do
        if model.Parent then
            local primary = model.PrimaryPart
            if primary then
                 -- Calculate target position
                 -- Behind player, slightly to side based on offsetIndex
                 -- Spacing: 3 studs back, +/- X offset
                 
                 local index = data.offsetIndex or 0
                 local sideOffset = (index % 2 == 0) and (index * 2) or (-index * 2) 
                 -- Actually let's just use the server's simple spacing for now: 3 + index*2
                 -- But we want them spread out visually.
                 -- Let's try: Behind (3 studs) + Right (index * 2 studs)
                 
                 local targetCFrame = hrp.CFrame 
                                    * CFrame.new(3 + (index * 1.5), 2 + floatY, 3 + (index * 1.5)) 
                                    * CFrame.Angles(0, math.rad(180), 0) -- Face player? Or Face forward?
                                    
                 -- Let's make them hover behind the player, forming a V shape or line
                 -- Simplest: Line behind player
                 local distBehind = 4
                 local distSide = (index + 1) * 2 * (index % 2 == 0 and 1 or -1)
                 
                 local idealCFrame = hrp.CFrame 
                                   * CFrame.new(distSide, 2 + floatY, distBehind)
                 
                 -- Lerp
                 local newCFrame = primary.CFrame:Lerp(idealCFrame, LERP_ALPHA)
                 primary.CFrame = newCFrame
                 
                 -- Ensure anchored? No, network ownership means we simulate physics if unanchored.
                 -- But if we set CFrame every frame, we are overriding physics.
                 -- We should anchor the PrimaryPart on the client? 
                 -- If unanchored, gravity fights us.
                 primary.Anchored = true 
                 primary.CanCollide = false
            end
        else
            activeFollowers[model] = nil
        end
    end
end)

--------------------------------------------------------------------------------
-- Handlers
--------------------------------------------------------------------------------

Remotes.SpawnFollower.OnClientEvent:Connect(function(model, itemId, offsetIndex)
    if not model then return end
    
    -- Wait for replication
    if not model.Parent then
        model.AncestryChanged:Wait()
    end
    
    print("[FollowerClient] Took control of " .. model.Name)
    
    -- Register
    activeFollowers[model] = {
        itemId = itemId,
        offsetIndex = offsetIndex
    }
    
    -- Setup model for client control
    if model.PrimaryPart then
        model.PrimaryPart.Anchored = true
        model.PrimaryPart.CanCollide = false
    end
    
    -- Cleanup humanoid physics to prevent fighting
    local hum = model:FindFirstChildWhichIsA("Humanoid")
    if hum then
        hum.PlatformStand = true
    end
end)

print("[FollowerClient] Initialized")
