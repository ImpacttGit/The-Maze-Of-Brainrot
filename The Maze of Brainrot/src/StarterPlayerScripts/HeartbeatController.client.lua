--[[
    HeartbeatController.lua
    =======================
    Client LocalScript — creates tension via audio and visual proximity effects.
    
    Features:
        - Heartbeat sound that intensifies based on distance to entity
        - Volume and PlaybackSpeed scale inversely with distance
        - Red vignette overlay when entity is very close
        - Camera data broadcasting for Mute Mannequin behavior
    
    Dependencies:
        - RemoteEvents
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera

local HeartbeatController = {}

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local MAX_DISTANCE = 100       -- Beyond this, no heartbeat
local CLOSE_DISTANCE = 20      -- Vignette starts
local KILL_DISTANCE = 10       -- Maximum heartbeat intensity

local VOLUME_MIN = 0
local VOLUME_MAX = 1.2
local SPEED_MIN = 0.5
local SPEED_MAX = 2.5

local CAMERA_SEND_RATE = 0.3  -- How often to send camera data (seconds)

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local entityPosition: Vector3? = nil
local isActive = false

--------------------------------------------------------------------------------
-- Create heartbeat sound
--------------------------------------------------------------------------------

local heartbeatSound = Instance.new("Sound")
heartbeatSound.Name = "HeartbeatEffect"
heartbeatSound.SoundId = "" -- No sound asset available yet
heartbeatSound.Volume = 0
heartbeatSound.Looped = true
heartbeatSound.PlaybackSpeed = 1
heartbeatSound.Parent = PlayerGui

--------------------------------------------------------------------------------
-- Create red vignette overlay
--------------------------------------------------------------------------------

local vignetteGui = Instance.new("ScreenGui")
vignetteGui.Name = "VignetteEffect"
vignetteGui.ResetOnSpawn = false
vignetteGui.IgnoreGuiInset = true
vignetteGui.DisplayOrder = 5
vignetteGui.Parent = PlayerGui

-- Four edge panels to create a vignette effect
local function createVignetteEdge(name: string, size: UDim2, position: UDim2, gradientRotation: number): Frame
    local edge = Instance.new("Frame")
    edge.Name = name
    edge.Size = size
    edge.Position = position
    edge.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
    edge.BackgroundTransparency = 1 -- Starts invisible
    edge.BorderSizePixel = 0
    edge.Parent = vignetteGui

    local gradient = Instance.new("UIGradient")
    gradient.Rotation = gradientRotation
    gradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.4, 0.5),
        NumberSequenceKeypoint.new(1, 1),
    })
    gradient.Parent = edge

    return edge
end

local vignetteEdges = {
    createVignetteEdge("Top", UDim2.new(1, 0, 0.3, 0), UDim2.new(0, 0, 0, 0), 90),
    createVignetteEdge("Bottom", UDim2.new(1, 0, 0.3, 0), UDim2.new(0, 0, 0.7, 0), 270),
    createVignetteEdge("Left", UDim2.new(0.3, 0, 1, 0), UDim2.new(0, 0, 0, 0), 0),
    createVignetteEdge("Right", UDim2.new(0.3, 0, 1, 0), UDim2.new(0.7, 0, 0, 0), 180),
}

--------------------------------------------------------------------------------
-- Create death screen overlay
--------------------------------------------------------------------------------

local deathGui = Instance.new("ScreenGui")
deathGui.Name = "DeathScreen"
deathGui.ResetOnSpawn = false
deathGui.IgnoreGuiInset = true
deathGui.DisplayOrder = 100
deathGui.Enabled = false
deathGui.Parent = PlayerGui

local deathOverlay = Instance.new("Frame")
deathOverlay.Size = UDim2.new(1, 0, 1, 0)
deathOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
deathOverlay.BackgroundTransparency = 0
deathOverlay.BorderSizePixel = 0
deathOverlay.Parent = deathGui

local deathTitle = Instance.new("TextLabel")
deathTitle.Size = UDim2.new(1, 0, 0, 80)
deathTitle.Position = UDim2.new(0, 0, 0.35, 0)
deathTitle.BackgroundTransparency = 1
deathTitle.Text = "YOU DIED"
deathTitle.TextColor3 = Color3.fromRGB(220, 0, 0)
deathTitle.TextSize = 64
deathTitle.Font = Enum.Font.GothamBold
deathTitle.Parent = deathOverlay

local deathSubtitle = Instance.new("TextLabel")
deathSubtitle.Size = UDim2.new(1, 0, 0, 40)
deathSubtitle.Position = UDim2.new(0, 0, 0.5, 0)
deathSubtitle.BackgroundTransparency = 1
deathSubtitle.Text = ""
deathSubtitle.TextColor3 = Color3.fromRGB(200, 200, 200)
deathSubtitle.TextSize = 20
deathSubtitle.Font = Enum.Font.GothamMedium
deathSubtitle.Parent = deathOverlay

