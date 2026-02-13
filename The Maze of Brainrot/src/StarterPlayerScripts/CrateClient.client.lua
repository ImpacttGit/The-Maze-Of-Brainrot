--[[
    CrateClient.lua
    ===============
    Client LocalScript — Crate Shop UI with purchase and reveal animation.
    
    Features:
        - 3 crate cards (Common, Rare, Legendary) with rarity styling
        - Fragment / Robux purchase buttons
        - Item reveal animation with rarity glow burst
        - Accessible from Hub via keybind (C) or through a prompt
    
    Dependencies:
        - RemoteEvents
        - CrateConfig
        - RarityConfig
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local CrateConfig = require(Modules.Data.CrateConfig)
local RarityConfig = require(Modules.Data.RarityConfig)
local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--------------------------------------------------------------------------------
-- Design Tokens
--------------------------------------------------------------------------------

local COLORS = {
    PanelBg = Color3.fromRGB(8, 8, 14),
    CardBg = Color3.fromRGB(18, 18, 28),
    TextPrimary = Color3.fromRGB(240, 240, 245),
    TextSecondary = Color3.fromRGB(150, 150, 170),
    BuyFragment = Color3.fromRGB(50, 180, 100),
    BuyRobux = Color3.fromRGB(0, 160, 255),
    CloseButton = Color3.fromRGB(180, 50, 50),
}

--------------------------------------------------------------------------------
-- Create Crate Shop UI
--------------------------------------------------------------------------------

local crateGui = Instance.new("ScreenGui")
crateGui.Name = "CrateShopUI"
crateGui.ResetOnSpawn = false
crateGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
crateGui.DisplayOrder = 20
crateGui.IgnoreGuiInset = true
crateGui.Enabled = false
crateGui.Parent = PlayerGui

-- Backdrop
local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.4
backdrop.BorderSizePixel = 0
backdrop.ZIndex = 1
backdrop.Parent = crateGui

-- Main panel
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0, 680, 0, 400)
panel.Position = UDim2.new(0.5, -340, 0.5, -200)
panel.BackgroundColor3 = COLORS.PanelBg
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.ZIndex = 2
panel.Parent = crateGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(100, 100, 150)
panelStroke.Thickness = 1
panelStroke.Transparency = 0.5
panelStroke.Parent = panel

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 0, 40)
title.Position = UDim2.new(0, 20, 0, 10)
title.BackgroundTransparency = 1
title.Text = "🎁 CRATE SHOP"
title.TextColor3 = COLORS.TextPrimary
title.TextSize = 26
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 3
title.Parent = panel

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -50, 0, 5)
closeBtn.BackgroundColor3 = COLORS.CloseButton
closeBtn.BackgroundTransparency = 0.5
closeBtn.Text = "✕"
closeBtn.TextColor3 = COLORS.TextPrimary
closeBtn.TextSize = 20
closeBtn.Font = Enum.Font.GothamBold
closeBtn.ZIndex = 4
closeBtn.AutoButtonColor = false
closeBtn.Parent = panel

local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0, 8)
closeBtnCorner.Parent = closeBtn

-- Cards container
local cardsFrame = Instance.new("Frame")
cardsFrame.Size = UDim2.new(1, -30, 0, 300)
cardsFrame.Position = UDim2.new(0, 15, 0, 60)
cardsFrame.BackgroundTransparency = 1
cardsFrame.ZIndex = 3
cardsFrame.Parent = panel

local cardsLayout = Instance.new("UIListLayout")
cardsLayout.FillDirection = Enum.FillDirection.Horizontal
cardsLayout.Padding = UDim.new(0, 12)
cardsLayout.SortOrder = Enum.SortOrder.LayoutOrder
cardsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
cardsLayout.Parent = cardsFrame

--------------------------------------------------------------------------------
-- Create individual crate cards
--------------------------------------------------------------------------------

