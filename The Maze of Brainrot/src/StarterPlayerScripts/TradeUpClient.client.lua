--[[
    TradeUpClient.lua
    =================
    Client LocalScript — Trade-Up Machine UI.
    
    Shows items grouped by ItemId with counts. When a group has 5+,
    enables the trade-up button. Displays the result with rarity glow
    animation.
    
    Dependencies:
        - RemoteEvents
        - RarityConfig
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local RarityConfig = require(Modules.Data.RarityConfig)
local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--------------------------------------------------------------------------------
-- Design Tokens
--------------------------------------------------------------------------------

local COLORS = {
    PanelBg = Color3.fromRGB(12, 10, 20),
    HeaderBg = Color3.fromRGB(25, 15, 40),
    ItemBg = Color3.fromRGB(30, 25, 45),
    TextPrimary = Color3.fromRGB(240, 240, 245),
    TextSecondary = Color3.fromRGB(170, 170, 190),
    Purple = Color3.fromRGB(163, 53, 238),
    TradeButton = Color3.fromRGB(163, 53, 238),
    TradeButtonDisabled = Color3.fromRGB(60, 40, 80),
    CloseButton = Color3.fromRGB(180, 50, 50),
}

--------------------------------------------------------------------------------
-- Create Trade-Up UI
--------------------------------------------------------------------------------

local tradeGui = Instance.new("ScreenGui")
tradeGui.Name = "TradeUpUI"
tradeGui.ResetOnSpawn = false
tradeGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
tradeGui.DisplayOrder = 15
tradeGui.IgnoreGuiInset = true
tradeGui.Enabled = false
tradeGui.Parent = PlayerGui

-- Dim backdrop
local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.5
backdrop.BorderSizePixel = 0
backdrop.ZIndex = 1
backdrop.Parent = tradeGui

-- Main panel
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0, 400, 0, 480)
panel.Position = UDim2.new(0.5, -200, 0.5, -240)
panel.BackgroundColor3 = COLORS.PanelBg
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.ZIndex = 2
panel.Parent = tradeGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = COLORS.Purple
panelStroke.Thickness = 2
panelStroke.Transparency = 0.3
panelStroke.Parent = panel

-- Header
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 50)
header.BackgroundColor3 = COLORS.HeaderBg
header.BackgroundTransparency = 0.1
header.BorderSizePixel = 0
header.ZIndex = 3
header.Parent = panel

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 12)
headerCorner.Parent = header

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -80, 1, 0)
titleLabel.Position = UDim2.new(0, 15, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "⚗️ TRADE-UP (5 → 1)"
titleLabel.TextColor3 = COLORS.Purple
titleLabel.TextSize = 22
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.ZIndex = 4
titleLabel.Parent = header

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -45, 0, 5)
closeBtn.BackgroundColor3 = COLORS.CloseButton
closeBtn.BackgroundTransparency = 0.5
closeBtn.Text = "✕"
closeBtn.TextColor3 = COLORS.TextPrimary
closeBtn.TextSize = 20
closeBtn.Font = Enum.Font.GothamBold
closeBtn.ZIndex = 4
closeBtn.AutoButtonColor = false
closeBtn.Parent = header

local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0, 8)
closeBtnCorner.Parent = closeBtn

-- Subtitle: instructions
local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Size = UDim2.new(1, -20, 0, 20)
subtitleLabel.Position = UDim2.new(0, 10, 0, 55)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Text = "Select an item type with 5+ copies to trade up"
subtitleLabel.TextColor3 = COLORS.TextSecondary
subtitleLabel.TextSize = 12
subtitleLabel.Font = Enum.Font.GothamMedium
subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
subtitleLabel.ZIndex = 3
subtitleLabel.Parent = panel

-- Scrolling frame for grouped items
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -20, 1, -130)
scrollFrame.Position = UDim2.new(0, 10, 0, 80)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 4
scrollFrame.ScrollBarImageColor3 = COLORS.Purple
scrollFrame.BorderSizePixel = 0
scrollFrame.ZIndex = 3
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollFrame

