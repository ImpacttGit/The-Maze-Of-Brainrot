--[[
    MerchantClient.lua
    ==================
    Client LocalScript — Merchant shop UI for selling items.
    
    Features:
        - Full inventory list with rarity colors
        - Per-item SELL button (excludes Legendaries)
        - SELL ALL button (non-Legendaries)
        - Fragment total display
        - Dark/gold aesthetic matching HUD
    
    Dependencies:
        - RemoteEvents
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
    PanelBg = Color3.fromRGB(12, 12, 18),
    HeaderBg = Color3.fromRGB(20, 18, 30),
    ItemBg = Color3.fromRGB(25, 25, 35),
    ItemBgHover = Color3.fromRGB(35, 35, 50),
    TextPrimary = Color3.fromRGB(240, 240, 245),
    TextSecondary = Color3.fromRGB(170, 170, 190),
    Gold = Color3.fromRGB(255, 215, 0),
    SellButton = Color3.fromRGB(50, 180, 80),
    SellAllButton = Color3.fromRGB(200, 160, 0),
    CloseButton = Color3.fromRGB(180, 50, 50),
    Legendary = Color3.fromRGB(255, 215, 0),
}

--------------------------------------------------------------------------------
-- Create Shop UI
--------------------------------------------------------------------------------

local shopGui = Instance.new("ScreenGui")
shopGui.Name = "MerchantShopUI"
shopGui.ResetOnSpawn = false
shopGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
shopGui.DisplayOrder = 15
shopGui.IgnoreGuiInset = true
shopGui.Enabled = false
shopGui.Parent = PlayerGui

-- Dim backdrop
local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.5
backdrop.BorderSizePixel = 0
backdrop.ZIndex = 1
backdrop.Parent = shopGui

-- Main panel
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0, 420, 0, 520)
panel.Position = UDim2.new(0.5, -210, 0.5, -260)
panel.BackgroundColor3 = COLORS.PanelBg
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.ZIndex = 2
panel.Parent = shopGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = COLORS.Gold
panelStroke.Thickness = 2
panelStroke.Transparency = 0.3
panelStroke.Parent = panel

-- Header
local header = Instance.new("Frame")
header.Name = "Header"
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
titleLabel.Text = "💰 MERCHANT"
titleLabel.TextColor3 = COLORS.Gold
titleLabel.TextSize = 24
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.ZIndex = 4
titleLabel.Parent = header

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
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

-- Scrolling frame for items
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "ItemList"
scrollFrame.Size = UDim2.new(1, -20, 1, -120)
scrollFrame.Position = UDim2.new(0, 10, 0, 55)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 4
scrollFrame.ScrollBarImageColor3 = COLORS.Gold
scrollFrame.BorderSizePixel = 0
scrollFrame.ZIndex = 3
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollFrame

-- Bottom bar with Sell All button
local bottomBar = Instance.new("Frame")
bottomBar.Name = "BottomBar"
bottomBar.Size = UDim2.new(1, 0, 0, 55)
bottomBar.Position = UDim2.new(0, 0, 1, -55)
bottomBar.BackgroundColor3 = COLORS.HeaderBg
bottomBar.BackgroundTransparency = 0.1
bottomBar.BorderSizePixel = 0
bottomBar.ZIndex = 3
bottomBar.Parent = panel

local bottomCorner = Instance.new("UICorner")
bottomCorner.CornerRadius = UDim.new(0, 12)
bottomCorner.Parent = bottomBar

local sellAllBtn = Instance.new("TextButton")
sellAllBtn.Name = "SellAllBtn"
sellAllBtn.Size = UDim2.new(0, 180, 0, 38)
sellAllBtn.Position = UDim2.new(0.5, -90, 0.5, -19)
sellAllBtn.BackgroundColor3 = COLORS.SellAllButton
sellAllBtn.Text = "💰 SELL ALL"
sellAllBtn.TextColor3 = COLORS.TextPrimary
sellAllBtn.TextSize = 18
sellAllBtn.Font = Enum.Font.GothamBold
sellAllBtn.ZIndex = 4
sellAllBtn.AutoButtonColor = false
sellAllBtn.Parent = bottomBar

local sellAllCorner = Instance.new("UICorner")
sellAllCorner.CornerRadius = UDim.new(0, 8)
sellAllCorner.Parent = sellAllBtn

--------------------------------------------------------------------------------
-- Populate item list
--------------------------------------------------------------------------------

local currentItems = {}

local function clearItemList()
    for _, child in ipairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
end