for i, crateId in ipairs(CrateConfig.CrateOrder) do
    local crateDef = CrateConfig.Crates[crateId]

    local card = Instance.new("Frame")
    card.Name = "Crate_" .. crateId
    card.Size = UDim2.new(0, 200, 1, 0)
    card.BackgroundColor3 = COLORS.CardBg
    card.BackgroundTransparency = 0.15
    card.BorderSizePixel = 0
    card.ZIndex = 4
    card.LayoutOrder = i
    card.Parent = cardsFrame

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 10)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = crateDef.Color
    cardStroke.Thickness = 2
    cardStroke.Transparency = 0.3
    cardStroke.Parent = card

    -- Crate icon (colored circle)
    local icon = Instance.new("Frame")
    icon.Size = UDim2.new(0, 60, 0, 60)
    icon.Position = UDim2.new(0.5, -30, 0, 20)
    icon.BackgroundColor3 = crateDef.Color
    icon.BackgroundTransparency = 0.2
    icon.ZIndex = 5
    icon.Parent = card

    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(1, 0)
    iconCorner.Parent = icon

    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(1, 0, 1, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = "🎁"
    iconLabel.TextSize = 30
    iconLabel.ZIndex = 6
    iconLabel.Parent = icon

    -- Name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0, 22)
    nameLabel.Position = UDim2.new(0, 0, 0, 90)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = crateDef.Name
    nameLabel.TextColor3 = crateDef.Color
    nameLabel.TextSize = 16
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.ZIndex = 5
    nameLabel.Parent = card

    -- Description
    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(1, -16, 0, 30)
    descLabel.Position = UDim2.new(0, 8, 0, 115)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = crateDef.Description
    descLabel.TextColor3 = COLORS.TextSecondary
    descLabel.TextSize = 11
    descLabel.Font = Enum.Font.GothamMedium
    descLabel.TextWrapped = true
    descLabel.ZIndex = 5
    descLabel.Parent = card

    -- Odds display
    local oddsText = ""
    for _, odd in ipairs(crateDef.Odds) do
        oddsText = oddsText .. odd.Rarity .. ": " .. odd.Weight .. "%  "
    end

    local oddsLabel = Instance.new("TextLabel")
    oddsLabel.Size = UDim2.new(1, -16, 0, 20)
    oddsLabel.Position = UDim2.new(0, 8, 0, 150)
    oddsLabel.BackgroundTransparency = 1
    oddsLabel.Text = oddsText
    oddsLabel.TextColor3 = COLORS.TextSecondary
    oddsLabel.TextSize = 10
    oddsLabel.Font = Enum.Font.Gotham
    oddsLabel.TextWrapped = true
    oddsLabel.ZIndex = 5
    oddsLabel.Parent = card

    -- Buy with Fragments button
    if crateDef.CanBuyWithFragments then
        local fragBtn = Instance.new("TextButton")
        fragBtn.Size = UDim2.new(1, -20, 0, 34)
        fragBtn.Position = UDim2.new(0, 10, 0, 195)
        fragBtn.BackgroundColor3 = COLORS.BuyFragment
        fragBtn.Text = "💎 " .. crateDef.FragmentPrice .. " Fragments"
        fragBtn.TextColor3 = COLORS.TextPrimary
        fragBtn.TextSize = 12
        fragBtn.Font = Enum.Font.GothamBold
        fragBtn.ZIndex = 5
        fragBtn.AutoButtonColor = false
        fragBtn.Parent = card

        local fragBtnCorner = Instance.new("UICorner")
        fragBtnCorner.CornerRadius = UDim.new(0, 6)
        fragBtnCorner.Parent = fragBtn

        fragBtn.MouseButton1Click:Connect(function()
            Remotes.RequestCratePurchase:FireServer({
                crateId = crateId,
                paymentType = "Fragments",
            })
        end)

        fragBtn.MouseEnter:Connect(function()
            TweenService:Create(fragBtn, TweenInfo.new(0.1), {
                BackgroundColor3 = Color3.fromRGB(70, 210, 120),
            }):Play()
        end)
        fragBtn.MouseLeave:Connect(function()
            TweenService:Create(fragBtn, TweenInfo.new(0.1), {
                BackgroundColor3 = COLORS.BuyFragment,
            }):Play()
        end)
    end

    -- Buy with Robux button
    local robuxBtn = Instance.new("TextButton")
    robuxBtn.Size = UDim2.new(1, -20, 0, 34)
    robuxBtn.Position = UDim2.new(0, 10, 0, crateDef.CanBuyWithFragments and 235 or 195)
    robuxBtn.BackgroundColor3 = COLORS.BuyRobux
    robuxBtn.Text = "R$ " .. crateDef.RobuxPrice
    robuxBtn.TextColor3 = COLORS.TextPrimary
    robuxBtn.TextSize = 12
    robuxBtn.Font = Enum.Font.GothamBold
    robuxBtn.ZIndex = 5
    robuxBtn.AutoButtonColor = false
    robuxBtn.Parent = card

    local robuxBtnCorner = Instance.new("UICorner")
    robuxBtnCorner.CornerRadius = UDim.new(0, 6)
    robuxBtnCorner.Parent = robuxBtn

    robuxBtn.MouseButton1Click:Connect(function()
        Remotes.RequestCratePurchase:FireServer({
            crateId = crateId,
            paymentType = "Robux",
        })
    end)

    robuxBtn.MouseEnter:Connect(function()
        TweenService:Create(robuxBtn, TweenInfo.new(0.1), {
            BackgroundColor3 = Color3.fromRGB(30, 190, 255),
        }):Play()
    end)
    robuxBtn.MouseLeave:Connect(function()
        TweenService:Create(robuxBtn, TweenInfo.new(0.1), {
            BackgroundColor3 = COLORS.BuyRobux,
        }):Play()
    end)
