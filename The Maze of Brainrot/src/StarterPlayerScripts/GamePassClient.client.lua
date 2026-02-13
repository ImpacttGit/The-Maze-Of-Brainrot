--[[
    GamePassClient.client.lua
    =========================
    Client LocalScript — Game Pass Shop UI.
    
    Features:
        - Displays available game passes (Speed, Flashlight, Luck)
        - Checks ownership and updates UI (Buy vs Owned)
        - Prompts purchases via MarketplaceService
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

-- Placeholder IDs for testing — replace with real ones from GamePassService
local GAME_PASSES = {
    {
        Id = 0, -- Replace with real ID
        Key = "SpeedBoost",
        Name = "⚡ Speed Demon",
        Desc = "Permanent +4 WalkSpeed. Outrun the entities!",
        Price = 250
    },
    {
        Id = 0, -- Replace with real ID
        Key = "UpgradedFlashlight",
        Name = "🔦 Mega Flashlight",
        Desc = "2x battery life, brighter beam, slower drain.",
        Price = 200
    },
    {
        Id = 0, -- Replace with real ID
        Key = "LootLuck",
        Name = "🍀 Lucky Looter",
        Desc = "1.5x higher chance for Rare, Epic & Legendary loot!",
        Price = 350
    },
}

--------------------------------------------------------------------------------
-- UI Constants
--------------------------------------------------------------------------------

local COLORS = {
    Bg = Color3.fromRGB(15, 15, 20),
    CardBg = Color3.fromRGB(25, 25, 35),
    Gold = Color3.fromRGB(255, 215, 0),
    Green = Color3.fromRGB(50, 220, 100),
    Red = Color3.fromRGB(255, 80, 80),
    Text = Color3.fromRGB(240, 240, 245),
}

--------------------------------------------------------------------------------
-- Build UI
--------------------------------------------------------------------------------

local shopGui = Instance.new("ScreenGui")
shopGui.Name = "GamePassShop"
shopGui.ResetOnSpawn = false
shopGui.DisplayOrder = 20
shopGui.Enabled = false
shopGui.IgnoreGuiInset = true
shopGui.Parent = PlayerGui

local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.5
backdrop.Parent = shopGui

local container = Instance.new("Frame")
container.Size = UDim2.new(0, 600, 0, 400)
container.Position = UDim2.new(0.5, -300, 0.5, -200)
container.BackgroundColor3 = COLORS.Bg
container.BorderSizePixel = 0
container.Parent = shopGui

local containerCorner = Instance.new("UICorner")
containerCorner.CornerRadius = UDim.new(0, 12)
containerCorner.Parent = container

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 50)
title.BackgroundTransparency = 1
title.Text = "GAME PASS SHOP"
title.TextColor3 = COLORS.Gold
title.TextSize = 24
title.Font = Enum.Font.GothamBold
title.Parent = container

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -45, 0, 5)
closeBtn.BackgroundColor3 = COLORS.Red
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.Parent = container
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.Padding = UDim.new(0, 10)
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.Parent = container

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -60)
scroll.Position = UDim2.new(0, 10, 0, 50)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.Parent = container

-- Helper to create card
local function createPassCard(passData)
    local card = Instance.new("Frame")
    card.Name = passData.Key
    card.Size = UDim2.new(1, -20, 0, 100)
    card.BackgroundColor3 = COLORS.CardBg
    card.BorderSizePixel = 0
    card.Parent = scroll
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -120, 0, 30)
    nameLabel.Position = UDim2.new(0, 15, 0, 10)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = passData.Name
    nameLabel.TextColor3 = COLORS.Text
    nameLabel.TextSize = 18
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = card

    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(1, -120, 0, 50)
    descLabel.Position = UDim2.new(0, 15, 0, 40)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = passData.Desc
    descLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
    descLabel.TextSize = 14
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextWrapped = true
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.Parent = card

    local buyBtn = Instance.new("TextButton")
    buyBtn.Name = "BuyButton"
    buyBtn.Size = UDim2.new(0, 100, 0, 40)
    buyBtn.Position = UDim2.new(1, -110, 0.5, -20)
    buyBtn.BackgroundColor3 = COLORS.Green
    buyBtn.Text = "R$ " .. passData.Price
    buyBtn.TextColor3 = Color3.new(1,1,1)
    buyBtn.Font = Enum.Font.GothamBold
    buyBtn.TextSize = 16
    buyBtn.Parent = card
    Instance.new("UICorner", buyBtn).CornerRadius = UDim.new(0, 8)

    buyBtn.MouseButton1Click:Connect(function()
        if passData.Id > 0 then
            MarketplaceService:PromptGamePassPurchase(LocalPlayer, passData.Id)
        else
            warn("Cannot purchase placeholder ID (0)")
        end
    end)
    
    return card, buyBtn
end

local passCards = {}
for _, pass in ipairs(GAME_PASSES) do
    local card, btn = createPassCard(pass)
    passCards[pass.Key] = { Card = card, Btn = btn }
end

--------------------------------------------------------------------------------
-- Logic
--------------------------------------------------------------------------------

local function updateOwned(ownedData)
    for key, data in pairs(passCards) do
        local isOwned = ownedData[key]
        if isOwned then
            data.Btn.Text = "OWNED"
            data.Btn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            data.Btn.Active = false
        end
    end
end

local function toggleShop(force)
    if force ~= nil then
        shopGui.Enabled = force
    else
        shopGui.Enabled = not shopGui.Enabled
    end
end

closeBtn.MouseButton1Click:Connect(function()
    toggleShop(false)
end)

backdrop.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        toggleShop(false)
    end
end)

-- Listen for server updates
Remotes.GamePassOwned.OnClientEvent:Connect(function(ownedData)
    print("Received game pass data", ownedData)
    updateOwned(ownedData)
    -- If we receive data, it means we asked for it (e.g., clicked shop button)
    -- Or user just bought something
    -- Only open if not open? actually HUD button trigger this check.
    -- Let's let the HUD/Bindable toggle it
    toggleShop(true)
end)

-- Also listen for direct toggle if needed
local toggleEvent = Instance.new("BindableEvent")
toggleEvent.Name = "ToggleGamePassShop"
toggleEvent.Parent = ReplicatedStorage
toggleEvent.Event:Connect(function()
    toggleShop()
    -- also fetch latest data
    Remotes.CheckGamePasses:FireServer()
end)

print("[GamePassClient] Ready")
