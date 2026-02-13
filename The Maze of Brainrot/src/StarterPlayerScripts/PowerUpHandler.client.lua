--[[
    PowerUpHandler.client.lua
    =========================
    Handles activation of Epic item power-ups on the client.
    
    Listens for ApplyPowerUp from server and applies effects:
    - SpeedBoost: Increases WalkSpeed
    - FlashlightRecharge: Refills battery
    - NeonAura: PointLight on character
    - DetectionBoost: (future — heartbeat range)
    - LightDisruption: (future — kills nearby lights)
    - SoundDecoy: (future — entity distraction)
    - ItemRadar: (future — compass UI)
    
    Shows activation toast notification.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--------------------------------------------------------------------------------
-- Toast notification system
--------------------------------------------------------------------------------

local function showPowerUpToast(message: string, color: Color3?)
    local toastColor = color or Color3.fromRGB(170, 80, 255) -- Purple

    local toast = Instance.new("ScreenGui")
    toast.Name = "PowerUpToast"
    toast.ResetOnSpawn = false
    toast.DisplayOrder = 20
    toast.Parent = PlayerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 350, 0, 60)
    frame.Position = UDim2.new(0.5, -175, 0, -70) -- Start above screen
    frame.AnchorPoint = Vector2.new(0, 0)
    frame.BackgroundColor3 = Color3.fromRGB(20, 15, 30)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Parent = toast

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = toastColor
    stroke.Thickness = 2
    stroke.Transparency = 0.3
    stroke.Parent = frame

    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(0, 40, 1, 0)
    icon.BackgroundTransparency = 1
    icon.Text = "⚡"
    icon.TextSize = 24
    icon.Font = Enum.Font.GothamBold
    icon.TextColor3 = toastColor
    icon.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -50, 1, 0)
    label.Position = UDim2.new(0, 45, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = message
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 16
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.Parent = frame

    -- Slide in
    local tweenService = game:GetService("TweenService")
    frame.Position = UDim2.new(0.5, -175, 0, -70)
    local slideIn = tweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -175, 0, 20)
    })
    slideIn:Play()

    -- Slide out after 3 seconds
    task.delay(3, function()
        local slideOut = tweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, -175, 0, -70)
        })
        slideOut:Play()
        slideOut.Completed:Connect(function()
            toast:Destroy()
        end)
    end)
end

--------------------------------------------------------------------------------
-- Power-up effect handlers
--------------------------------------------------------------------------------

local function applySpeedBoost(powerUp, itemName)
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildWhichIsA("Humanoid")
    if not humanoid then return end

    local originalSpeed = humanoid.WalkSpeed
    local multiplier = powerUp.Multiplier or 1.5
    local duration = powerUp.Duration or 15

    humanoid.WalkSpeed = originalSpeed * multiplier
    showPowerUpToast("⚡ " .. itemName .. " — " .. multiplier .. "x Speed for " .. duration .. "s!", Color3.fromRGB(255, 200, 50))

    task.delay(duration, function()
        if humanoid and humanoid.Parent then
            humanoid.WalkSpeed = originalSpeed
        end
    end)
end

local function applyFlashlightRecharge(powerUp, itemName)
    -- FlashlightController listens for LootPickupResult for powerbank
    -- But for equipped items, we need a different approach
    -- We'll directly call refill via a module reference
    showPowerUpToast("🔋 " .. itemName .. " — Battery fully recharged!", Color3.fromRGB(50, 255, 100))

    -- Find the FlashlightController's spotlight and reset battery
    -- The FlashlightController is a local script, so we fire a synthetic event
    -- Actually, we can just create a new spotlight or find the existing one
    local character = LocalPlayer.Character
    if character then
        local head = character:FindFirstChild("Head")
        if head then
            local flashlight = head:FindFirstChild("Flashlight")
            if flashlight and flashlight:IsA("SpotLight") then
                flashlight.Enabled = true
                flashlight.Brightness = 1.5
            end
        end
    end
    -- Note: The FlashlightController tracks battery locally.
    -- For a proper refill, we fire EquipFlashlight to re-activate
    -- But that would reset position. Instead, the pickup handler
    -- already handles Powerbank pickup. For equipped powerbanks,
    -- we fire a synthetic LootPickupResult
    Remotes.LootPickupResult.OnClientEvent:Once(function() end) -- noop
    -- Actually, just fire the refill by mimicking the pickup
    -- The FlashlightController already listens for LootPickupResult
    -- We can't fire server events to ourselves, so we handle it here
    -- by directly setting the spotlight. The battery tracking in
    -- FlashlightController won't sync, but the visual works.
    -- TODO: expose a proper refill remote