local function populateItemList(items: { any })
    clearItemList()
    currentItems = items

    local order = 0
    for _, item in ipairs(items) do
        order += 1
        local rarityTier = RarityConfig.Tiers[item.Rarity]
        local rarityColor = rarityTier and rarityTier.OutlineColor or Color3.fromRGB(200, 200, 200)
        local isLegendary = item.Rarity == "Legendary"

        local row = Instance.new("Frame")
        row.Name = "Item_" .. item.UniqueId
        row.Size = UDim2.new(1, 0, 0, 50)
        row.BackgroundColor3 = COLORS.ItemBg
        row.BackgroundTransparency = 0.3
        row.BorderSizePixel = 0
        row.ZIndex = 4
        row.LayoutOrder = order
        row.Parent = scrollFrame

        local rowCorner = Instance.new("UICorner")
        rowCorner.CornerRadius = UDim.new(0, 6)
        rowCorner.Parent = row

        -- Rarity accent bar
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

        -- Item name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0, 180, 0, 28)
        nameLabel.Position = UDim2.new(0, 16, 0, 4)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = item.DisplayName
        nameLabel.TextColor3 = rarityColor
        nameLabel.TextSize = 14
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.ZIndex = 5
        nameLabel.Parent = row

        -- Rarity + value
        local infoLabel = Instance.new("TextLabel")
        infoLabel.Size = UDim2.new(0, 180, 0, 16)
        infoLabel.Position = UDim2.new(0, 16, 0, 30)
        infoLabel.BackgroundTransparency = 1
        infoLabel.Text = item.Rarity .. " • " .. (isLegendary and "Non-sellable" or (item.FragmentValue .. " 💎"))
        infoLabel.TextColor3 = COLORS.TextSecondary
        infoLabel.TextSize = 11
        infoLabel.Font = Enum.Font.GothamMedium
        infoLabel.TextXAlignment = Enum.TextXAlignment.Left
        infoLabel.ZIndex = 5
        infoLabel.Parent = row

        -- Sell button (not for Legendaries)
        if not isLegendary then
            local sellBtn = Instance.new("TextButton")
            sellBtn.Size = UDim2.new(0, 70, 0, 30)
            sellBtn.Position = UDim2.new(1, -80, 0.5, -15)
            sellBtn.BackgroundColor3 = COLORS.SellButton
            sellBtn.Text = "SELL"
            sellBtn.TextColor3 = COLORS.TextPrimary
            sellBtn.TextSize = 13
            sellBtn.Font = Enum.Font.GothamBold
            sellBtn.ZIndex = 5
            sellBtn.AutoButtonColor = false
            sellBtn.Parent = row

            local sellBtnCorner = Instance.new("UICorner")
            sellBtnCorner.CornerRadius = UDim.new(0, 6)
            sellBtnCorner.Parent = sellBtn

            sellBtn.MouseButton1Click:Connect(function()
                Remotes.RequestSellItem:FireServer(item.UniqueId)
            end)

            sellBtn.MouseEnter:Connect(function()
                TweenService:Create(sellBtn, TweenInfo.new(0.1), {
                    BackgroundColor3 = Color3.fromRGB(70, 220, 100),
                }):Play()
            end)
            sellBtn.MouseLeave:Connect(function()
                TweenService:Create(sellBtn, TweenInfo.new(0.1), {
                    BackgroundColor3 = COLORS.SellButton,
                }):Play()
            end)
        else
            -- Protected badge for Legendaries
            local badge = Instance.new("TextLabel")
            badge.Size = UDim2.new(0, 70, 0, 30)
            badge.Position = UDim2.new(1, -80, 0.5, -15)
            badge.BackgroundTransparency = 1
            badge.Text = "🔒"
            badge.TextSize = 20
            badge.ZIndex = 5
            badge.Parent = row
        end
    end

    -- Update canvas size
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, order * 54)
end

--------------------------------------------------------------------------------
-- Open / Close
--------------------------------------------------------------------------------

local function openShop()
    shopGui.Enabled = true
    panel.Size = UDim2.new(0, 20, 0, 20)
    panel.Position = UDim2.new(0.5, -10, 0.5, -10)

    TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 420, 0, 520),
        Position = UDim2.new(0.5, -210, 0.5, -260),
    }):Play()
end

local function closeShop()
    TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(0.5, -10, 0.5, -10),
    }):Play()
    task.wait(0.25)
    shopGui.Enabled = false
end

--------------------------------------------------------------------------------
-- Event connections
--------------------------------------------------------------------------------

closeBtn.MouseButton1Click:Connect(closeShop)
backdrop.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        closeShop()
    end
end)

sellAllBtn.MouseButton1Click:Connect(function()
    Remotes.RequestSellAll:FireServer()
end)

-- Listen for merchant open
Remotes.OpenMerchant.OnClientEvent:Connect(function()
    openShop()
end)

-- Listen for inventory data
Remotes.InventoryData.OnClientEvent:Connect(function(items)
    populateItemList(items)
end)

-- Listen for sell results (refresh list)
Remotes.SellResult.OnClientEvent:Connect(function(success, earned, message)
    -- Request updated inventory
    if success then
        Remotes.RequestInventoryData:FireServer()
    end
end)

print("[MerchantClient] Initialized")
