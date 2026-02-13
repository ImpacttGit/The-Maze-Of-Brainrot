--[[
    FollowerService.lua
    ===================
    Server Module — spawns & manages Legendary follower NPCs.
    
    When a player has a Legendary item with IsFollower=true in their inventory,
    a small Part-based follower model walks beside them.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))
local ItemDatabase = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Data"):WaitForChild("ItemDatabase"))

local FollowerService = {}

-- { [UserId] = { [ItemId] = followerModel } }
local activeFollowers = {}

--------------------------------------------------------------------------------
-- Follower Colors (unique per legendary)
--------------------------------------------------------------------------------

local FOLLOWER_VISUALS = {
    tralalero_tralala = {
        BodyColor = Color3.fromRGB(80, 130, 200),
        EyeColor = Color3.fromRGB(255, 255, 0),
        Scale = 0.6,
        GlowColor = Color3.fromRGB(255, 215, 0),
    },
    chimpanzini_bananini = {
        BodyColor = Color3.fromRGB(100, 70, 40),
        EyeColor = Color3.fromRGB(255, 200, 0),
        Scale = 0.5,
        GlowColor = Color3.fromRGB(255, 200, 50),
    },
    bombardiro_crocodilo = {
        BodyColor = Color3.fromRGB(50, 120, 50),
        EyeColor = Color3.fromRGB(255, 100, 0),
        Scale = 0.7,
        GlowColor = Color3.fromRGB(255, 180, 0),
    },
    tung_tung_tung_sahur = {
        BodyColor = Color3.fromRGB(60, 60, 70),
        EyeColor = Color3.fromRGB(255, 0, 0),
        Scale = 0.55,
        GlowColor = Color3.fromRGB(255, 50, 50),
    },
    la_vaca_saturno = {
        BodyColor = Color3.fromRGB(220, 200, 180),
        EyeColor = Color3.fromRGB(200, 0, 255),
        Scale = 0.65,
        GlowColor = Color3.fromRGB(200, 100, 255),
    },
}

--------------------------------------------------------------------------------
-- Create a follower model
--------------------------------------------------------------------------------

local function createFollowerModel(itemId: string, player: Player): Model?
    local visuals = FOLLOWER_VISUALS[itemId]
    if not visuals then return nil end

    local itemDef = ItemDatabase.getItem(itemId)
    if not itemDef then return nil end

    local scale = visuals.Scale

    local model = Instance.new("Model")
    model.Name = "Follower_" .. itemId

    -- Body
    local body = Instance.new("Part")
    body.Name = "HumanoidRootPart"
    body.Size = Vector3.new(2 * scale, 3 * scale, 1.5 * scale)
    body.Color = visuals.BodyColor
    body.Material = Enum.Material.SmoothPlastic
    body.Anchored = false
    body.CanCollide = false
    body.Parent = model

    -- Head
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(1.5 * scale, 1.5 * scale, 1.5 * scale)
    head.Color = visuals.BodyColor
    head.Material = Enum.Material.SmoothPlastic
    head.Anchored = false
    head.CanCollide = false
    head.Parent = model

    local headWeld = Instance.new("WeldConstraint")
    headWeld.Part0 = body
    headWeld.Part1 = head
    headWeld.Parent = head

    head.CFrame = body.CFrame * CFrame.new(0, 2.5 * scale, 0)

    -- Eyes
    for _, xOff in ipairs({-0.3 * scale, 0.3 * scale}) do
        local eye = Instance.new("Part")
        eye.Name = "Eye"
        eye.Size = Vector3.new(0.3 * scale, 0.3 * scale, 0.15 * scale)
        eye.Color = visuals.EyeColor
        eye.Material = Enum.Material.Neon
        eye.Anchored = false
        eye.CanCollide = false
        eye.Parent = model

        local eyeWeld = Instance.new("WeldConstraint")
        eyeWeld.Part0 = head
        eyeWeld.Part1 = eye
        eyeWeld.Parent = eye

        eye.CFrame = head.CFrame * CFrame.new(xOff, 0.1 * scale, -0.7 * scale)
    end

    -- Gold shimmer particles
    local particles = Instance.new("ParticleEmitter")
    particles.Color = ColorSequence.new(visuals.GlowColor)
    particles.Size = NumberSequence.new(0.15, 0)
    particles.Lifetime = NumberRange.new(0.5, 1.5)
    particles.Rate = 12
    particles.Speed = NumberRange.new(0.5, 1.5)
    particles.SpreadAngle = Vector2.new(360, 360)
    particles.LightEmission = 1
    particles.Parent = body

    -- Gold glow
    local glow = Instance.new("PointLight")
    glow.Brightness = 1
    glow.Range = 8
    glow.Color = visuals.GlowColor
    glow.Parent = body

    -- Humanoid for movement
    local humanoid = Instance.new("Humanoid")
    humanoid.WalkSpeed = 14
    humanoid.MaxHealth = math.huge
    humanoid.Health = math.huge
    humanoid.Parent = model

    model.PrimaryPart = body

    -- Name billboard
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 150, 0, 25)
    bb.StudsOffset = Vector3.new(0, 2 * scale, 0)
    bb.AlwaysOnTop = false
    bb.Parent = head

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = itemDef.DisplayName
    nameLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    nameLabel.TextSize = 12
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextStrokeTransparency = 0.5
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.Parent = bb

    return model
