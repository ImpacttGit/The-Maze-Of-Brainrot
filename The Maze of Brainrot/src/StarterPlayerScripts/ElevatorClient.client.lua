--[[
    ElevatorClient.lua
    ==================
    Client LocalScript — handles the elevator interaction UI and fade effects.
    
    Responsibilities:
        - Listen for ProximityPrompt on the ElevatorDoor part
        - Show a modal confirmation UI: "ENTER THE MAZE?"
        - Fire RequestMazeEntry to server on confirm
        - Play a cinematic fade-to-black transition on MazeEntryResult
    
    Dependencies:
        - RemoteEvents
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local ELEVATOR_DOOR_NAME = "ElevatorDoor"

local COLORS = {
    ModalBg = Color3.fromRGB(10, 10, 15),
    ModalStroke = Color3.fromRGB(255, 215, 0), -- Gold
    TitleText = Color3.fromRGB(255, 215, 0),
    SubText = Color3.fromRGB(200, 200, 210),
    EnterButton = Color3.fromRGB(50, 180, 80),
    EnterButtonHover = Color3.fromRGB(60, 220, 100),
    CancelButton = Color3.fromRGB(180, 50, 50),
    CancelButtonHover = Color3.fromRGB(220, 70, 70),
    ButtonText = Color3.fromRGB(255, 255, 255),
    FadeBlack = Color3.fromRGB(0, 0, 0),
}

local TWEEN_FADE_IN = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local TWEEN_FADE_OUT = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local TWEEN_MODAL_IN = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_MODAL_OUT = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local isModalOpen = false
local isTransitioning = false

--------------------------------------------------------------------------------
-- Create the ScreenGui for elevator UI
--------------------------------------------------------------------------------

local elevatorGui = Instance.new("ScreenGui")
elevatorGui.Name = "ElevatorUI"
elevatorGui.ResetOnSpawn = false
elevatorGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
elevatorGui.DisplayOrder = 10 -- Above MainHUD
elevatorGui.IgnoreGuiInset = true
elevatorGui.Enabled = false
elevatorGui.Parent = PlayerGui

--------------------------------------------------------------------------------
-- Fade Overlay (full-screen black for transitions)
--------------------------------------------------------------------------------

local fadeOverlay = Instance.new("Frame")
fadeOverlay.Name = "FadeOverlay"
fadeOverlay.Size = UDim2.new(1, 0, 1, 0)
fadeOverlay.Position = UDim2.new(0, 0, 0, 0)
fadeOverlay.BackgroundColor3 = COLORS.FadeBlack
fadeOverlay.BackgroundTransparency = 1 -- Starts invisible
fadeOverlay.BorderSizePixel = 0
fadeOverlay.ZIndex = 100
fadeOverlay.Parent = elevatorGui

--------------------------------------------------------------------------------
-- Modal UI: "ENTER THE MAZE?"
--------------------------------------------------------------------------------

-- Dim background behind modal
local dimBg = Instance.new("Frame")
dimBg.Name = "DimBackground"
dimBg.Size = UDim2.new(1, 0, 1, 0)
dimBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dimBg.BackgroundTransparency = 1
dimBg.BorderSizePixel = 0
dimBg.ZIndex = 50
dimBg.Visible = false
dimBg.Parent = elevatorGui

-- Modal Panel
local modal = Instance.new("Frame")
modal.Name = "MazeEntryModal"
modal.Size = UDim2.new(0, 340, 0, 220)
modal.Position = UDim2.new(0.5, -170, 0.5, -110)
modal.BackgroundColor3 = COLORS.ModalBg
modal.BackgroundTransparency = 0.15
modal.BorderSizePixel = 0
modal.ZIndex = 51
modal.Visible = false
modal.Parent = elevatorGui

local modalCorner = Instance.new("UICorner")
modalCorner.CornerRadius = UDim.new(0, 12)
modalCorner.Parent = modal

local modalStroke = Instance.new("UIStroke")
modalStroke.Color = COLORS.ModalStroke
modalStroke.Thickness = 2
modalStroke.Transparency = 0.3
modalStroke.Parent = modal

-- Title: "ENTER THE MAZE?"
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 40)
title.Position = UDim2.new(0, 0, 0, 25)
title.BackgroundTransparency = 1
title.Text = "⚠️ ENTER THE MAZE?"
title.TextColor3 = COLORS.TitleText
title.TextSize = 26
title.Font = Enum.Font.GothamBold
title.ZIndex = 52
title.Parent = modal

-- Subtitle warning
local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.Size = UDim2.new(1, -40, 0, 40)
subtitle.Position = UDim2.new(0, 20, 0, 70)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Something lurks in the dark.\nDeath means losing your loot."
subtitle.TextColor3 = COLORS.SubText
subtitle.TextSize = 14
subtitle.Font = Enum.Font.GothamMedium
subtitle.TextWrapped = true
subtitle.ZIndex = 52
subtitle.Parent = modal

-- Helper: Create a styled button
local function createButton(name: string, text: string, color: Color3, hoverColor: Color3, posX: number): TextButton
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(0, 130, 0, 44)
    btn.Position = UDim2.new(0.5, posX, 1, -65)
    btn.BackgroundColor3 = color
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = COLORS.ButtonText
    btn.TextSize = 18
    btn.Font = Enum.Font.GothamBold
    btn.ZIndex = 52
    btn.AutoButtonColor = false
    btn.Parent = modal

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btn

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Color3.fromRGB(255, 255, 255)
    btnStroke.Thickness = 1
    btnStroke.Transparency = 0.7
    btnStroke.Parent = btn

    -- Hover effects
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = hoverColor,
        }):Play()
    end)

    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = color,
        }):Play()
    end)

    return btn