-- Result display panel (hidden initially)
local resultPanel = Instance.new("Frame")
resultPanel.Name = "ResultPanel"
resultPanel.Size = UDim2.new(1, -40, 0, 100)
resultPanel.Position = UDim2.new(0, 20, 1, -110)
resultPanel.BackgroundColor3 = Color3.fromRGB(20, 15, 35)
resultPanel.BackgroundTransparency = 0.2
resultPanel.BorderSizePixel = 0
resultPanel.ZIndex = 4
resultPanel.Visible = false
resultPanel.Parent = panel

local resultCorner = Instance.new("UICorner")
resultCorner.CornerRadius = UDim.new(0, 8)
resultCorner.Parent = resultPanel

local resultLabel = Instance.new("TextLabel")
resultLabel.Size = UDim2.new(1, 0, 1, 0)
resultLabel.BackgroundTransparency = 1
resultLabel.Text = ""
resultLabel.TextColor3 = COLORS.TextPrimary
resultLabel.TextSize = 18
resultLabel.Font = Enum.Font.GothamBold
resultLabel.TextWrapped = true
resultLabel.ZIndex = 5
resultLabel.Parent = resultPanel

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local cachedInventory = {}

--------------------------------------------------------------------------------
-- Group items by ItemId and populate list
--------------------------------------------------------------------------------

local function populateTradeUpList(items: { any })
    -- Clear existing
    for _, child in ipairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    cachedInventory = items

    -- Group by ItemId
    local groups = {} -- { [ItemId] = { items = {}, displayName, rarity, count } }
    local groupOrder = {}

    for _, item in ipairs(items) do
        if not groups[item.ItemId] then
            groups[item.ItemId] = {
                items = {},
                displayName = item.DisplayName,
                rarity = item.Rarity,
                itemId = item.ItemId,
            }
            table.insert(groupOrder, item.ItemId)
        end
        table.insert(groups[item.ItemId].items, item)
    end

    -- Create rows
    local order = 0
    for _, itemId in ipairs(groupOrder) do
        local group = groups[itemId]
        local count = #group.items
        local rarityTier = RarityConfig.Tiers[group.rarity]
        local rarityColor = rarityTier and rarityTier.OutlineColor or Color3.fromRGB(200, 200, 200)
        local canTrade = count >= 5 and rarityTier and rarityTier.CanTradeUpFrom

        order += 1

        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 55)
        row.BackgroundColor3 = COLORS.ItemBg
        row.BackgroundTransparency = 0.3
        row.BorderSizePixel = 0
        row.ZIndex = 4
        row.LayoutOrder = order
        row.Parent = scrollFrame

        local rowCorner = Instance.new("UICorner")
        rowCorner.CornerRadius = UDim.new(0, 6)
        rowCorner.Parent = row

        -- Rarity accent
        local accent = Instance.new("Frame")
        accent.Size = UDim2.new(0, 4, 0.8, 0)
        accent.Position = UDim2.new(0, 4, 0.1, 0)
        accent.BackgroundColor3 = rarityColor
        accent.BorderSizePixel = 0
        accent.ZIndex = 5
        accent.Parent = row

        local accentCorner = Instance.new("UICorner")
        accentCorner.CornerRadius = UDim.new(0, 2)
        accentCorner.Parent = accent

        -- Item name + count
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0, 180, 0, 28)
        nameLabel.Position = UDim2.new(0, 16, 0, 5)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = group.displayName
        nameLabel.TextColor3 = rarityColor
        nameLabel.TextSize = 14
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.ZIndex = 5
        nameLabel.Parent = row

        local countLabel = Instance.new("TextLabel")
        countLabel.Size = UDim2.new(0, 100, 0, 18)
        countLabel.Position = UDim2.new(0, 16, 0, 32)
        countLabel.BackgroundTransparency = 1
        countLabel.Text = group.rarity .. " × " .. count .. (count >= 5 and " ✓" or " (need 5)")
        countLabel.TextColor3 = count >= 5 and Color3.fromRGB(100, 255, 100) or COLORS.TextSecondary
        countLabel.TextSize = 11
        countLabel.Font = Enum.Font.GothamMedium
        countLabel.TextXAlignment = Enum.TextXAlignment.Left
        countLabel.ZIndex = 5
        countLabel.Parent = row

        -- Trade-Up button (only if eligible)
        if canTrade then
            local tradeBtn = Instance.new("TextButton")
            tradeBtn.Size = UDim2.new(0, 90, 0, 34)
            tradeBtn.Position = UDim2.new(1, -100, 0.5, -17)
            tradeBtn.BackgroundColor3 = COLORS.TradeButton
            tradeBtn.Text = "TRADE UP"
            tradeBtn.TextColor3 = COLORS.TextPrimary
            tradeBtn.TextSize = 12
            tradeBtn.Font = Enum.Font.GothamBold
            tradeBtn.ZIndex = 5
            tradeBtn.AutoButtonColor = false
            tradeBtn.Parent = row

            local tradeBtnCorner = Instance.new("UICorner")
            tradeBtnCorner.CornerRadius = UDim.new(0, 6)
            tradeBtnCorner.Parent = tradeBtn

            tradeBtn.MouseButton1Click:Connect(function()
                -- Send the first 5 UniqueIds of this group
                local uniqueIds = {}
                for i = 1, 5 do
                    table.insert(uniqueIds, group.items[i].UniqueId)
                end
                Remotes.RequestTradeUp:FireServer({
                    itemId = group.itemId,
                    uniqueIds = uniqueIds,
                })
            end)

            tradeBtn.MouseEnter:Connect(function()
                TweenService:Create(tradeBtn, TweenInfo.new(0.1), {
                    BackgroundColor3 = Color3.fromRGB(190, 80, 255),
                }):Play()
            end)
            tradeBtn.MouseLeave:Connect(function()
                TweenService:Create(tradeBtn, TweenInfo.new(0.1), {
                    BackgroundColor3 = COLORS.TradeButton,
                }):Play()
            end)
        end
    end

    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, order * 59)