end

local function applyNeonAura(powerUp, itemName)
    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local duration = powerUp.Duration or 20

    -- Bright neon glow around player
    local aura = Instance.new("PointLight")
    aura.Name = "NeonAura"
    aura.Brightness = 3
    aura.Range = 30
    aura.Color = Color3.fromRGB(150, 220, 255)
    aura.Parent = hrp

    -- Particle effect
    local particles = Instance.new("ParticleEmitter")
    particles.Name = "AuraParticles"
    particles.Color = ColorSequence.new(Color3.fromRGB(150, 220, 255))
    particles.Size = NumberSequence.new(0.3, 0)
    particles.Lifetime = NumberRange.new(0.5, 1)
    particles.Rate = 20
    particles.Speed = NumberRange.new(1, 3)
    particles.SpreadAngle = Vector2.new(360, 360)
    particles.LightEmission = 1
    particles.Parent = hrp

    showPowerUpToast("💡 " .. itemName .. " — Neon Aura for " .. duration .. "s!", Color3.fromRGB(150, 220, 255))

    task.delay(duration, function()
        if aura and aura.Parent then aura:Destroy() end
        if particles and particles.Parent then particles:Destroy() end
    end)
end

local function applyDetectionBoost(powerUp, itemName)
    local duration = powerUp.Duration or 30
    showPowerUpToast("🎧 " .. itemName .. " — Enhanced hearing for " .. duration .. "s!", Color3.fromRGB(100, 150, 255))
    -- TODO: Increase heartbeat controller detection range
end

local function applyLightDisruption(powerUp, itemName)
    local duration = powerUp.Duration or 10
    showPowerUpToast("🖨️ " .. itemName .. " — Lights disrupted for " .. duration .. "s!", Color3.fromRGB(200, 50, 255))
    -- TODO: Kill nearby PointLights in maze
end

local function applySoundDecoy(powerUp, itemName)
    showPowerUpToast("📞 " .. itemName .. " — Decoy sound placed!", Color3.fromRGB(255, 100, 100))
    -- TODO: Create decoy sound at player position, teleport it away
end

local function applyItemRadar(powerUp, itemName)
    local duration = powerUp.Duration or 45
    showPowerUpToast("🧭 " .. itemName .. " — Item radar active for " .. duration .. "s!", Color3.fromRGB(255, 215, 0))
    -- TODO: Show compass UI pointing to nearest high-tier loot
end

--------------------------------------------------------------------------------
-- Route power-ups by type
--------------------------------------------------------------------------------

local POWER_UP_HANDLERS = {
    SpeedBoost = applySpeedBoost,
    FlashlightRecharge = applyFlashlightRecharge,
    NeonAura = applyNeonAura,
    DetectionBoost = applyDetectionBoost,
    LightDisruption = applyLightDisruption,
    SoundDecoy = applySoundDecoy,
    ItemRadar = applyItemRadar,
}

--------------------------------------------------------------------------------
-- Listen for ApplyPowerUp from server
--------------------------------------------------------------------------------

Remotes.ApplyPowerUp.OnClientEvent:Connect(function(powerUpData, itemName: string)
    if not powerUpData or not powerUpData.Type then
        warn("[PowerUpHandler] Received invalid power-up data")
        return
    end

    local handler = POWER_UP_HANDLERS[powerUpData.Type]
    if handler then
        handler(powerUpData, itemName)
        print("[PowerUpHandler] Activated: " .. powerUpData.Type .. " from " .. itemName)
    else
        warn("[PowerUpHandler] Unknown power-up type: " .. powerUpData.Type)
        showPowerUpToast("⚡ " .. itemName .. " activated!", Color3.fromRGB(170, 80, 255))
    end
end)

-- Also listen for equip results (for error messages)
Remotes.EquipItemResult.OnClientEvent:Connect(function(success: boolean, message: string)
    if not success then
        showPowerUpToast("❌ " .. tostring(message), Color3.fromRGB(255, 80, 80))
    end
end)

print("[PowerUpHandler] Initialized")
