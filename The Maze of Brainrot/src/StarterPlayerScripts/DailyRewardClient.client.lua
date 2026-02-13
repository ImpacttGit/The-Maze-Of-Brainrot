--[[
    DailyRewardClient.lua
    =====================
    Client LocalScript — Daily Reward UI.
    
    Features:
    - 7-Day calendar view.
    - Shows current streak progress.
    - Claim button for available rewards.
    - Auto-opens on join if reward available.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--------------------------------------------------------------------------------
-- UI Constants
--------------------------------------------------------------------------------

local COLORS = {
    Bg = Color3.fromRGB(12, 12, 18),
    DayBg = Color3.fromRGB(20, 20, 30),
    CurrentDayBg = Color3.fromRGB(40, 35, 60),
    ClaimedBg = Color3.fromRGB(15, 40, 20),
    LockedText = Color3.fromRGB(100, 100, 120),
    ActiveText = Color3.fromRGB(255, 255, 255),
    Gold = Color3.fromRGB(255, 215, 0),
    Green = Color3.fromRGB(50, 220, 100),
    Purple = Color3.fromRGB(170, 80, 255),
}

--------------------------------------------------------------------------------
-- Build UI
--------------------------------------------------------------------------------

local rewardGui = Instance.new("ScreenGui")
rewardGui.Name = "DailyRewardUI"
rewardGui.ResetOnSpawn = false
rewardGui.DisplayOrder = 25
rewardGui.Enabled = false
rewardGui.IgnoreGuiInset = true
rewardGui.Parent = PlayerGui

local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3 = Color3.new(0,0,0)
backdrop.BackgroundTransparency = 0.4
backdrop.Parent = rewardGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 700, 0, 450)
mainFrame.Position = UDim2.new(0.5, -350, 0.5, -225)
mainFrame.BackgroundColor3 = COLORS.Bg
mainFrame.BorderSizePixel = 0
mainFrame.Parent = rewardGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 60)
title.BackgroundTransparency = 1
title.Text = "📅 DAILY REWARDS"
title.TextColor3 = COLORS.Gold
title.TextSize = 28
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -45, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.Parent = mainFrame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

-- Days Container
local daysContainer = Instance.new("Frame")
daysContainer.Size = UDim2.new(1, -40, 0, 280)
daysContainer.Position = UDim2.new(0, 20, 0, 80)
daysContainer.BackgroundTransparency = 1
daysContainer.Parent = mainFrame

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0, 85, 0, 120) -- 7 items width approx
grid.CellPadding = UDim2.new(0, 10, 0, 10)
grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
grid.Parent = daysContainer

-- Claim Button
local claimBtn = Instance.new("TextButton")
claimBtn.Size = UDim2.new(0, 200, 0, 50)
claimBtn.Position = UDim2.new(0.5, -100, 1, -70)
claimBtn.BackgroundColor3 = COLORS.Green
claimBtn.Text = "CLAIM REWARD"
claimBtn.TextColor3 = Color3.new(1,1,1)
claimBtn.Font = Enum.Font.GothamBold
claimBtn.TextSize = 20
claimBtn.Parent = mainFrame
Instance.new("UICorner", claimBtn).CornerRadius = UDim.new(0, 10)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 20)
statusLabel.Position = UDim2.new(0, 0, 1, -15)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Come back tomorrow for more!"
statusLabel.TextColor3 = COLORS.LockedText
statusLabel.TextSize = 14
statusLabel.Font = Enum.Font.Gotham
statusLabel.Parent = mainFrame

--------------------------------------------------------------------------------
-- Logic
--------------------------------------------------------------------------------

local dayFrames = {}

local function createDayFrame(dayIdx, rewardData)
    local frame = Instance.new("Frame")
    frame.BackgroundColor3 = COLORS.DayBg
    frame.BorderSizePixel = 0
    frame.Parent = daysContainer
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    
    local dayLabel = Instance.new("TextLabel")
    dayLabel.Size = UDim2.new(1, 0, 0, 25)
    dayLabel.BackgroundTransparency = 1
    dayLabel.Text = "Day " .. dayIdx
    dayLabel.TextColor3 = COLORS.LockedText
    dayLabel.Font = Enum.Font.GothamBold
    dayLabel.TextSize = 14
    dayLabel.Parent = frame
    
    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(1, 0, 0, 50)
    icon.Position = UDim2.new(0, 0, 0, 30)
    icon.BackgroundTransparency = 1
    icon.Text = rewardData.Type == "Fragments" and "💎" or "📦"
    icon.TextSize = 30
    icon.Parent = frame
    
    local amountLabel = Instance.new("TextLabel")
    amountLabel.Size = UDim2.new(1, 0, 0, 20)
    amountLabel.Position = UDim2.new(0, 0, 0, 80)
    amountLabel.BackgroundTransparency = 1
    if rewardData.Type == "Fragments" then
        amountLabel.Text = rewardData.Amount
    else
        amountLabel.Text = rewardData.Rarity
        amountLabel.TextColor3 = COLORS.Purple
    end
    amountLabel.TextColor3 = COLORS.ActiveText
    amountLabel.Font = Enum.Font.GothamBold
    amountLabel.TextSize = 12
    amountLabel.Parent = frame
    
    -- Overlay for state (tick, lock)
    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundTransparency = 1
    overlay.ZIndex = 2
    overlay.Parent = frame
    
    local check = Instance.new("TextLabel")
    check.Size = UDim2.new(1, 0, 1, 0)
    check.BackgroundTransparency = 1
    check.Text = "✓"
    check.TextSize = 40
    check.TextColor3 = COLORS.Green
    check.Visible = false
    check.Parent = overlay
    
    dayFrames[dayIdx] = {
        Frame = frame,
        Check = check,
        Reward = rewardData
    }