end

--------------------------------------------------------------------------------
-- Reveal Overlay (shows item received from crate)
--------------------------------------------------------------------------------

local revealGui = Instance.new("ScreenGui")
revealGui.Name = "CrateRevealUI"
revealGui.ResetOnSpawn = false
revealGui.DisplayOrder = 25
revealGui.IgnoreGuiInset = true
revealGui.Enabled = false
revealGui.Parent = PlayerGui

local revealBackdrop = Instance.new("Frame")
revealBackdrop.Size = UDim2.new(1, 0, 1, 0)
revealBackdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
revealBackdrop.BackgroundTransparency = 0.3
revealBackdrop.BorderSizePixel = 0
revealBackdrop.Parent = revealGui

local revealCard = Instance.new("Frame")
revealCard.Size = UDim2.new(0, 300, 0, 250)
revealCard.Position = UDim2.new(0.5, -150, 0.5, -125)
revealCard.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
revealCard.BackgroundTransparency = 0.1
revealCard.BorderSizePixel = 0
revealCard.Parent = revealGui

local revealCardCorner = Instance.new("UICorner")
revealCardCorner.CornerRadius = UDim.new(0, 14)
revealCardCorner.Parent = revealCard

local revealCardStroke = Instance.new("UIStroke")
revealCardStroke.Thickness = 3
revealCardStroke.Color = Color3.fromRGB(255, 255, 255)
revealCardStroke.Parent = revealCard

local revealTitle = Instance.new("TextLabel")
revealTitle.Size = UDim2.new(1, 0, 0, 30)
revealTitle.Position = UDim2.new(0, 0, 0, 25)
revealTitle.BackgroundTransparency = 1
revealTitle.Text = "✨ YOU GOT ✨"
revealTitle.TextColor3 = COLORS.TextPrimary
revealTitle.TextSize = 18
revealTitle.Font = Enum.Font.GothamBold
revealTitle.Parent = revealCard

local revealItemName = Instance.new("TextLabel")
revealItemName.Size = UDim2.new(1, -20, 0, 40)
revealItemName.Position = UDim2.new(0, 10, 0, 70)
revealItemName.BackgroundTransparency = 1
revealItemName.Text = ""
revealItemName.TextSize = 28
revealItemName.Font = Enum.Font.GothamBold
revealItemName.TextWrapped = true
revealItemName.Parent = revealCard

local revealRarity = Instance.new("TextLabel")
revealRarity.Size = UDim2.new(1, 0, 0, 25)
revealRarity.Position = UDim2.new(0, 0, 0, 120)
revealRarity.BackgroundTransparency = 1
revealRarity.Text = ""
revealRarity.TextSize = 16
revealRarity.Font = Enum.Font.GothamMedium
revealRarity.Parent = revealCard

