--[[
    PartyClient.lua
    ===============
    Client LocalScript — Party UI and interaction.
    
    Features:
    - Party Panel: List members, Leave/Kick/Invite buttons.
    - HUD Integration: Toggle button.
    - Invite Popups: Accept/Decline incoming invites.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--------------------------------------------------------------------------------
-- Constants & Styles
--------------------------------------------------------------------------------

local COLORS = {
    PanelBg = Color3.fromRGB(15, 15, 20),
    HeaderBg = Color3.fromRGB(25, 25, 35),
    MemberBg = Color3.fromRGB(30, 30, 40),
    Accent = Color3.fromRGB(100, 80, 255), -- Purple-ish
    Green = Color3.fromRGB(50, 200, 100),
    Red = Color3.fromRGB(200, 60, 60),
    Text = Color3.fromRGB(240, 240, 240),
    SubText = Color3.fromRGB(180, 180, 180)
}

--------------------------------------------------------------------------------
-- UI Builders
--------------------------------------------------------------------------------

local partyGui = Instance.new("ScreenGui")
partyGui.Name = "PartyUI"
partyGui.ResetOnSpawn = false
partyGui.DisplayOrder = 10
partyGui.Parent = PlayerGui

-- Toggle Button is managed by HUDController via BindableEvent

-- Main Panel
local panel = Instance.new("Frame")
panel.Name = "MainPanel"
panel.Size = UDim2.new(0, 250, 0, 350)
panel.Position = UDim2.new(0.5, -125, 0.5, -175) -- Centered
panel.BackgroundColor3 = COLORS.PanelBg
panel.Visible = false
panel.Parent = partyGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", panel).Color = COLORS.Accent

local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, 0, 0, 40)
header.BackgroundColor3 = COLORS.HeaderBg
header.Text = "PARTY"
header.TextColor3 = COLORS.Text
header.Font = Enum.Font.GothamBold
header.TextSize = 18
header.Parent = panel
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

-- Member List
local memberList = Instance.new("ScrollingFrame")
memberList.Size = UDim2.new(1, -20, 1, -130)
memberList.Position = UDim2.new(0, 10, 0, 50)
memberList.BackgroundTransparency = 1
memberList.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 5)
layout.Parent = memberList

-- Actions Area (Create / Invite / Leave)
local actionFrame = Instance.new("Frame")
actionFrame.Size = UDim2.new(1, -20, 0, 80)
actionFrame.Position = UDim2.new(0, 10, 1, -90)
actionFrame.BackgroundTransparency = 1
actionFrame.Parent = panel

--------------------------------------------------------------------------------
-- Logic
--------------------------------------------------------------------------------

local currentParty = nil -- { Members = {}, LeaderId = ... }

