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

--------------------------------------------------------------------------------
-- Render Loop
--------------------------------------------------------------------------------

RunService.RenderStepped:Connect(function(deltaTime)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local head = char:FindFirstChild("Head")

    local timeNow = tick()
    local floatY = math.sin(timeNow * FLOAT_SPEED) * FLOAT_AMPLITUDE

    for model, data in pairs(activeFollowers) do
        if model.Parent then
            local primary = model.PrimaryPart
            if primary then
                 local itemId = data.itemId or ""
                 local index = data.offsetIndex or 0
                 
                 -- Standard Follower (Floating behind)
                 local targetCFrame = hrp.CFrame
                 local appliedCFrame
                 
                 -- BEHAVIORS
                 if itemId:match("Sneakers") or itemId:match("Shark") then
                     -- Shark (Sneakers): Walks/Slides behind. Ground level.
                     local slideOffset = math.sin(timeNow * 3) * 2 -- Slide left/right
                     appliedCFrame = hrp.CFrame * CFrame.new(slideOffset, -2, 4 + index) 
                 
                 elseif itemId:match("Coffee") or itemId:match("Ballerina") then
                     -- Ballerina (Coffee): Orbits the player's head.
                     if head then
                         local orbitSpeed = 2
                         local radius = 4
                         local angle = timeNow * orbitSpeed
                         local offset = Vector3.new(math.cos(angle) * radius, 1, math.sin(angle) * radius)
                         appliedCFrame = head.CFrame + offset
                         appliedCFrame = CFrame.new(appliedCFrame.Position, head.Position) -- Look at head
                     else
                         appliedCFrame = hrp.CFrame * CFrame.new(0, 5, 0)
                     end
                     
                 elseif itemId:match("Banana") or itemId:match("Monkey") then
                     -- Monkey (Banana): Mimics player jumping.
                     -- Detect jump via Humanoid state or just use HRP Y relative to ground?
                     -- Simply match HRP Y + offset
                     local jumpY = 0
                     -- If player is high up, maintain rel height
                     appliedCFrame = hrp.CFrame * CFrame.new(2 + index, 0 + floatY, 3) 
                     
                 elseif itemId:match("Jet") or itemId:match("Croc") then
                     -- Croc (Jet): Leaves fire particles. Flying.
                     appliedCFrame = hrp.CFrame * CFrame.new(-3 - index, 3 + floatY, 3)
                     -- Add particles if missing
                     if not primary:FindFirstChild("JetFire") then
                         local p = Instance.new("ParticleEmitter")
                         p.Name = "JetFire"
                         p.Texture = "rbxassetid://242203061" -- Fire
                         p.Color = ColorSequence.new(Color3.fromRGB(255, 100, 0))
                         p.Rate = 20
                         p.Lifetime = NumberRange.new(0.5)
                         p.Speed = NumberRange.new(2)
                         p.EmissionDirection = Enum.NormalId.Back
                         p.Parent = primary
                     end
                     
                 elseif itemId:match("Bat") or itemId:match("Plank") then
                     -- Plank (Bat): Attached to player's back via WeldConstraint.
                     -- We don't lerp here, we should WELD it once.
                     -- If not welded, weld it.
                     if not model:FindFirstChild("BackWeld") then
                         local weld = Instance.new("WeldConstraint")
                         weld.Name = "BackWeld"
                         weld.Part0 = hrp
                         weld.Part1 = primary
                         weld.Parent = model
                         -- Position it
                         primary.CFrame = hrp.CFrame * CFrame.new(0, 0, 0.6) * CFrame.Angles(0, 0, math.rad(45))
                     end
                     -- Skip CFrame update for welded items
                     appliedCFrame = nil 
                     
                 else
                     -- Default behavior
                     local distBehind = 4
                     local distSide = (index + 1) * 2 * (index % 2 == 0 and 1 or -1)
                     appliedCFrame = hrp.CFrame * CFrame.new(distSide, 2 + floatY, distBehind)
                 end
                 
                 -- Apply CFrame if not welded
                 if appliedCFrame then
                     local newCFrame = primary.CFrame:Lerp(appliedCFrame, LERP_ALPHA)
                     primary.CFrame = newCFrame
                     primary.Anchored = true 
                     primary.CanCollide = false
                 end
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
