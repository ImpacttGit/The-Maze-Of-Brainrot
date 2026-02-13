--[[
    HUDController.lua
    =================
    Client LocalScript — builds and manages the player's HUD.
    
    Creates all UI elements programmatically (no Studio ScreenGui needed).
    Listens to RemoteEvents from the server to update displayed values.
    
    UI Elements:
        1. Fragment Display (top-right) — crystal icon + balance
        2. Inventory Counter (below fragments) — "X / 20" format
        3. Level & XP Panel (top-left) — Level, Prestige stars, XP bar
        4. Battery Bar (bottom-left)
        5. Keybind Hints (bottom-center)
        6. Shop Buttons (bottom-right) — Crates, Game Passes
    
    Design: Dark glassmorphism panels, GothamBold font, tweened animations.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local HUDController = {}

--------------------------------------------------------------------------------
-- Design Tokens
--------------------------------------------------------------------------------

local COLORS = {
    PanelBackground = Color3.fromRGB(15, 15, 20),
    PanelStroke = Color3.fromRGB(80, 80, 100),
    TextPrimary = Color3.fromRGB(240, 240, 245),
    TextSecondary = Color3.fromRGB(170, 170, 190),
    FragmentGold = Color3.fromRGB(255, 215, 0),
    BatteryFull = Color3.fromRGB(0, 220, 80),
    BatteryMid = Color3.fromRGB(255, 200, 0),
    BatteryLow = Color3.fromRGB(255, 50, 50),
    InventoryBlue = Color3.fromRGB(100, 160, 255),
    AccentPurple = Color3.fromRGB(163, 53, 238),
    XPBlue = Color3.fromRGB(50, 150, 255),
    PrestigeRed = Color3.fromRGB(255, 60, 60),
}

local FONTS = {
    Bold = Enum.Font.GothamBold,
    Medium = Enum.Font.GothamMedium,
    Regular = Enum.Font.Gotham,
}

local PANEL_TRANSPARENCY = 0.35
local CORNER_RADIUS = UDim.new(0, 8)
local TWEEN_INFO = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TWEEN_INFO_FAST = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

--------------------------------------------------------------------------------
-- UI References
--------------------------------------------------------------------------------

local fragmentLabel: TextLabel
local inventoryLabel: TextLabel
local batteryFillFrame: Frame
local batteryLabel: TextLabel
local levelLabel: TextLabel
local xpFillFrame: Frame
local prestigeContainer: Frame

-- Current values for smooth tweening
local currentFragments = 0
local currentBattery = 100

--------------------------------------------------------------------------------
-- Helper: Create a rounded panel
--------------------------------------------------------------------------------

local function createPanel(name: string, size: UDim2, position: UDim2, parent: Instance): Frame
    local panel = Instance.new("Frame")
    panel.Name = name
    panel.Size = size
    panel.Position = position
    panel.BackgroundColor3 = COLORS.PanelBackground
    panel.BackgroundTransparency = PANEL_TRANSPARENCY
    panel.BorderSizePixel = 0
    panel.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = CORNER_RADIUS
    corner.Parent = panel

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.PanelStroke
    stroke.Thickness = 1.5
    stroke.Transparency = 0.4
    stroke.Parent = panel

    return panel
end

local function createButton(name: string, text: string, color: Color3, parent: Instance): TextButton
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(0, 50, 0, 50)
    btn.BackgroundColor3 = COLORS.PanelBackground
    btn.BackgroundTransparency = 0.3
    btn.Text = text
    btn.TextColor3 = color
    btn.TextSize = 24
    btn.Font = FONTS.Bold
    btn.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = 1.5
    stroke.Transparency = 0.5
    stroke.Parent = btn
    
    -- Subtitle
    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, 0, 0, 15)
    sub.Position = UDim2.new(0, 0, 1, 2)
    sub.BackgroundTransparency = 1
    sub.Text = name
    sub.TextColor3 = COLORS.TextSecondary
    sub.TextSize = 10
    sub.Font = FONTS.Medium
    sub.Parent = btn

    return btn
end

--------------------------------------------------------------------------------
-- Build the HUD
--------------------------------------------------------------------------------

local function buildHUD()
    -- Main ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MainHUD"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = false
    screenGui.Parent = PlayerGui

    --------------------------------------------------------------------------
    -- 1. LEVEL & PRESTIGE (Top-Left)
    --------------------------------------------------------------------------
    local levelPanel = createPanel(
        "LevelPanel",
        UDim2.new(0, 220, 0, 60),
        UDim2.new(0, 15, 0, 15),
        screenGui
    )
    
    -- Level Label
    levelLabel = Instance.new("TextLabel")
    levelLabel.Name = "LevelLabel"
    levelLabel.Size = UDim2.new(1, -20, 0, 25)
    levelLabel.Position = UDim2.new(0, 10, 0, 5)
    levelLabel.BackgroundTransparency = 1
    levelLabel.Text = "LEVEL 1"
    levelLabel.TextSize = 18
    levelLabel.Font = FONTS.Bold
    levelLabel.TextColor3 = COLORS.XPBlue
    levelLabel.TextXAlignment = Enum.TextXAlignment.Left
    levelLabel.Parent = levelPanel
    
    -- Prestige Stars Container
    prestigeContainer = Instance.new("Frame")
    prestigeContainer.Name = "PrestigeContainer"
    prestigeContainer.Size = UDim2.new(0, 100, 0, 20)
    prestigeContainer.Position = UDim2.new(0, 100, 0, 8)
    prestigeContainer.BackgroundTransparency = 1
    prestigeContainer.Parent = levelPanel

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 2)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = prestigeContainer

    -- XP Bar Background
    local xpBg = Instance.new("Frame")
    xpBg.Size = UDim2.new(1, -20, 0, 8)
    xpBg.Position = UDim2.new(0, 10, 0, 35)
    xpBg.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    xpBg.BorderSizePixel = 0
    xpBg.Parent = levelPanel
    
    local xpCorner = Instance.new("UICorner")
    xpCorner.CornerRadius = UDim.new(0, 4)
    xpCorner.Parent = xpBg
    
    -- XP Fill
    xpFillFrame = Instance.new("Frame")
    xpFillFrame.Size = UDim2.new(0, 0, 1, 0)
    xpFillFrame.BackgroundColor3 = COLORS.XPBlue
    xpFillFrame.BorderSizePixel = 0
    xpFillFrame.Parent = xpBg
    
    local xpFillCorner = Instance.new("UICorner")
    xpFillCorner.CornerRadius = UDim.new(0, 4)
    xpFillCorner.Parent = xpFillFrame

    --------------------------------------------------------------------------
    -- 2. FRAGMENT DISPLAY (Top-Right)
    --------------------------------------------------------------------------
    local fragPanel = createPanel(
        "FragmentPanel",
        UDim2.new(0, 200, 0, 50),
        UDim2.new(1, -215, 0, 15),
        screenGui
    )

    local fragIcon = Instance.new("TextLabel")
    fragIcon.Name = "FragmentIcon"
    fragIcon.Size = UDim2.new(0, 36, 1, 0)
    fragIcon.Position = UDim2.new(0, 8, 0, 0)
    fragIcon.BackgroundTransparency = 1
    fragIcon.Text = "💎"
    fragIcon.TextSize = 22
    fragIcon.Font = FONTS.Regular
    fragIcon.TextColor3 = COLORS.FragmentGold
    fragIcon.Parent = fragPanel

    fragmentLabel = Instance.new("TextLabel")
    fragmentLabel.Name = "FragmentCount"
    fragmentLabel.Size = UDim2.new(1, -50, 1, 0)
    fragmentLabel.Position = UDim2.new(0, 44, 0, 0)
    fragmentLabel.BackgroundTransparency = 1
    fragmentLabel.Text = "0"
    fragmentLabel.TextSize = 22
    fragmentLabel.Font = FONTS.Bold
    fragmentLabel.TextColor3 = COLORS.FragmentGold
    fragmentLabel.TextXAlignment = Enum.TextXAlignment.Left
    fragmentLabel.Parent = fragPanel

    local fragSubtitle = Instance.new("TextLabel")
    fragSubtitle.Name = "FragmentSubtitle"
    fragSubtitle.Size = UDim2.new(0, 90, 0, 14)
    fragSubtitle.Position = UDim2.new(0, 44, 1, -16)
    fragSubtitle.BackgroundTransparency = 1
    fragSubtitle.Text = "FRAGMENTS"
    fragSubtitle.TextSize = 9
    fragSubtitle.Font = FONTS.Medium
    fragSubtitle.TextColor3 = COLORS.TextSecondary
    fragSubtitle.TextXAlignment = Enum.TextXAlignment.Left
    fragSubtitle.Parent = fragPanel

    --------------------------------------------------------------------------
    -- 3. INVENTORY COUNTER (Below Fragments)
    --------------------------------------------------------------------------
    local invPanel = createPanel(
        "InventoryPanel",
        UDim2.new(0, 200, 0, 44),
        UDim2.new(1, -215, 0, 75),
        screenGui
    )

    local invIcon = Instance.new("TextLabel")
    invIcon.Name = "InventoryIcon"
    invIcon.Size = UDim2.new(0, 36, 1, 0)
    invIcon.Position = UDim2.new(0, 8, 0, 0)
    invIcon.BackgroundTransparency = 1
    invIcon.Text = "🎒"
    invIcon.TextSize = 20
    invIcon.Font = FONTS.Regular
    invIcon.TextColor3 = COLORS.InventoryBlue
    invIcon.Parent = invPanel

    inventoryLabel = Instance.new("TextLabel")
    inventoryLabel.Name = "InventoryCount"
    inventoryLabel.Size = UDim2.new(1, -50, 1, 0)
    inventoryLabel.Position = UDim2.new(0, 44, 0, 0)
    inventoryLabel.BackgroundTransparency = 1
    inventoryLabel.Text = "0 / 20"
    inventoryLabel.TextSize = 20
    inventoryLabel.Font = FONTS.Bold
    inventoryLabel.TextColor3 = COLORS.InventoryBlue
    inventoryLabel.TextXAlignment = Enum.TextXAlignment.Left
    inventoryLabel.Parent = invPanel

    --------------------------------------------------------------------------
    -- 4. FLASHLIGHT BATTERY BAR (Bottom-Left)
    --------------------------------------------------------------------------
    local battPanel = createPanel(
        "BatteryPanel",
        UDim2.new(0, 220, 0, 50),
        UDim2.new(0, 15, 1, -65),
        screenGui
    )

    local battIcon = Instance.new("TextLabel")
    battIcon.Name = "BatteryIcon"
    battIcon.Size = UDim2.new(0, 30, 0, 20)
    battIcon.Position = UDim2.new(0, 8, 0, 4)
    battIcon.BackgroundTransparency = 1
    battIcon.Text = "🔦"
    battIcon.TextSize = 16
    battIcon.Font = FONTS.Regular
    battIcon.TextColor3 = COLORS.TextPrimary
    battIcon.Parent = battPanel

    batteryLabel = Instance.new("TextLabel")
    batteryLabel.Name = "BatteryPercent"
    batteryLabel.Size = UDim2.new(0, 50, 0, 20)
    batteryLabel.Position = UDim2.new(1, -58, 0, 4)
    batteryLabel.BackgroundTransparency = 1
    batteryLabel.Text = "100%"
    batteryLabel.TextSize = 14
    batteryLabel.Font = FONTS.Bold
    batteryLabel.TextColor3 = COLORS.BatteryFull
    batteryLabel.TextXAlignment = Enum.TextXAlignment.Right
    batteryLabel.Parent = battPanel

    local battBarBg = Instance.new("Frame")
    battBarBg.Size = UDim2.new(1, -20, 0, 12)
    battBarBg.Position = UDim2.new(0, 10, 1, -18)
    battBarBg.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    battBarBg.BackgroundTransparency = 0.2
    battBarBg.BorderSizePixel = 0
    battBarBg.Parent = battPanel

    local battBarBgCorner = Instance.new("UICorner")
    battBarBgCorner.CornerRadius = UDim.new(0, 4)
    battBarBgCorner.Parent = battBarBg

    batteryFillFrame = Instance.new("Frame")
    batteryFillFrame.Size = UDim2.new(1, 0, 1, 0)
    batteryFillFrame.BackgroundColor3 = COLORS.BatteryFull
    batteryFillFrame.BorderSizePixel = 0
    batteryFillFrame.Parent = battBarBg

    local battFillCorner = Instance.new("UICorner")
    battFillCorner.CornerRadius = UDim.new(0, 4)
    battFillCorner.Parent = batteryFillFrame

    local battGlow = Instance.new("UIGradient")
    battGlow.Rotation = 90
    battGlow.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 200, 200)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
    })
    battGlow.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.7),
        NumberSequenceKeypoint.new(0.5, 0.85),
        NumberSequenceKeypoint.new(1, 0.7),
    })
    battGlow.Parent = batteryFillFrame

    --------------------------------------------------------------------------
    -- 5. BUTTONS (Bottom-Right)
    --------------------------------------------------------------------------
    local btnContainer = Instance.new("Frame")
    btnContainer.Size = UDim2.new(0, 120, 0, 60)
    btnContainer.Position = UDim2.new(1, -140, 1, -75)
    btnContainer.BackgroundTransparency = 1
    btnContainer.Parent = screenGui
    
    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Horizontal
    list.Padding = UDim.new(0, 15)
    list.HorizontalAlignment = Enum.HorizontalAlignment.Right
    list.Parent = btnContainer
    
    local crateBtn = createButton("CRATES", "📦", COLORS.InventoryBlue, btnContainer)
    crateBtn.MouseButton1Click:Connect(function()
        local toggleEvent = ReplicatedStorage:FindFirstChild("ToggleCrateShop")
        if toggleEvent then
            toggleEvent:Fire()
        else
            warn("[HUDController] ToggleCrateShop event not found")
        end
    end)
    
    local passBtn = createButton("PASSES", "⚡", COLORS.FragmentGold, btnContainer)
    passBtn.MouseButton1Click:Connect(function()
        Remotes.CheckGamePasses:FireServer()
        -- GamePassClient should handle the UI showing locally
        -- Ideally we'd toggle GamePassClient UI here too
    end)

    --------------------------------------------------------------------------
    -- 6. KEYBIND HINTS (Bottom-Center)
    --------------------------------------------------------------------------
    local hintPanel = Instance.new("Frame")
    hintPanel.Size = UDim2.new(0, 300, 0, 30)
    hintPanel.Position = UDim2.new(0.5, -150, 1, -40)
    hintPanel.BackgroundTransparency = 1
    hintPanel.Parent = screenGui
    
    local hintText = Instance.new("TextLabel")
    hintText.Size = UDim2.new(1, 0, 1, 0)
    hintText.BackgroundTransparency = 1
    hintText.Text = "[G] INVENTORY     [F] FLASHLIGHT"
    hintText.TextColor3 = COLORS.TextSecondary
    hintText.TextSize = 12
    hintText.Font = FONTS.Bold
    hintText.TextTransparency = 0.5
    hintText.Parent = hintPanel

    print("[HUDController] HUD built successfully")
