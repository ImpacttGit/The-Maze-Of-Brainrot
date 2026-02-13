--[[
    InventoryClient.client.lua
    ==========================
    Client LocalScript — inventory viewer UI.
    
    Press TAB to toggle the inventory panel. Shows all items with
    rarity-colored names and a Drop button per item.
    
    Dependencies:
        - RemoteEvents
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--------------------------------------------------------------------------------
-- Rarity Colors (matches RarityConfig)
--------------------------------------------------------------------------------

local RARITY_COLORS = {
    Common = Color3.fromRGB(255, 255, 255),
    Rare = Color3.fromRGB(0, 120, 255),
    Epic = Color3.fromRGB(163, 53, 238),
    Legendary = Color3.fromRGB(255, 215, 0),
}

local RARITY_ORDER = { Common = 1, Rare = 2, Epic = 3, Legendary = 4 }

--------------------------------------------------------------------------------
-- Design Tokens
--------------------------------------------------------------------------------

local COLORS = {
    PanelBg = Color3.fromRGB(12, 12, 18),
    PanelStroke = Color3.fromRGB(80, 80, 100),
    ItemBg = Color3.fromRGB(22, 22, 30),
    ItemHover = Color3.fromRGB(32, 32, 44),
    TextPrimary = Color3.fromRGB(240, 240, 245),
    TextSecondary = Color3.fromRGB(150, 150, 170),
    DropButton = Color3.fromRGB(180, 50, 50),
    DropHover = Color3.fromRGB(220, 70, 70),
    HeaderText = Color3.fromRGB(255, 215, 0),
}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local isOpen = false
local inventoryData = {} -- Array of item tables from server
local currentMaxSlots = 99 -- Updated dynamically from server

--------------------------------------------------------------------------------
-- Create ScreenGui
--------------------------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "InventoryUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 15
screenGui.IgnoreGuiInset = true
screenGui.Enabled = false
screenGui.Parent = PlayerGui

-- Dim background
local dimBg = Instance.new("Frame")
dimBg.Name = "DimBg"
dimBg.Size = UDim2.new(1, 0, 1, 0)
dimBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dimBg.BackgroundTransparency = 0.5
dimBg.BorderSizePixel = 0
dimBg.ZIndex = 1
dimBg.Parent = screenGui

-- Main panel (centered)
local panel = Instance.new("Frame")
panel.Name = "InventoryPanel"
panel.Size = UDim2.new(0, 360, 0, 480)
panel.Position = UDim2.new(0.5, -180, 0.5, -240)
panel.BackgroundColor3 = COLORS.PanelBg
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.ZIndex = 2
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = COLORS.PanelStroke
panelStroke.Thickness = 1.5
panelStroke.Transparency = 0.3
panelStroke.Parent = panel

-- Header
local header = Instance.new("TextLabel")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 50)
header.Position = UDim2.new(0, 0, 0, 0)
header.BackgroundTransparency = 1
header.Text = "🎒 INVENTORY"
header.TextColor3 = COLORS.HeaderText
header.TextSize = 22
header.Font = Enum.Font.GothamBold
header.ZIndex = 3
header.Parent = panel

-- Capacity label
local capacityLabel = Instance.new("TextLabel")
capacityLabel.Name = "Capacity"
capacityLabel.Size = UDim2.new(1, -20, 0, 20)
capacityLabel.Position = UDim2.new(0, 10, 0, 42)
capacityLabel.BackgroundTransparency = 1
capacityLabel.Text = "0 / 99 slots"
capacityLabel.TextColor3 = COLORS.TextSecondary
capacityLabel.TextSize = 12
capacityLabel.Font = Enum.Font.GothamMedium
capacityLabel.TextXAlignment = Enum.TextXAlignment.Left
capacityLabel.ZIndex = 3
capacityLabel.Parent = panel

-- Scrolling frame for items
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "ItemList"
scrollFrame.Size = UDim2.new(1, -20, 1, -80)
scrollFrame.Position = UDim2.new(0, 10, 0, 68)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 4
scrollFrame.ScrollBarImageColor3 = COLORS.PanelStroke
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.ZIndex = 3
scrollFrame.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 6)
listLayout.Parent = scrollFrame