local function clearMembers()
    for _, child in ipairs(memberList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
end

local function updateActions()
    actionFrame:ClearAllChildren()
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.Parent = actionFrame

    if not currentParty then
        -- "Create Party" button
        local createBtn = Instance.new("TextButton")
        createBtn.Size = UDim2.new(1, 0, 0, 35)
        createBtn.BackgroundColor3 = COLORS.Green
        createBtn.Text = "CREATE PARTY"
        createBtn.TextColor3 = COLORS.Text
        createBtn.Font = Enum.Font.GothamBold
        createBtn.Parent = actionFrame
        Instance.new("UICorner", createBtn).CornerRadius = UDim.new(0, 6)
        
        createBtn.MouseButton1Click:Connect(function()
            Remotes.CreateParty:FireServer()
        end)
    else
        -- Invite Input
        local inviteBox = Instance.new("TextBox")
        inviteBox.Size = UDim2.new(1, 0, 0, 30)
        inviteBox.BackgroundColor3 = COLORS.HeaderBg
        inviteBox.PlaceholderText = "Type player name..."
        inviteBox.Text = ""
        inviteBox.TextColor3 = COLORS.Text
        inviteBox.PlaceholderColor3 = COLORS.SubText
        inviteBox.Font = Enum.Font.Gotham
        inviteBox.Parent = actionFrame
        Instance.new("UICorner", inviteBox).CornerRadius = UDim.new(0, 6)
        
        local inviteBtn = Instance.new("TextButton")
        inviteBtn.Size = UDim2.new(0, 60, 1, 0)
        inviteBtn.Position = UDim2.new(1, -60, 0, 0)
        inviteBtn.BackgroundColor3 = COLORS.Accent
        inviteBtn.Text = "INVITE"
        inviteBtn.TextColor3 = COLORS.Text
        inviteBtn.Font = Enum.Font.GothamBold
        inviteBtn.Parent = inviteBox
        Instance.new("UICorner", inviteBtn).CornerRadius = UDim.new(0, 6)
        
        inviteBtn.MouseButton1Click:Connect(function()
            if inviteBox.Text ~= "" then
                Remotes.InvitePlayer:FireServer(inviteBox.Text)
                inviteBox.Text = ""
            end
        end)
        
        -- Leave Button
        local leaveBtn = Instance.new("TextButton")
        leaveBtn.Size = UDim2.new(1, 0, 0, 30)
        leaveBtn.BackgroundColor3 = COLORS.Red
        leaveBtn.Text = "LEAVE PARTY"
        leaveBtn.TextColor3 = COLORS.Text
        leaveBtn.Font = Enum.Font.GothamBold
        leaveBtn.Parent = actionFrame
        Instance.new("UICorner", leaveBtn).CornerRadius = UDim.new(0, 6)
        
        leaveBtn.MouseButton1Click:Connect(function()
            Remotes.LeaveParty:FireServer()
        end)
    end
end

local function updatePartyUI(data)
    currentParty = data
    clearMembers()
    updateActions()
    
    if not data then
        -- Show local player only? Or empty instructions?
        -- Just allow "Create Party"
        return
    end
    
    local isLeader = (data.LeaderId == LocalPlayer.UserId)
    
    for _, member in ipairs(data.Members) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 30)
        row.BackgroundColor3 = COLORS.MemberBg
        row.Parent = memberList
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
        
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -30, 1, 0)
        nameLabel.Position = UDim2.new(0, 10, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = member.Name
        nameLabel.TextColor3 = COLORS.Text
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = row
        
        if member.UserId == data.LeaderId then
            nameLabel.TextColor3 = COLORS.Gold or Color3.fromRGB(255, 215, 0)
            nameLabel.Text = "👑 " .. member.Name
        end
        
        -- Kick button (if local player is leader AND row is not self)
        if isLeader and member.UserId ~= LocalPlayer.UserId then
            local kickBtn = Instance.new("TextButton")
            kickBtn.Size = UDim2.new(0, 20, 0, 20)
            kickBtn.Position = UDim2.new(1, -25, 0.5, -10)
            kickBtn.BackgroundColor3 = COLORS.Red
            kickBtn.Text = "X"
            kickBtn.TextColor3 = COLORS.Text
            kickBtn.Parent = row
            Instance.new("UICorner", kickBtn).CornerRadius = UDim.new(0, 4)
            
            kickBtn.MouseButton1Click:Connect(function()
                Remotes.KickPlayer:FireServer(member.UserId)
            end)
        end
    end
end

local function showInvitePopup(data)
    -- data = { PartyId, LeaderName }
    local popup = Instance.new("Frame")
    popup.Size = UDim2.new(0, 300, 0, 120)
    popup.Position = UDim2.new(0.5, -150, 0.2, 0)
    popup.BackgroundColor3 = COLORS.PanelBg
    popup.Parent = partyGui
    Instance.new("UICorner", popup).CornerRadius = UDim.new(0, 10)
    Instance.new("UIStroke", popup).Color = COLORS.Green
    popup.UIStroke.Thickness = 2
    
    local msg = Instance.new("TextLabel")
    msg.Size = UDim2.new(1, -20, 0, 60)
    msg.Position = UDim2.new(0, 10, 0, 10)
    msg.BackgroundTransparency = 1
    msg.Text = data.LeaderName .. " invited you to a party!"
    msg.TextColor3 = COLORS.Text
    msg.TextWrapped = true
    msg.Font = Enum.Font.GothamBold
    msg.TextSize = 18
    msg.Parent = popup
    
    local acceptBtn = Instance.new("TextButton")
    acceptBtn.Size = UDim2.new(0, 100, 0, 35)
    acceptBtn.Position = UDim2.new(0, 20, 1, -45)
    acceptBtn.BackgroundColor3 = COLORS.Green
    acceptBtn.Text = "ACCEPT"
    acceptBtn.TextColor3 = COLORS.Text
    acceptBtn.Font = Enum.Font.GothamBold
    acceptBtn.Parent = popup
    Instance.new("UICorner", acceptBtn).CornerRadius = UDim.new(0, 6)
    
    local declineBtn = Instance.new("TextButton")
    declineBtn.Size = UDim2.new(0, 100, 0, 35)
    declineBtn.Position = UDim2.new(1, -120, 1, -45)
    declineBtn.BackgroundColor3 = COLORS.Red
    declineBtn.Text = "DECLINE"
    declineBtn.TextColor3 = COLORS.Text
    declineBtn.Font = Enum.Font.GothamBold
    declineBtn.Parent = popup
    Instance.new("UICorner", declineBtn).CornerRadius = UDim.new(0, 6)
    
    local function close()
        popup:Destroy()
    end
    
    acceptBtn.MouseButton1Click:Connect(function()
        Remotes.AcceptInvite:FireServer(data.PartyId)
        close()
    end)
    
    declineBtn.MouseButton1Click:Connect(close)
    
    -- Auto-decline after 30s
    task.delay(30, close)
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

toggleBtn.MouseButton1Click:Connect(function()
    panel.Visible = not panel.Visible
end)

Remotes.PartyUpdate.OnClientEvent:Connect(updatePartyUI)
Remotes.PartyInviteReceived.OnClientEvent:Connect(showInvitePopup)

updateActions() -- Init default state (Create Party)

print("[PartyClient] Initialized")
