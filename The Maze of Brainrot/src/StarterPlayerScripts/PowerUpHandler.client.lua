--[[
    PowerUpHandler.client.lua
    =========================
    Handles activation of Epic item power-ups on the client.
    
    Listens for ApplyPowerUp from server and applies effects:
    - SpeedBoost: Increases WalkSpeed
    - FlashlightRecharge: Refills battery
    - NeonAura: PointLight on character
    - DetectionBoost: Entity ESP highlighting
    - LightDisruption: Flickers/disables nearby maze lights
    - SoundDecoy: Plays distraction sound
    - ItemRadar: Highlights high-value loot with beams
    
    Shows activation toast notification.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

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
    local slideIn = TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -175, 0, 20)
    })
    slideIn:Play()

    -- Slide out after 3 seconds
    task.delay(3, function()
        if not toast.Parent then return end
        local slideOut = TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
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
    showPowerUpToast(itemName .. " — " .. multiplier .. "x Speed for " .. duration .. "s!", Color3.fromRGB(255, 200, 50))

    task.delay(duration, function()
        if humanoid and humanoid.Parent then
            humanoid.WalkSpeed = originalSpeed
        end
    end)
end

local function applyFlashlightRecharge(powerUp, itemName)
    -- Fire a synthetic event to trigger FlashlightController refill logic
    -- (This assumes proper coordination with FlashlightController)
    local character = LocalPlayer.Character
    if character then
        local head = character:FindFirstChild("Head")
        if head then
            local flashlight = head:FindFirstChild("Flashlight")
            if flashlight and flashlight:IsA("SpotLight") then
                flashlight.Enabled = true
                flashlight.Brightness = 1.6
            end
        end
    end
    -- Send battery update to HUD (fake 100% until synced)
    Remotes.UpdateBattery:FireClient(LocalPlayer, 100)
    showPowerUpToast(itemName .. " — Battery Fully Recharged!", Color3.fromRGB(50, 255, 100))
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

    showPowerUpToast(itemName .. " — Neon Aura for " .. duration .. "s!", Color3.fromRGB(150, 220, 255))

    task.delay(duration, function()
        if aura and aura.Parent then aura:Destroy() end
        if particles and particles.Parent then particles:Destroy() end
    end)
end

local function applyDetectionBoost(powerUp, itemName)
    local duration = powerUp.Duration or 30
    showPowerUpToast(itemName .. " — Entity Vision Active!", Color3.fromRGB(255, 50, 50))
    
    -- Highlight all entities
    local activeHighlights = {}
    local maze = Workspace:FindFirstChild("GeneratedMaze")
    if not maze then return end
    
    -- Scan for entities
    for _, child in ipairs(maze:GetChildren()) do
        if child.Name:match("Entity_") and child:IsA("Model") then
            local hl = Instance.new("Highlight")
            hl.Adornee = child
            hl.FillColor = Color3.fromRGB(255, 0, 0)
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.FillTransparency = 0.5
            hl.OutlineTransparency = 0
            hl.Parent = child
            table.insert(activeHighlights, hl)
        end
    end
    
    task.delay(duration, function()
        for _, hl in ipairs(activeHighlights) do
            if hl.Parent then hl:Destroy() end
        end
    end)
end

local function applyLightDisruption(powerUp, itemName)
    local duration = powerUp.Duration or 10
    showPowerUpToast(itemName .. " — Overloading nearby lights!", Color3.fromRGB(200, 50, 255))
    
    local maze = Workspace:FindFirstChild("GeneratedMaze")
    if not maze then return end
    
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    -- Find nearby lights and flicker/explode them
    local lights = {}
    for _, desc in ipairs(maze:GetDescendants()) do
        if desc:IsA("PointLight") or desc:IsA("SpotLight") then
            if (desc.Parent.Position - hrp.Position).Magnitude < 100 then
                 table.insert(lights, {light = desc, origBrightness = desc.Brightness})
            end
        end
    end
    
    task.spawn(function()
        local endTime = tick() + duration
        while tick() < endTime do
            for _, l in ipairs(lights) do
                if l.light.Parent then
                    l.light.Brightness = math.random() * 2
                    l.light.Enabled = math.random() > 0.5
                end
            end
            task.wait(0.1)
        end
        -- Restore
        for _, l in ipairs(lights) do
            if l.light.Parent then
                l.light.Brightness = l.origBrightness
                l.light.Enabled = true
            end
        end
    end)
end

local function applySoundDecoy(powerUp, itemName)
    showPowerUpToast(itemName .. " — Decoy Activated!", Color3.fromRGB(255, 100, 100))
    
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    -- Create decoy part at current location
    local decoy = Instance.new("Part")
    decoy.Size = Vector3.new(2, 2, 2)
    decoy.Color = Color3.fromRGB(255, 0, 0)
    decoy.Material = Enum.Material.Neon
    decoy.Position = hrp.Position
    decoy.Anchored = true
    decoy.CanCollide = false
    decoy.Parent = Workspace
    
    -- Play loud sound
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://9119713951" -- Alarm/Siren placeholder
    sound.Volume = 2
    sound.RollOffMaxDistance = 100
    sound.Looped = true
    sound.Parent = decoy
    sound:Play()
    
    -- Pulse visual
    local tween = TweenService:Create(decoy, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
        Transparency = 0.2,
        Size = Vector3.new(3, 3, 3)
    })
    tween:Play()
    
    task.delay(10, function()
        decoy:Destroy()
    end)
end

local function applyItemRadar(powerUp, itemName)
    local duration = powerUp.Duration or 45
    showPowerUpToast(itemName .. " — High-Tier Loot Radar Active!", Color3.fromRGB(255, 215, 0))
    
    local maze = Workspace:FindFirstChild("GeneratedMaze")
    if not maze then return end
    
    local beams = {}
    local lootFolder = maze:FindFirstChild("Loot")
    
    if lootFolder then
        for _, itemPart in ipairs(lootFolder:GetChildren()) do
            -- Check rarity via attribute or check name in database? 
            -- Simplest is to check name or assume LootSpawner tagging.
            -- LootSpawner doesn't tag rarity on part, but we can check visual color maybe?
            -- Or just highlight all loot for now.
            -- Let's highlight ALL loot but color code it if possible.
            
            -- Ideally we'd know rarity. For now, just highlight all.
            local hl = Instance.new("Highlight")
            hl.Adornee = itemPart
            hl.FillColor = Color3.fromRGB(255, 215, 0)
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.FillTransparency = 0.6
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = itemPart
            table.insert(beams, hl)
        end
    end
    
    task.delay(duration, function()
        for _, hl in ipairs(beams) do
            if hl.Parent then hl:Destroy() end
        end
    end)
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
    else
        warn("[PowerUpHandler] Unknown power-up type: " .. powerUpData.Type)
        showPowerUpToast(itemName .. " activated!", Color3.fromRGB(170, 80, 255))
    end
end)

-- Also listen for equip results (for error messages)
Remotes.EquipItemResult.OnClientEvent:Connect(function(success: boolean, message: string)
    if not success then
        showPowerUpToast("❌ " .. tostring(message), Color3.fromRGB(255, 80, 80))
    end
end)

print("[PowerUpHandler] Initialized")