end

--------------------------------------------------------------------------------
-- Update Functions
--------------------------------------------------------------------------------

local function updateFragmentDisplay(newBalance: number)
    if not fragmentLabel then return end

    local startVal = currentFragments
    currentFragments = newBalance

    task.spawn(function()
        local elapsed = 0
        local duration = 0.5
        while elapsed < duration do
            elapsed += task.wait()
            local alpha = math.min(elapsed / duration, 1)
            alpha = 1 - (1 - alpha) ^ 3
            local displayVal = math.floor(startVal + (newBalance - startVal) * alpha)
            if fragmentLabel then
                fragmentLabel.Text = tostring(displayVal)
            end
        end
        if fragmentLabel then
            fragmentLabel.Text = tostring(newBalance)
        end
    end)

    if fragmentLabel.Parent then
        local panel = fragmentLabel.Parent
        TweenService:Create(panel, TWEEN_INFO_FAST, { Size = UDim2.new(0, 210, 0, 54) }):Play()
        task.wait(0.15)
        TweenService:Create(panel, TWEEN_INFO, { Size = UDim2.new(0, 200, 0, 50) }):Play()
    end
end

local function updateInventoryDisplay(count: number, maxSlots: number)
    if not inventoryLabel then return end
    inventoryLabel.Text = tostring(count) .. " / " .. tostring(maxSlots)
    if count >= maxSlots then
        inventoryLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    elseif count >= maxSlots * 0.8 then
        inventoryLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
    else
        inventoryLabel.TextColor3 = COLORS.InventoryBlue
    end