--------------------------------------------------------------------------------
-- Update heartbeat intensity based on distance
--------------------------------------------------------------------------------

local function updateHeartbeat(dt: number)
    if not isActive or not entityPosition then
        heartbeatSound.Volume = 0
        for _, edge in ipairs(vignetteEdges) do
            edge.BackgroundTransparency = 1
        end
        return
    end

    -- Get player position
    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local distance = (hrp.Position - entityPosition).Magnitude

    if distance > MAX_DISTANCE then
        heartbeatSound.Volume = 0
        for _, edge in ipairs(vignetteEdges) do
            edge.BackgroundTransparency = 1
        end
        return
    end

    -- Map distance to intensity (0 at MAX, 1 at KILL)
    local intensity = 1 - math.clamp((distance - KILL_DISTANCE) / (MAX_DISTANCE - KILL_DISTANCE), 0, 1)

    -- Update sound
    heartbeatSound.Volume = VOLUME_MIN + (VOLUME_MAX - VOLUME_MIN) * intensity
    heartbeatSound.PlaybackSpeed = SPEED_MIN + (SPEED_MAX - SPEED_MIN) * intensity

    if not heartbeatSound.IsPlaying then
        heartbeatSound:Play()
    end

    -- Update vignette (only when very close)
    if distance < CLOSE_DISTANCE then
        local vignetteIntensity = 1 - (distance / CLOSE_DISTANCE)
        for _, edge in ipairs(vignetteEdges) do
            edge.BackgroundTransparency = 1 - (vignetteIntensity * 0.6)
        end
    else
        for _, edge in ipairs(vignetteEdges) do
            edge.BackgroundTransparency = 1
        end
    end
end

--------------------------------------------------------------------------------
-- Camera data broadcasting (for Mute Mannequin)
--------------------------------------------------------------------------------

local lastCameraSend = 0

local function broadcastCameraData()
    local now = tick()
    if now - lastCameraSend < CAMERA_SEND_RATE then return end
    lastCameraSend = now

    if Camera then
        Remotes.CameraCheck:FireServer(Camera.CFrame)
    end
end

--------------------------------------------------------------------------------
-- Main update loop
--------------------------------------------------------------------------------

RunService.Heartbeat:Connect(function(dt)
    updateHeartbeat(dt)

    if isActive then
        broadcastCameraData()
    end
end)

--------------------------------------------------------------------------------
-- Listen for EntityPosition updates from server
--------------------------------------------------------------------------------

Remotes.EntityPosition.OnClientEvent:Connect(function(position: Vector3)
    entityPosition = position
    if not isActive then
        isActive = true
    end
end)

--------------------------------------------------------------------------------
-- Listen for PlayerDied event
--------------------------------------------------------------------------------

Remotes.PlayerDied.OnClientEvent:Connect(function(deathData: any)
    -- Show death screen
    isActive = false
    entityPosition = nil
    heartbeatSound:Stop()

    -- Hide vignette
    for _, edge in ipairs(vignetteEdges) do
        edge.BackgroundTransparency = 1
    end

    -- Flash red then show death screen
    deathGui.Enabled = true
    deathOverlay.BackgroundTransparency = 1

    -- Red flash
    TweenService:Create(deathOverlay, TweenInfo.new(0.2), {
        BackgroundTransparency = 0,
        BackgroundColor3 = Color3.fromRGB(100, 0, 0),
    }):Play()
    task.wait(0.3)

    -- Fade to black
    TweenService:Create(deathOverlay, TweenInfo.new(0.5), {
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
    }):Play()

    -- Set text
    deathTitle.Text = deathData.message or "YOU DIED"
    if deathData.itemsLost and deathData.itemsLost > 0 then
        deathSubtitle.Text = "Lost " .. deathData.itemsLost .. " items. Legendaries are safe."
    else
        deathSubtitle.Text = "The entity got you..."
    end

    -- Hold for 2.5 seconds
    task.wait(2.5)

    -- Fade out
    TweenService:Create(deathOverlay, TweenInfo.new(0.5), {
        BackgroundTransparency = 1,
    }):Play()
    task.wait(0.6)
    deathGui.Enabled = false
end)

--------------------------------------------------------------------------------
-- Listen for ReturnToHub (cleanup active state)
--------------------------------------------------------------------------------

Remotes.ReturnToHub.OnClientEvent:Connect(function(message: string?)
    isActive = false
    entityPosition = nil
    heartbeatSound:Stop()

    for _, edge in ipairs(vignetteEdges) do
        edge.BackgroundTransparency = 1
    end
end)

print("[HeartbeatController] Initialized")