-- Empty state label
local emptyLabel = Instance.new("TextLabel")
emptyLabel.Name = "EmptyLabel"
emptyLabel.Size = UDim2.new(1, 0, 0, 60)
emptyLabel.BackgroundTransparency = 1
emptyLabel.Text = "No items yet.\nExplore the maze to find loot!"
emptyLabel.TextColor3 = COLORS.TextSecondary
emptyLabel.TextSize = 14
emptyLabel.Font = Enum.Font.GothamMedium
emptyLabel.TextWrapped = true
emptyLabel.ZIndex = 4
emptyLabel.Parent = scrollFrame

--------------------------------------------------------------------------------
-- Build item rows
--------------------------------------------------------------------------------

local function clearItems()
    for _, child in ipairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
end

local function buildItemRow(item, index: number): Frame
    local rarityColor = RARITY_COLORS[item.Rarity] or COLORS.TextPrimary
    local hasEquip = item.Rarity == "Epic" -- Epic items have power-ups

    local row = Instance.new("Frame")
    row.Name = "Item_" .. index
    row.Size = UDim2.new(1, 0, 0, 52)
    row.BackgroundColor3 = COLORS.ItemBg
    row.BackgroundTransparency = 0.3
    row.BorderSizePixel = 0
    row.LayoutOrder = index
    row.ZIndex = 4

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 6)
    rowCorner.Parent = row

    -- Rarity color bar (left edge)
    local colorBar = Instance.new("Frame")
    colorBar.Size = UDim2.new(0, 4, 1, -8)
    colorBar.Position = UDim2.new(0, 4, 0, 4)
    colorBar.BackgroundColor3 = rarityColor
    colorBar.BorderSizePixel = 0
    colorBar.ZIndex = 5
    colorBar.Parent = row

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 2)
    barCorner.Parent = colorBar

    -- Item name
    local nameWidth = hasEquip and -175 or -110
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, nameWidth, 0, 22)
    nameLabel.Position = UDim2.new(0, 16, 0, 5)
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
    local infoText = item.Rarity
    if item.FragmentValue and item.FragmentValue > 0 then
        infoText = item.Rarity .. " • 💎 " .. tostring(item.FragmentValue)
    end

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(1, nameWidth, 0, 16)
    infoLabel.Position = UDim2.new(0, 16, 0, 28)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = infoText
    infoLabel.TextColor3 = COLORS.TextSecondary
    infoLabel.TextSize = 11
    infoLabel.Font = Enum.Font.GothamMedium
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.ZIndex = 5
    infoLabel.Parent = row

    -- EQUIP button (Epic items only)
    if hasEquip then
        local equipBtn = Instance.new("TextButton")
        equipBtn.Name = "EquipButton"
        equipBtn.Size = UDim2.new(0, 55, 0, 30)
        equipBtn.Position = UDim2.new(1, -135, 0.5, -15)
        equipBtn.BackgroundColor3 = Color3.fromRGB(120, 50, 200)
        equipBtn.BorderSizePixel = 0
        equipBtn.Text = "⚡ USE"
        equipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        equipBtn.TextSize = 11
        equipBtn.Font = Enum.Font.GothamBold
        equipBtn.AutoButtonColor = false
        equipBtn.ZIndex = 5
        equipBtn.Parent = row

        local equipCorner = Instance.new("UICorner")
        equipCorner.CornerRadius = UDim.new(0, 5)
        equipCorner.Parent = equipBtn

        equipBtn.MouseEnter:Connect(function()
            TweenService:Create(equipBtn, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(150, 70, 240),
            }):Play()
        end)

        equipBtn.MouseLeave:Connect(function()
            TweenService:Create(equipBtn, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(120, 50, 200),
            }):Play()
        end)

        equipBtn.MouseButton1Click:Connect(function()
            Remotes.RequestEquipItem:FireServer(item.UniqueId)
        end)
    end

    -- Drop button
    local dropBtn = Instance.new("TextButton")
    dropBtn.Name = "DropButton"
    dropBtn.Size = UDim2.new(0, 55, 0, 30)
    dropBtn.Position = UDim2.new(1, -70, 0.5, -15)
    dropBtn.BackgroundColor3 = COLORS.DropButton
    dropBtn.BorderSizePixel = 0
    dropBtn.Text = "DROP"
    dropBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    dropBtn.TextSize = 12
    dropBtn.Font = Enum.Font.GothamBold
    dropBtn.AutoButtonColor = false
    dropBtn.ZIndex = 5
    dropBtn.Parent = row

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 5)
    btnCorner.Parent = dropBtn

    -- Hover effects
    dropBtn.MouseEnter:Connect(function()
        TweenService:Create(dropBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = COLORS.DropHover,
        }):Play()
    end)

    dropBtn.MouseLeave:Connect(function()
        TweenService:Create(dropBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = COLORS.DropButton,
        }):Play()
    end)

    -- Drop action
    dropBtn.MouseButton1Click:Connect(function()
        Remotes.RequestDropItem:FireServer(item.UniqueId)
    end)

    row.Parent = scrollFrame
    return row