end

local function updateBatteryDisplay(percent: number)
    if not batteryFillFrame or not batteryLabel then return end
    percent = math.clamp(percent, 0, 100)
    currentBattery = percent
    local battColor
    if percent > 60 then battColor = COLORS.BatteryFull
    elseif percent > 25 then battColor = COLORS.BatteryMid
    else battColor = COLORS.BatteryLow end

    TweenService:Create(batteryFillFrame, TWEEN_INFO, {
        Size = UDim2.new(percent / 100, 0, 1, 0),
        BackgroundColor3 = battColor,
    }):Play()
    batteryLabel.Text = tostring(math.floor(percent)) .. "%"
    batteryLabel.TextColor3 = battColor
end

local function updateXP(xp: number, level: number, prestige: number)
    if not levelLabel or not xpFillFrame then return end
    
    local xpNeeded = level * 150
    local percent = math.clamp(xp / xpNeeded, 0, 1)
    
    levelLabel.Text = "LEVEL " .. tostring(level)
    TweenService:Create(xpFillFrame, TWEEN_INFO, { Size = UDim2.new(percent, 0, 1, 0) }):Play()
    
    -- Update stats
    if prestigeContainer then
        for _, child in ipairs(prestigeContainer:GetChildren()) do
            if child:IsA("TextLabel") then child:Destroy() end
        end
        for i = 1, prestige do
            local star = Instance.new("TextLabel")
            star.Text = "⭐"
            star.TextSize = 14
            star.Size = UDim2.new(0, 15, 1, 0)
            star.BackgroundTransparency = 1
            star.Parent = prestigeContainer
        end
    end