end

local enterBtn = createButton("EnterButton", "ENTER", COLORS.EnterButton, COLORS.EnterButtonHover, -75)
local cancelBtn = createButton("CancelButton", "CANCEL", COLORS.CancelButton, COLORS.CancelButtonHover, 75 - 130)

--------------------------------------------------------------------------------
-- Modal Show / Hide
--------------------------------------------------------------------------------

local function showModal()
    if isModalOpen or isTransitioning then return end
    isModalOpen = true
    elevatorGui.Enabled = true

    -- Animate in
    dimBg.Visible = true
    dimBg.BackgroundTransparency = 1
    TweenService:Create(dimBg, TweenInfo.new(0.3), {
        BackgroundTransparency = 0.6,
    }):Play()

    modal.Visible = true
    modal.Size = UDim2.new(0, 20, 0, 20)
    modal.Position = UDim2.new(0.5, -10, 0.5, -10)

    TweenService:Create(modal, TWEEN_MODAL_IN, {
        Size = UDim2.new(0, 340, 0, 220),
        Position = UDim2.new(0.5, -170, 0.5, -110),
    }):Play()
end

local function hideModal()
    if not isModalOpen then return end

    -- Animate out
    TweenService:Create(dimBg, TweenInfo.new(0.2), {
        BackgroundTransparency = 1,
    }):Play()

    TweenService:Create(modal, TWEEN_MODAL_OUT, {
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(0.5, -10, 0.5, -10),
    }):Play()

    task.wait(0.25)
    modal.Visible = false
    dimBg.Visible = false
    isModalOpen = false

    if not isTransitioning then
        elevatorGui.Enabled = false
    end
end

--------------------------------------------------------------------------------
-- Fade Transition
--------------------------------------------------------------------------------

local function playFadeTransition()
    isTransitioning = true
    elevatorGui.Enabled = true
    fadeOverlay.BackgroundTransparency = 1

    -- Fade to black
    local fadeIn = TweenService:Create(fadeOverlay, TWEEN_FADE_IN, {
        BackgroundTransparency = 0,
    })
    fadeIn:Play()
    fadeIn.Completed:Wait()

    -- Hold black while server teleports
    task.wait(0.5)

    -- Fade back in
    local fadeOut = TweenService:Create(fadeOverlay, TWEEN_FADE_OUT, {
        BackgroundTransparency = 1,
    })
    fadeOut:Play()
    fadeOut.Completed:Wait()

    isTransitioning = false
    if not isModalOpen then
        elevatorGui.Enabled = false
    end
end

--------------------------------------------------------------------------------
-- Button Handlers
--------------------------------------------------------------------------------

enterBtn.MouseButton1Click:Connect(function()
    if isTransitioning then return end

    hideModal()

    -- Fire request to server
    Remotes.RequestMazeEntry:FireServer()
end)

cancelBtn.MouseButton1Click:Connect(function()
    hideModal()
end)

--------------------------------------------------------------------------------
-- Listen for Maze Entry Result from Server
--------------------------------------------------------------------------------

Remotes.MazeEntryResult.OnClientEvent:Connect(function(success: boolean, message: string?)
    if success then
        -- Play the cinematic fade transition
        task.spawn(playFadeTransition)
    else
        -- Show error feedback (brief notification)
        warn("[ElevatorClient] Maze entry denied: " .. tostring(message))
    end
end)

--------------------------------------------------------------------------------
-- Connect to ProximityPrompt on the Elevator Door
--------------------------------------------------------------------------------

local function setupElevatorPrompt()
    -- Wait for the ElevatorDoor to exist
    local elevatorDoor = Workspace:WaitForChild(ELEVATOR_DOOR_NAME, 30)
    if not elevatorDoor then
        warn("[ElevatorClient] ElevatorDoor not found in Workspace!")
        return
    end

    -- Find or wait for the ProximityPrompt
    local prompt = elevatorDoor:WaitForChild("ProximityPrompt", 10)
    if not prompt then
        warn("[ElevatorClient] No ProximityPrompt on ElevatorDoor!")
        return
    end

    -- When player triggers the prompt, show the modal
    prompt.Triggered:Connect(function(triggerPlayer)
        if triggerPlayer == LocalPlayer then
            showModal()
        end
    end)

    print("[ElevatorClient] Elevator prompt connected")
end

-- Run setup
task.spawn(setupElevatorPrompt)
print("[ElevatorClient] Elevator client initialized")