end

-- Initialize 7 days placeholder (will update with real data)
-- Actually wait for data. But build structure first.
local DEFAULT_CYCLE = {
    { Type = "Fragments", Amount = 100 },
    { Type = "Fragments", Amount = 200 },
    { Type = "Fragments", Amount = 350 },
    { Type = "Item", Rarity = "Common" },
    { Type = "Fragments", Amount = 500 },
    { Type = "Item", Rarity = "Rare" },
    { Type = "Item", Rarity = "Epic" },
}

for i, data in ipairs(DEFAULT_CYCLE) do
    createDayFrame(i, data)
end

local function updateUI(data)
    local streak = data.streak or 0
    local canClaim = data.canClaim
    local nextDay = data.nextRewardDay
    local cycle = data.rewardCycle or DEFAULT_CYCLE

    -- Update days
    for i = 1, 7 do
        local df = dayFrames[i]
        local frame = df.Frame
        local check = df.Check
        
        -- Reset style
        frame.BackgroundColor3 = COLORS.DayBg
        check.Visible = false
        
        if i < nextDay then
            -- Past claimed days
            frame.BackgroundColor3 = COLORS.ClaimedBg
            check.Visible = true
        elseif i == nextDay then
            -- Current active day
            if canClaim then
                frame.BackgroundColor3 = COLORS.CurrentDayBg
                -- Highlight border?
                local stroke = frame:FindFirstChild("UIStroke") or Instance.new("UIStroke", frame)
                stroke.Color = COLORS.Gold
                stroke.Thickness = 2
                stroke.Transparency = 0
            else
                -- Already claimed today?
                -- Wait, if !canClaim, it means we claimed today.
                -- So nextRewardDay should point to TOMORROW.
                -- Logic in Service: "displayDay = streak + 1"
                -- If we claimed today (streak=1), nextDay=2.
                -- So day 1 is claimed. Day 2 is locked.
                -- Ah, let's re-read service logic.
                -- Service: "streak = streak + 1" after claim.
                -- So nextRewardDay points to the UPCOMING reward.
                
                -- So days < nextDay are CLAIMED.
                -- Day == nextDay is UPCOMING.
                frame.BackgroundColor3 = COLORS.DayBg
                local stroke = frame:FindFirstChild("UIStroke")
                if stroke then stroke.Transparency = 1 end
            end
        else
            -- Future day
            frame.BackgroundColor3 = COLORS.DayBg
            local stroke = frame:FindFirstChild("UIStroke")
            if stroke then stroke.Transparency = 1 end
        end
    end
    
    -- Claim button state
    if canClaim then
        claimBtn.Text = "CLAIM DAY " .. nextDay
        claimBtn.BackgroundColor3 = COLORS.Green
        claimBtn.AutoButtonColor = true
        statusLabel.Text = "Reward available!"
        statusLabel.TextColor3 = COLORS.Green
        
        -- Auto-open if not seen yet?
        if not rewardGui.Enabled then
            rewardGui.Enabled = true
        end
    else
        claimBtn.Text = "COME BACK TOMORROW"
        claimBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        claimBtn.AutoButtonColor = false
        
        -- Calculate time left
        -- We don't have exact time left sent, only lastClaimTime.
        local elapsed = os.time() - (data.lastClaimTime or 0)
        local cooldown = 22 * 3600
        local left = math.max(0, cooldown - elapsed)
        local h = math.floor(left / 3600)
        local m = math.floor((left % 3600) / 60)
        
        statusLabel.Text = string.format("Next reward in %02d:%02d", h, m)
        statusLabel.TextColor3 = COLORS.LockedText
    end
end

--------------------------------------------------------------------------------
-- Connections
--------------------------------------------------------------------------------

Remotes.DailyRewardData.OnClientEvent:Connect(function(data)
    print("Received daily data", data)
    updateUI(data)
end)

claimBtn.MouseButton1Click:Connect(function()
    if claimBtn.BackgroundColor3 == COLORS.Green then
        Remotes.DailyRewardClaim:FireServer()
        claimBtn.Text = "CLAIMING..."
        claimBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    rewardGui.Enabled = false
end)

print("[DailyRewardClient] Initialized")