local revealFragments = Instance.new("TextLabel")
revealFragments.Size = UDim2.new(1, 0, 0, 25)
revealFragments.Position = UDim2.new(0, 0, 0, 150)
revealFragments.BackgroundTransparency = 1
revealFragments.Text = ""
revealFragments.TextColor3 = COLORS.TextSecondary
revealFragments.TextSize = 14
revealFragments.Font = Enum.Font.GothamMedium
revealFragments.Parent = revealCard

local revealDismiss = Instance.new("TextButton")
revealDismiss.Size = UDim2.new(0, 120, 0, 36)
revealDismiss.Position = UDim2.new(0.5, -60, 1, -50)
revealDismiss.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
revealDismiss.Text = "CLOSE"
revealDismiss.TextColor3 = COLORS.TextPrimary
revealDismiss.TextSize = 14
revealDismiss.Font = Enum.Font.GothamBold
revealDismiss.AutoButtonColor = false
revealDismiss.Parent = revealCard

local dismissCorner = Instance.new("UICorner")
dismissCorner.CornerRadius = UDim.new(0, 8)
dismissCorner.Parent = revealDismiss

--------------------------------------------------------------------------------
-- Reveal Animation
--------------------------------------------------------------------------------

local function showReveal(itemData: any)
    local rarityTier = RarityConfig.Tiers[itemData.Rarity]
    local rarityColor = rarityTier and rarityTier.OutlineColor or Color3.fromRGB(200, 200, 200)

    revealItemName.Text = itemData.DisplayName
    revealItemName.TextColor3 = rarityColor
    revealRarity.Text = itemData.Rarity
    revealRarity.TextColor3 = rarityColor
    revealFragments.Text = "Worth " .. (itemData.FragmentValue or 0) .. " 💎"
    revealCardStroke.Color = rarityColor

    -- Start small and burst open
    revealCard.Size = UDim2.new(0, 10, 0, 10)
    revealCard.Position = UDim2.new(0.5, -5, 0.5, -5)
    revealGui.Enabled = true

    -- Burst animation
    TweenService:Create(revealCard, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 300, 0, 250),
        Position = UDim2.new(0.5, -150, 0.5, -125),
    }):Play()

    -- Glow pulse on stroke
    TweenService:Create(revealCardStroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true), {
        Thickness = 5,
    }):Play()
end

local function hideReveal()
    TweenService:Create(revealCard, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 10, 0, 10),
        Position = UDim2.new(0.5, -5, 0.5, -5),
    }):Play()
    task.wait(0.25)
    revealGui.Enabled = false
end

--------------------------------------------------------------------------------
-- Open / Close Shop
--------------------------------------------------------------------------------

local function openShop()
    crateGui.Enabled = true
    panel.Size = UDim2.new(0, 20, 0, 20)
    panel.Position = UDim2.new(0.5, -10, 0.5, -10)

    TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 680, 0, 400),
        Position = UDim2.new(0.5, -340, 0.5, -200),
    }):Play()
end

local function closeShop()
    TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(0.5, -10, 0.5, -10),
    }):Play()
    task.wait(0.25)
    crateGui.Enabled = false
end

local isOpen = false

local function toggleShop()
    if isOpen then
        closeShop()
    else
        openShop()
    end
    isOpen = not isOpen
end

--------------------------------------------------------------------------------
-- Event connections
--------------------------------------------------------------------------------

closeBtn.MouseButton1Click:Connect(function()
    closeShop()
    isOpen = false
end)

backdrop.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        closeShop()
        isOpen = false
    end
end)

revealDismiss.MouseButton1Click:Connect(hideReveal)
revealBackdrop.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        hideReveal()
    end
end)

-- Keybind: C to toggle crate shop
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.C then
        toggleShop()
    end
end)

-- Handle crate result from server
Remotes.CrateResult.OnClientEvent:Connect(function(success: boolean, itemData: any, message: string)
    if success and itemData then
        showReveal(itemData)
    else
        -- Show error briefly
        if message then
            warn("[CrateClient] " .. message)
        end
    end
end)

print("[CrateClient] Initialized — Press C to open Crate Shop")
