--[[
    HUDController.lua
    =================
    Client LocalScript — builds and manages the player's HUD.
    
    Creates all UI elements programmatically (no Studio ScreenGui needed).
    Listens to RemoteEvents from the server to update displayed values.
    
    UI Elements:
        1. Fragment Display (top-right) — crystal icon + balance
        2. Inventory Counter (below fragments) — "X / 20" format
        3. Flashlight Battery Bar (bottom-left) — fill bar with color gradient
    
    Design: Dark glassmorphism panels, GothamBold font, tweened animations.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
-- UI References (set during creation)
--------------------------------------------------------------------------------

local fragmentLabel: TextLabel = nil
local inventoryLabel: TextLabel = nil
local batteryFillFrame: Frame = nil
local batteryLabel: TextLabel = nil

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
    -- 1. FRAGMENT DISPLAY (Top-Right)
    --------------------------------------------------------------------------
    local fragPanel = createPanel(
        "FragmentPanel",
        UDim2.new(0, 200, 0, 50),
        UDim2.new(1, -215, 0, 15),
        screenGui
    )

    -- Crystal emoji / icon
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

    -- Fragment count
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

    -- "FRAGMENTS" subtitle
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
    -- 2. INVENTORY COUNTER (Below Fragments)
    --------------------------------------------------------------------------
    local invPanel = createPanel(
        "InventoryPanel",
        UDim2.new(0, 200, 0, 44),
        UDim2.new(1, -215, 0, 75),
        screenGui
    )

    -- Backpack icon
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

    -- Inventory count
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
    -- 3. FLASHLIGHT BATTERY BAR (Bottom-Left)
    --------------------------------------------------------------------------
    local battPanel = createPanel(
        "BatteryPanel",
        UDim2.new(0, 220, 0, 50),
        UDim2.new(0, 15, 1, -65),
        screenGui
    )

    -- Battery icon
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

    -- Battery percentage text
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

    -- Battery bar background
    local battBarBg = Instance.new("Frame")
    battBarBg.Name = "BatteryBarBg"
    battBarBg.Size = UDim2.new(1, -20, 0, 12)
    battBarBg.Position = UDim2.new(0, 10, 1, -18)
    battBarBg.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    battBarBg.BackgroundTransparency = 0.2
    battBarBg.BorderSizePixel = 0
    battBarBg.Parent = battPanel

    local battBarBgCorner = Instance.new("UICorner")
    battBarBgCorner.CornerRadius = UDim.new(0, 4)
    battBarBgCorner.Parent = battBarBg

    -- Battery fill bar
    batteryFillFrame = Instance.new("Frame")
    batteryFillFrame.Name = "BatteryFill"
    batteryFillFrame.Size = UDim2.new(1, 0, 1, 0) -- 100% initially
    batteryFillFrame.Position = UDim2.new(0, 0, 0, 0)
    batteryFillFrame.BackgroundColor3 = COLORS.BatteryFull
    batteryFillFrame.BorderSizePixel = 0
    batteryFillFrame.Parent = battBarBg

    local battFillCorner = Instance.new("UICorner")
    battFillCorner.CornerRadius = UDim.new(0, 4)
    battFillCorner.Parent = batteryFillFrame

    -- Subtle glow on the fill bar
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

    print("[HUDController] HUD built successfully")
end

--------------------------------------------------------------------------------
-- Update Functions (called by RemoteEvent listeners)
--------------------------------------------------------------------------------

local function updateFragmentDisplay(newBalance: number)
    if not fragmentLabel then return end

    -- Smooth count-up/down animation
    local startVal = currentFragments
    currentFragments = newBalance

    task.spawn(function()
        local elapsed = 0
        local duration = 0.5
        while elapsed < duration do
            elapsed += task.wait()
            local alpha = math.min(elapsed / duration, 1)
            -- Ease out
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

    -- Quick scale pop effect on the panel
    if fragmentLabel.Parent then
        local panel = fragmentLabel.Parent
        TweenService:Create(panel, TWEEN_INFO_FAST, {
            Size = UDim2.new(0, 210, 0, 54),
        }):Play()
        task.wait(0.15)
        TweenService:Create(panel, TWEEN_INFO, {
            Size = UDim2.new(0, 200, 0, 50),
        }):Play()
    end
end

local function updateInventoryDisplay(count: number, maxSlots: number)
    if not inventoryLabel then return end

    inventoryLabel.Text = tostring(count) .. " / " .. tostring(maxSlots)

    -- Change color when nearly full
    if count >= maxSlots then
        inventoryLabel.TextColor3 = Color3.fromRGB(255, 80, 80) -- Red = FULL
    elseif count >= maxSlots * 0.8 then
        inventoryLabel.TextColor3 = Color3.fromRGB(255, 200, 0) -- Yellow = almost full
    else
        inventoryLabel.TextColor3 = COLORS.InventoryBlue -- Normal blue
    end
end

local function updateBatteryDisplay(percent: number)
    if not batteryFillFrame or not batteryLabel then return end

    percent = math.clamp(percent, 0, 100)
    currentBattery = percent

    -- Determine battery color based on level
    local battColor
    if percent > 60 then
        battColor = COLORS.BatteryFull -- Green
    elseif percent > 25 then
        battColor = COLORS.BatteryMid -- Yellow
    else
        battColor = COLORS.BatteryLow -- Red
    end

    -- Tween the fill bar width and color
    TweenService:Create(batteryFillFrame, TWEEN_INFO, {
        Size = UDim2.new(percent / 100, 0, 1, 0),
        BackgroundColor3 = battColor,
    }):Play()

    -- Update the percentage text
    batteryLabel.Text = tostring(math.floor(percent)) .. "%"
    batteryLabel.TextColor3 = battColor
end

--------------------------------------------------------------------------------
-- Connect RemoteEvent Listeners
--------------------------------------------------------------------------------

Remotes.UpdateFragments.OnClientEvent:Connect(function(newBalance: number)
    updateFragmentDisplay(newBalance)
end)

Remotes.UpdateInventory.OnClientEvent:Connect(function(count: number, maxSlots: number)
    updateInventoryDisplay(count, maxSlots)
end)

Remotes.UpdateBattery.OnClientEvent:Connect(function(percent: number)
    updateBatteryDisplay(percent)
end)

--------------------------------------------------------------------------------
-- Build the HUD on script start
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Hide loot that this player has already picked up
--------------------------------------------------------------------------------

Remotes.HideLootForPlayer.OnClientEvent:Connect(function(lootPart: BasePart)
    if not lootPart or not lootPart:IsA("BasePart") then return end

    -- Make invisible
    lootPart.Transparency = 1

    -- Hide selection box, billboard, particles, lights
    for _, child in ipairs(lootPart:GetChildren()) do
        if child:IsA("BillboardGui") then
            child.Enabled = false
        elseif child:IsA("SelectionBox") then
            child.Visible = false
        elseif child:IsA("ProximityPrompt") then
            child.Enabled = false
        elseif child:IsA("PointLight") then
            child.Enabled = false
        elseif child:IsA("ParticleEmitter") then
            child.Enabled = false
        end
    end
end)

buildHUD()

print("[HUDController] Ready")