end

local function refreshUI()
    clearItems()

    -- Sort by rarity (Legendary first)
    table.sort(inventoryData, function(a, b)
        local orderA = RARITY_ORDER[a.Rarity] or 0
        local orderB = RARITY_ORDER[b.Rarity] or 0
        if orderA ~= orderB then
            return orderA > orderB
        end
        return a.DisplayName < b.DisplayName
    end)

    emptyLabel.Visible = #inventoryData == 0
    capacityLabel.Text = tostring(#inventoryData) .. " / " .. tostring(currentMaxSlots) .. " slots"

    -- Dynamic title: Backpack in maze, Inventory in lobby
    if currentMaxSlots <= 5 then
        header.Text = "🎒 BACKPACK"
    else
        header.Text = "🎒 INVENTORY"
    end

    for i, item in ipairs(inventoryData) do
        buildItemRow(item, i)
    end
end

--------------------------------------------------------------------------------
-- Open / Close
--------------------------------------------------------------------------------

local function openInventory()
    if isOpen then return end
    isOpen = true

    -- Request fresh data from server
    Remotes.RequestInventoryData:FireServer()

    screenGui.Enabled = true

    -- Animate panel in
    panel.Size = UDim2.new(0, 20, 0, 20)
    panel.Position = UDim2.new(0.5, -10, 0.5, -10)
    dimBg.BackgroundTransparency = 1

    TweenService:Create(dimBg, TweenInfo.new(0.25), {
        BackgroundTransparency = 0.5,
    }):Play()

    TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 360, 0, 480),
        Position = UDim2.new(0.5, -180, 0.5, -240),
    }):Play()
end

local function closeInventory()
    if not isOpen then return end

    TweenService:Create(dimBg, TweenInfo.new(0.2), {
        BackgroundTransparency = 1,
    }):Play()

    TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(0.5, -10, 0.5, -10),
    }):Play()

    task.wait(0.25)
    screenGui.Enabled = false
    isOpen = false
end

local function toggleInventory()
    if isOpen then
        closeInventory()
    else
        openInventory()
    end
end

--------------------------------------------------------------------------------
-- Keybind: TAB to toggle
--------------------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.G then
        toggleInventory()
    end
end)

-- Clicking dim background closes
dimBg.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        closeInventory()
    end
end)

--------------------------------------------------------------------------------
-- Listen for inventory data from server
--------------------------------------------------------------------------------

Remotes.InventoryData.OnClientEvent:Connect(function(items: { any })
    inventoryData = items or {}
    refreshUI()
end)

-- Listen for drop results
Remotes.DropItemResult.OnClientEvent:Connect(function(success: boolean, message: string)
    if success then
        -- Re-request inventory to refresh
        Remotes.RequestInventoryData:FireServer()
    else
        warn("[InventoryClient] Drop failed: " .. tostring(message))
    end
end)

-- Listen for inventory updates (slot count changes when entering/leaving maze)
Remotes.UpdateInventory.OnClientEvent:Connect(function(count: number, maxSlots: number)
    currentMaxSlots = maxSlots or 99
    -- If currently open, refresh display
    if isOpen then
        refreshUI()
    end
end)

print("[InventoryClient] Initialized — Press G to open inventory")