end

--------------------------------------------------------------------------------
-- Open / Close
--------------------------------------------------------------------------------

local function openTradeUp()
    tradeGui.Enabled = true
    resultPanel.Visible = false

    panel.Size = UDim2.new(0, 20, 0, 20)
    panel.Position = UDim2.new(0.5, -10, 0.5, -10)

    TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 400, 0, 480),
        Position = UDim2.new(0.5, -200, 0.5, -240),
    }):Play()
end

local function closeTradeUp()
    TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(0.5, -10, 0.5, -10),
    }):Play()
    task.wait(0.25)
    tradeGui.Enabled = false
end

--------------------------------------------------------------------------------
-- Event connections
--------------------------------------------------------------------------------

closeBtn.MouseButton1Click:Connect(closeTradeUp)
backdrop.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        closeTradeUp()
    end
end)

Remotes.OpenTradeUp.OnClientEvent:Connect(function()
    openTradeUp()
end)

Remotes.InventoryData.OnClientEvent:Connect(function(items)
    populateTradeUpList(items)
end)

-- Handle trade-up result
Remotes.TradeUpResult.OnClientEvent:Connect(function(success: boolean, itemData: any, message: string)
    if success and itemData then
        local rarityTier = RarityConfig.Tiers[itemData.Rarity]
        local rarityColor = rarityTier and rarityTier.OutlineColor or Color3.fromRGB(255, 255, 255)

        -- Show result animation
        resultPanel.Visible = true
        resultLabel.Text = "✨ " .. itemData.DisplayName .. "\n" ..
            itemData.Rarity .. " • " .. itemData.FragmentValue .. " 💎"
        resultLabel.TextColor3 = rarityColor

        -- Glow effect
        local resultStroke = resultPanel:FindFirstChildWhichIsA("UIStroke")
        if not resultStroke then
            resultStroke = Instance.new("UIStroke")
            resultStroke.Parent = resultPanel
        end
        resultStroke.Color = rarityColor
        resultStroke.Thickness = 2
        resultStroke.Transparency = 0

        TweenService:Create(resultStroke, TweenInfo.new(1.5), {
            Transparency = 0.8,
        }):Play()

        -- Refresh inventory data
        Remotes.RequestInventoryData:FireServer()
    elseif message then
        resultPanel.Visible = true
        resultLabel.Text = "❌ " .. message
        resultLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    end
end)

print("[TradeUpClient] Initialized")
