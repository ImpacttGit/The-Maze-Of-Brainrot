--[[
    FlashlightController.client.lua
    ================================
    Client LocalScript — manages flashlight during maze runs.
    
    - Press F to toggle flashlight ON/OFF
    - Battery drains ONLY when the light is ON
    - Flickers when battery < 15%, dies at 0%
    - Powerbank Epic item refills battery
    
    Dependencies: RemoteEvents
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))

local LocalPlayer = Players.LocalPlayer

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local DRAIN_RATE = 1.5        -- Percentage lost per second (when ON)
local FLICKER_THRESHOLD = 15  -- Start flickering below this %
local FLICKER_MIN = 0.05
local FLICKER_MAX = 1.2
local SPOTLIGHT_BRIGHTNESS = 1.5
local SPOTLIGHT_RANGE = 40
local SPOTLIGHT_ANGLE = 55
local UPDATE_INTERVAL = 0.5   -- How often to push battery update to server

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local isInMaze = false       -- True while player is in the maze
local isLightOn = false      -- True when flashlight is toggled ON
local battery = 100
local spotLight: SpotLight? = nil
local updateConnection: RBXScriptConnection? = nil
local lastUpdateTime = 0

--------------------------------------------------------------------------------
-- INTERNAL: Create the SpotLight on the character
--------------------------------------------------------------------------------

local function createSpotLight()
    local character = LocalPlayer.Character
    if not character then return end

    local head = character:WaitForChild("Head", 5)
    if not head then return end

    -- Remove old spotlight if exists
    local existing = head:FindFirstChild("Flashlight")
    if existing then existing:Destroy() end

    local light = Instance.new("SpotLight")
    light.Name = "Flashlight"
    light.Brightness = SPOTLIGHT_BRIGHTNESS
    light.Range = SPOTLIGHT_RANGE
    light.Angle = SPOTLIGHT_ANGLE
    light.Face = Enum.NormalId.Front
    light.Color = Color3.fromRGB(255, 250, 230)
    light.Enabled = false -- Starts OFF, player presses F to turn on
    light.Parent = head

    spotLight = light
    return light
end

local function destroySpotLight()
    if spotLight then
        spotLight:Destroy()
        spotLight = nil
    end
end

--------------------------------------------------------------------------------
-- Toggle flashlight ON/OFF
--------------------------------------------------------------------------------

local toggleSound = Instance.new("Sound")
toggleSound.Name = "FlashlightToggle"
toggleSound.SoundId = "rbxassetid://131826366187224"
toggleSound.Volume = 0.5
toggleSound.Parent = PlayerGui

local flickerSound = Instance.new("Sound")
flickerSound.Name = "FlashlightFlicker"
flickerSound.SoundId = "rbxassetid://129511449394470"
flickerSound.Volume = 0.6
flickerSound.Parent = PlayerGui

local function toggleFlashlight()
    if not isInMaze then return end
    if battery <= 0 then return end -- Can't toggle on when dead

    isLightOn = not isLightOn
    toggleSound:Play()

    if spotLight then
        spotLight.Enabled = isLightOn
        if isLightOn then
            spotLight.Brightness = SPOTLIGHT_BRIGHTNESS
        end
    end

    print("[Flashlight] " .. (isLightOn and "ON" or "OFF") .. " — Battery: " .. math.floor(battery) .. "%")
end

--------------------------------------------------------------------------------
-- Main update loop
--------------------------------------------------------------------------------

local function applyFlicker()
    if not spotLight then return end

    if battery <= 0 then
        spotLight.Enabled = false
        isLightOn = false
        return
    end

    if not isLightOn then
        spotLight.Enabled = false
        return
    end

    if battery < FLICKER_THRESHOLD then
        local flickerChance = 1 - (battery / FLICKER_THRESHOLD)
        if math.random() < flickerChance * 0.4 then
            spotLight.Brightness = FLICKER_MIN
            spotLight.Enabled = math.random() > 0.3
            if not spotLight.Enabled and math.random() < 0.2 then
                 if not flickerSound.IsPlaying then flickerSound:Play() end
            end
        else
            spotLight.Brightness = SPOTLIGHT_BRIGHTNESS * (battery / 100)
            spotLight.Enabled = true
        end
    else
        spotLight.Brightness = SPOTLIGHT_BRIGHTNESS
        spotLight.Enabled = true
    end
end

--------------------------------------------------------------------------------
-- Main update loop
--------------------------------------------------------------------------------

local function startUpdateLoop()
    if updateConnection then
        updateConnection:Disconnect()
    end

    updateConnection = RunService.Heartbeat:Connect(function(dt)
        if not isInMaze then return end

        -- Only drain when light is ON
        if isLightOn and battery > 0 then
            battery = math.max(0, battery - DRAIN_RATE * dt)
        end

        -- Apply flicker effect
        applyFlicker()

        -- Push battery to server periodically
        local now = tick()
        if now - lastUpdateTime >= UPDATE_INTERVAL then
            lastUpdateTime = now
            -- UpdateBattery is server→client, so we just track locally
            -- HUD reads battery from server pushes
        end
    end)
end

local function stopUpdateLoop()
    if updateConnection then
        updateConnection:Disconnect()
        updateConnection = nil
    end
end

--------------------------------------------------------------------------------
-- Activate / Deactivate (maze entry/exit)
--------------------------------------------------------------------------------

local function activate()
    if isInMaze then return end
    isInMaze = true
    isLightOn = false  -- Starts OFF — player presses F
    battery = 100
    lastUpdateTime = tick()

    createSpotLight()
    startUpdateLoop()

    print("[FlashlightController] Ready — Press F to toggle flashlight")
end

local function deactivate()
    if not isInMaze then return end
    isInMaze = false
    isLightOn = false
    battery = 0

    stopUpdateLoop()
    destroySpotLight()

    print("[FlashlightController] Deactivated")
end

--------------------------------------------------------------------------------
-- Refill battery (Powerbank Epic item)
--------------------------------------------------------------------------------

local function refillBattery(amount: number?)
    battery = math.min(100, battery + (amount or 100))
    print("[FlashlightController] Battery refilled to " .. math.floor(battery) .. "%")
end

local function getBattery(): number
    return battery
end

--------------------------------------------------------------------------------
-- Keybind: F to toggle flashlight
--------------------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F then
        toggleFlashlight()
    end
end)

--------------------------------------------------------------------------------
-- Listen for server events
--------------------------------------------------------------------------------

Remotes.EquipFlashlight.OnClientEvent:Connect(function(shouldActivate: boolean)
    if shouldActivate then
        activate()
    else
        deactivate()
    end
end)

-- Powerbank refill on pickup
Remotes.LootPickupResult.OnClientEvent:Connect(function(success: boolean, message: string, itemData: any)
    if success and itemData and itemData.ItemId then
        if string.find(itemData.ItemId, "powerbank") or string.find(itemData.ItemId, "Powerbank") then
            refillBattery(100)
        end
    end
end)

-- Handle character respawn
LocalPlayer.CharacterAdded:Connect(function()
    if isInMaze then
        task.wait(1)
        createSpotLight()
        if isLightOn and battery > 0 then
            spotLight.Enabled = true
        end
    end
end)

print("[FlashlightController] Initialized — F to toggle in maze")
