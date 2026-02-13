--[[
    DeathScreen.client.lua
    ======================
    Full-screen death overlay with glitch effects.
    Listens for PlayerDied remote from server.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--------------------------------------------------------------------------------
-- Create Death Screen UI
--------------------------------------------------------------------------------

local function showDeathScreen(deathData)
    local entityName = deathData.entityName or "Unknown Entity"
    local itemsLost = deathData.itemsLost or 0

    -- Main ScreenGui
    local gui = Instance.new("ScreenGui")
    gui.Name = "DeathScreen"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 100
    gui.IgnoreGuiInset = true
    gui.Parent = PlayerGui

    -- Black background
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bg.BackgroundTransparency = 1
    bg.BorderSizePixel = 0
    bg.ZIndex = 1
    bg.Parent = gui

    -- Red vignette overlay
    local vignette = Instance.new("ImageLabel")
    vignette.Size = UDim2.new(1, 0, 1, 0)
    vignette.BackgroundTransparency = 1
    vignette.ImageColor3 = Color3.fromRGB(150, 0, 0)
    vignette.ImageTransparency = 1
    vignette.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
    vignette.ScaleType = Enum.ScaleType.Stretch
    vignette.ZIndex = 2
    vignette.Parent = gui

    -- "YOU DIED" text
    local deathText = Instance.new("TextLabel")
    deathText.Size = UDim2.new(1, 0, 0, 120)
    deathText.Position = UDim2.new(0, 0, 0.3, 0)
    deathText.BackgroundTransparency = 1
    deathText.Text = "YOU DIED"
    deathText.TextColor3 = Color3.fromRGB(200, 0, 0)
    deathText.TextSize = 72
    deathText.Font = Enum.Font.GothamBlack
    deathText.TextTransparency = 1
    deathText.ZIndex = 5
    deathText.Parent = gui

    -- Entity name
    local entityText = Instance.new("TextLabel")
    entityText.Size = UDim2.new(1, 0, 0, 40)
    entityText.Position = UDim2.new(0, 0, 0.45, 0)
    entityText.BackgroundTransparency = 1
    entityText.Text = "Killed by: " .. entityName
    entityText.TextColor3 = Color3.fromRGB(180, 180, 180)
    entityText.TextSize = 22
    entityText.Font = Enum.Font.GothamMedium
    entityText.TextTransparency = 1
    entityText.ZIndex = 5
    entityText.Parent = gui

    -- Items lost
    local lostText = Instance.new("TextLabel")
    lostText.Size = UDim2.new(1, 0, 0, 30)
    lostText.Position = UDim2.new(0, 0, 0.52, 0)
    lostText.BackgroundTransparency = 1
    lostText.Text = "Items lost: " .. tostring(itemsLost) .. " (Legendaries are safe)"
    lostText.TextColor3 = Color3.fromRGB(255, 200, 100)
    lostText.TextSize = 18
    lostText.Font = Enum.Font.GothamMedium
    lostText.TextTransparency = 1
    lostText.ZIndex = 5
    lostText.Parent = gui

    -- Returning countdown
    local countdownText = Instance.new("TextLabel")
    countdownText.Size = UDim2.new(1, 0, 0, 30)
    countdownText.Position = UDim2.new(0, 0, 0.62, 0)
    countdownText.BackgroundTransparency = 1
    countdownText.Text = "Returning to lobby..."
    countdownText.TextColor3 = Color3.fromRGB(120, 120, 140)
    countdownText.TextSize = 16
    countdownText.Font = Enum.Font.Gotham
    countdownText.TextTransparency = 1
    countdownText.ZIndex = 5
    countdownText.Parent = gui

    -- Glitch lines (horizontal scan lines)
    for i = 1, 8 do
        local line = Instance.new("Frame")
        line.Size = UDim2.new(1, 0, 0, math.random(2, 6))
        line.Position = UDim2.new(0, 0, math.random() * 0.8 + 0.1, 0)
        line.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
        line.BackgroundTransparency = 0.7
        line.BorderSizePixel = 0
        line.ZIndex = 3
        line.Parent = gui

        -- Animate glitch lines
        task.spawn(function()
            while gui.Parent do
                line.Position = UDim2.new(math.random() * 0.2 - 0.1, 0, math.random() * 0.8 + 0.1, 0)
                line.Size = UDim2.new(math.random() * 0.5 + 0.5, 0, 0, math.random(1, 4))
                line.BackgroundTransparency = math.random() * 0.5 + 0.4
                task.wait(0.05 + math.random() * 0.1)
            end
        end)
    end

    -- === Animate in ===

    -- Fade background to red-black
    TweenService:Create(bg, TweenInfo.new(0.5), { BackgroundTransparency = 0.15 }):Play()
    TweenService:Create(vignette, TweenInfo.new(0.3), { ImageTransparency = 0.4 }):Play()

    task.wait(0.3)

    -- Camera shake effect
    local camera = Workspace.CurrentCamera
    if camera then
        task.spawn(function()
            for _ = 1, 10 do
                local offset = CFrame.Angles(
                    math.rad(math.random(-3, 3)),
                    math.rad(math.random(-3, 3)),
                    0
                )
                camera.CFrame = camera.CFrame * offset
                task.wait(0.05)
            end
        end)
    end

    -- "YOU DIED" slam in
    deathText.TextSize = 120
    TweenService:Create(deathText, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        TextTransparency = 0,
        TextSize = 72,
    }):Play()

    task.wait(0.6)

    -- Fade in details
    TweenService:Create(entityText, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
    task.wait(0.3)
    TweenService:Create(lostText, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
    task.wait(0.3)
    TweenService:Create(countdownText, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()

    -- Glitch the "YOU DIED" text periodically
    task.spawn(function()
        local glitchTexts = {"Y0U D1ED", "YO▓ DIED", "YOU █IED", "Y█U DI▓D", "YOU DIED"}
        while gui.Parent do
            if math.random() < 0.3 then
                deathText.Text = glitchTexts[math.random(1, #glitchTexts)]
                deathText.Position = UDim2.new(math.random() * 0.02 - 0.01, 0, 0.3, 0)
                task.wait(0.05)
                deathText.Text = "YOU DIED"
                deathText.Position = UDim2.new(0, 0, 0.3, 0)
            end
            task.wait(0.2 + math.random() * 0.3)
        end
    end)

    -- Wait for server to teleport us back, then fade out
    task.wait(2.5)

    TweenService:Create(bg, TweenInfo.new(0.5), { BackgroundTransparency = 0 }):Play()
    task.wait(0.6)
    gui:Destroy()
end

--------------------------------------------------------------------------------
-- Listen for death event
--------------------------------------------------------------------------------

Remotes.PlayerDied.OnClientEvent:Connect(function(deathData)
    showDeathScreen(deathData or {})
end)

-- Also listen for return to hub (cleanup)
Remotes.ReturnToHub.OnClientEvent:Connect(function(message)
    -- Remove any lingering death screens
    local existing = PlayerGui:FindFirstChild("DeathScreen")
    if existing then existing:Destroy() end
end)

print("[DeathScreen] Initialized")