end

--------------------------------------------------------------------------------
-- Connect RemoteEvent Listeners
--------------------------------------------------------------------------------

Remotes.UpdateFragments.OnClientEvent:Connect(updateFragmentDisplay)
Remotes.UpdateInventory.OnClientEvent:Connect(updateInventoryDisplay)
Remotes.UpdateBattery.OnClientEvent:Connect(updateBatteryDisplay)

Remotes.UpdateXP.OnClientEvent:Connect(function(xp, level, prestige)
    updateXP(xp or 0, level or 1, prestige or 0)
end)

Remotes.UpdateLevel.OnClientEvent:Connect(function(newLevel)
    -- Level Up Celebration?
    if levelLabel then
        local originalColor = levelLabel.TextColor3
        for i = 1, 3 do
            levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            task.wait(0.1)
            levelLabel.TextColor3 = COLORS.FragmentGold
            task.wait(0.1)
        end
        levelLabel.TextColor3 = originalColor
    end
end)

--------------------------------------------------------------------------------
-- Hide loot that this player has already picked up
--------------------------------------------------------------------------------

Remotes.HideLootForPlayer.OnClientEvent:Connect(function(lootPart: BasePart)
    if not lootPart or not lootPart:IsA("BasePart") then return end
    lootPart.Transparency = 1
    for _, child in ipairs(lootPart:GetChildren()) do
        if child:IsA("BillboardGui") or child:IsA("SelectionBox") or child:IsA("ProximityPrompt") or child:IsA("PointLight") or child:IsA("ParticleEmitter") then
            child.Enabled = false
            if child:IsA("SelectionBox") then child.Visible = false end
        end
    end
end)

buildHUD()

print("[HUDController] Ready")