end

--------------------------------------------------------------------------------
-- Follow logic: Client handles movement (Network Ownership)
--------------------------------------------------------------------------------
-- startFollowing removed. Client uses RenderStepped.

--------------------------------------------------------------------------------
-- Update followers for a player
--------------------------------------------------------------------------------

function FollowerService.updateFollowers(player: Player)
    local PlayerManager = require(ServerScriptService:WaitForChild("PlayerManager"))

    local userId = player.UserId
    local character = player.Character
    if not character then return end

    -- Get current legendary followers in inventory
    local items = PlayerManager.getInventoryList(player)
    local followerItems = {}
    for _, item in ipairs(items) do
        if item.Rarity == "Legendary" and item.IsFollower then
            followerItems[item.ItemId] = true
        end
    end

    -- Initialize tracking
    if not activeFollowers[userId] then
        activeFollowers[userId] = {}
    end

    -- Remove followers that player no longer has
    for itemId, model in pairs(activeFollowers[userId]) do
        if not followerItems[itemId] then
            if model and model.Parent then model:Destroy() end
            activeFollowers[userId][itemId] = nil
        end
    end

    -- Spawn new followers
    local offsetIndex = 0
    for itemId, _ in pairs(followerItems) do
        if not activeFollowers[userId][itemId] then
            local model = createFollowerModel(itemId, player)
            if model then
                local hrp = character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    model:SetPrimaryPartCFrame(hrp.CFrame * CFrame.new(3 + offsetIndex * 2, 0, -2))
                end
                
                -- NETWORK OWNERSHIP for smooth client physics
                if model.PrimaryPart then
                    model.PrimaryPart:SetNetworkOwner(player)
                end
                
                model.Parent = Workspace

                -- Tell client to animate/smooth this
                Remotes.SpawnFollower:FireClient(player, model, itemId, offsetIndex)

                activeFollowers[userId][itemId] = model
                offsetIndex += 1
            end
        else
            offsetIndex += 1
        end
    end
end

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

function FollowerService.cleanup(player: Player)
    local userId = player.UserId
    if activeFollowers[userId] then
        for _, model in pairs(activeFollowers[userId]) do
            if model and model.Parent then model:Destroy() end
        end
        activeFollowers[userId] = nil
    end
end

--------------------------------------------------------------------------------
-- Connections
--------------------------------------------------------------------------------

Players.PlayerRemoving:Connect(function(player)
    FollowerService.cleanup(player)
end)

print("[FollowerService] Initialized")

return FollowerService
