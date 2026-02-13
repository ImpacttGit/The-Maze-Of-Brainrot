--[[
    EntityManager.lua
    =================
    Server Script — spawns and manages AI entities within maze instances.
    
    AI Overhaul:
        - All entities actively seek the player (PlayerSeekChance)
        - Pursuit persists for PursuitDuration even after losing sight
        - Kill check runs on a fast 0.1s loop separate from behavior
        - Entities are dangerous but escapable (LoseInterestRange)
    
    Dependencies:
        - EntityConfig, MazeConfig
        - PathfindingService for navigation
        - RemoteEvents for client updates
]]

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local EntityConfig = require(Modules.Data.EntityConfig)
local MazeConfig = require(Modules.Data.MazeConfig)

local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))

local EntityManager = {}

-- Active entity sessions: { [UserId] = { model, connection, alive } }
local activeEntities = {}

-- Camera look data from clients (for Mute Mannequin)
local playerCameraData = {}

Remotes.CameraCheck.OnServerEvent:Connect(function(player, lookDir)
    playerCameraData[player.UserId] = {
        lookDirection = lookDir,
        timestamp = tick(),
    }
end)

--------------------------------------------------------------------------------
-- INTERNAL: Create entity NPC model
--------------------------------------------------------------------------------

local function createEntityModel(entityDef: any, spawnCFrame: CFrame, folder: Folder): Model
    local model = Instance.new("Model")
    model.Name = "Entity_" .. entityDef.EntityId

    local body = Instance.new("Part")
    body.Name = "HumanoidRootPart"
    body.Size = Vector3.new(
        3 * entityDef.BodyScale,
        6 * entityDef.BodyScale,
        2 * entityDef.BodyScale
    )
    body.CFrame = spawnCFrame + Vector3.new(0, 3 * entityDef.BodyScale, 0)
    body.Anchored = false
    body.CanCollide = true
    body.Color = entityDef.Color
    body.Material = Enum.Material.SmoothPlastic
    body.Parent = model

    local humanoid = Instance.new("Humanoid")
    humanoid.WalkSpeed = entityDef.Speed
    humanoid.MaxHealth = math.huge
    humanoid.Health = math.huge
    humanoid.Parent = model

    model.PrimaryPart = body

    -- Creepy glowing eyes
    local eyeSize = Vector3.new(0.4, 0.4, 0.2) * entityDef.BodyScale
    for _, offset in ipairs({ -0.6, 0.6 }) do
        local eye = Instance.new("Part")
        eye.Name = "Eye"
        eye.Size = eyeSize
        eye.Material = Enum.Material.Neon
        eye.Color = Color3.fromRGB(255, 0, 0)
        eye.Anchored = false
        eye.CanCollide = false
        eye.Parent = model

        local weld = Instance.new("WeldConstraint")
        weld.Part0 = body
        weld.Part1 = eye
        weld.Parent = eye

        eye.CFrame = body.CFrame * CFrame.new(
            offset * entityDef.BodyScale,
            1.5 * entityDef.BodyScale,
            -(entityDef.BodyScale)
        )
    end

    -- Ambient sound (skip placeholders)
    if entityDef.SoundId and entityDef.SoundId ~= "rbxassetid://0" then
        local sound = Instance.new("Sound")
        sound.SoundId = entityDef.SoundId
        sound.Looped = true
        sound.Volume = entityDef.SoundVolume
        sound.RollOffMode = Enum.RollOffMode.Linear
        sound.RollOffMinDistance = 5
        sound.RollOffMaxDistance = entityDef.SoundMaxDistance
        sound.Parent = body
        sound:Play()
    end

    -- Red glow
    local glow = Instance.new("PointLight")
    glow.Brightness = 1
    glow.Range = 15
    glow.Color = Color3.fromRGB(255, 0, 0)
    glow.Parent = body

    model.Parent = folder
    return model
end

--------------------------------------------------------------------------------
-- INTERNAL: Navigate entity to a target position using PathfindingService
--------------------------------------------------------------------------------

local function navigateTo(model: Model, targetPos: Vector3, speed: number)
    local humanoid = model:FindFirstChildWhichIsA("Humanoid")
    if not humanoid or not model.PrimaryPart then return end

    humanoid.WalkSpeed = speed

    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 6,
        AgentCanJump = false,
    })

    local success = pcall(function()
        path:ComputeAsync(model.PrimaryPart.Position, targetPos)
    end)

    if success and path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        for _, wp in ipairs(waypoints) do
            if not model.Parent then return end
            humanoid:MoveTo(wp.Position)
            humanoid.MoveToFinished:Wait()
        end
    else
        -- Fallback: direct move
        humanoid:MoveTo(targetPos)
        task.wait(1)
    end
end

--------------------------------------------------------------------------------
-- INTERNAL: Get random cell position within the maze
--------------------------------------------------------------------------------

local function getRandomMazePosition(origin: Vector3): Vector3
    local ts = MazeConfig.TileSize
    local w = MazeConfig.GridWidth
    local h = MazeConfig.GridHeight

    local rx = math.random(1, w)
    local rz = math.random(1, h)

    return origin + Vector3.new(
        (rx - 0.5) * ts,
        3,
        (rz - 0.5) * ts
    )
end

--------------------------------------------------------------------------------
-- INTERNAL: Get player position / check movement / LoS / camera
--------------------------------------------------------------------------------

local function getPlayerPosition(player: Player): Vector3?
    local character = player.Character
    if not character then return nil end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position or nil
end

local function isInCameraView(player: Player, entityPos: Vector3): boolean
    local data = playerCameraData[player.UserId]
    if not data or (tick() - data.timestamp) > 1 then return false end

    local playerPos = getPlayerPosition(player)
    if not playerPos then return false end

    local dirToEntity = (entityPos - playerPos).Unit
    local dot = dirToEntity:Dot(data.lookDirection)
    return dot > 0.5
end

local function isPlayerMoving(player: Player): boolean
    local character = player.Character
    if not character then return false end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    return hrp.AssemblyLinearVelocity.Magnitude > 1
end

local function checkKillRange(model: Model, player: Player, killRange: number): boolean
    local hrp = model.PrimaryPart
    if not hrp then return false end
    local playerPos = getPlayerPosition(player)
    if not playerPos then return false end
    return (hrp.Position - playerPos).Magnitude <= killRange
end

local function hasLineOfSight(model: Model, player: Player): boolean
    local hrp = model.PrimaryPart
    if not hrp then return false end
    local playerPos = getPlayerPosition(player)
    if not playerPos then return false end

    local direction = (playerPos - hrp.Position)
    local distance = direction.Magnitude
    if distance < 1 then return true end

    local rayResult = Workspace:Raycast(hrp.Position, direction.Unit * distance)
    return not rayResult or rayResult.Instance:IsDescendantOf(player.Character)
end

local function getDistanceToPlayer(model: Model, player: Player): number
    local hrp = model.PrimaryPart
    if not hrp then return math.huge end
    local playerPos = getPlayerPosition(player)
    if not playerPos then return math.huge end
    return (hrp.Position - playerPos).Magnitude
end

--------------------------------------------------------------------------------
-- Kill check loop (runs independently from behavior @ 0.1s)
--------------------------------------------------------------------------------

local function startKillCheckLoop(model: Model, player: Player, entityDef: any, session: any)
    task.spawn(function()
        while session.alive and model.Parent do
            if checkKillRange(model, player, entityDef.KillRange) then
                session.alive = false
                session.onKill(player)
                return
            end
            task.wait(0.1)
        end
    end)
end

--------------------------------------------------------------------------------
-- BEHAVIOR: Patrol — patrol with player-seeking bias
--------------------------------------------------------------------------------

local function behaviorPatrol(model: Model, player: Player, entityDef: any, origin: Vector3, session: any)
    while session.alive and model.Parent do
        local target

        -- Player-seeking bias: chance to pick player's location
        if math.random() < entityDef.PlayerSeekChance then
            local playerPos = getPlayerPosition(player)
            if playerPos then
                target = playerPos
            end
        end

        if not target then
            target = getRandomMazePosition(origin)
        end

        navigateTo(model, target, entityDef.Speed)

        -- If near player, pursue for PursuitDuration
        local dist = getDistanceToPlayer(model, player)
        if dist < entityDef.DetectionRange then
            local pursuitEnd = tick() + entityDef.PursuitDuration
            while session.alive and model.Parent and tick() < pursuitEnd do
                local playerPos = getPlayerPosition(player)
                if playerPos then
                    navigateTo(model, playerPos, entityDef.Speed * 1.1)
                end

                -- Stop pursuit if too far
                if getDistanceToPlayer(model, player) > entityDef.LoseInterestRange then
                    break
                end
                task.wait(0.2)
            end
        end

        task.wait(0.3)
    end
end

--------------------------------------------------------------------------------
-- BEHAVIOR: Stalk — move toward player when player moves, approach otherwise
--------------------------------------------------------------------------------

local function behaviorStalk(model: Model, player: Player, entityDef: any, origin: Vector3, session: any)
    while session.alive and model.Parent do
        local dist = getDistanceToPlayer(model, player)

        if dist < entityDef.DetectionRange then
            -- Active pursuit mode
            if isPlayerMoving(player) then
                local playerPos = getPlayerPosition(player)
                if playerPos then
                    navigateTo(model, playerPos, entityDef.Speed)
                end
            else
                -- Player stopped — slowly creep closer
                local playerPos = getPlayerPosition(player)
                if playerPos then
                    navigateTo(model, playerPos, entityDef.Speed * 0.4)
                end
            end
        else
            -- Wander toward player with bias
            if math.random() < entityDef.PlayerSeekChance then
                local playerPos = getPlayerPosition(player)
                if playerPos then
                    navigateTo(model, playerPos, entityDef.Speed * 0.7)
                end
            else
                local target = getRandomMazePosition(origin)
                navigateTo(model, target, entityDef.Speed * 0.6)
            end
        end

        task.wait(0.2)
    end
end

--------------------------------------------------------------------------------
-- BEHAVIOR: Chase — wander until LoS, then chase persistently
--------------------------------------------------------------------------------

local function behaviorChase(model: Model, player: Player, entityDef: any, origin: Vector3, session: any)
    local isChasing = false
    local lastKnownPos: Vector3? = nil
    local chaseLostTime = 0

    while session.alive and model.Parent do
        local playerPos = getPlayerPosition(player)
        local dist = getDistanceToPlayer(model, player)

        if dist < entityDef.DetectionRange and hasLineOfSight(model, player) then
            isChasing = true
            lastKnownPos = playerPos
            chaseLostTime = 0
        elseif isChasing then
            -- Lost sight — keep chasing last known position for PursuitDuration
            chaseLostTime += 0.3
            if chaseLostTime > entityDef.PursuitDuration or dist > entityDef.LoseInterestRange then
                isChasing = false
                lastKnownPos = nil
            end
        end

        if isChasing then
            local target = playerPos or lastKnownPos
            if target then
                navigateTo(model, target, entityDef.Speed)
            end
        else
            -- Wander with player-seeking bias
            if math.random() < entityDef.PlayerSeekChance then
                local pp = getPlayerPosition(player)
                if pp then
                    navigateTo(model, pp, entityDef.Speed * 0.8)
                end
            else
                local target = getRandomMazePosition(origin)
                navigateTo(model, target, entityDef.Speed)
            end
        end

        task.wait(0.3)
    end
end

--------------------------------------------------------------------------------
-- BEHAVIOR: Camera — SCP-173 style, now teleports when not watched
--------------------------------------------------------------------------------

local function behaviorCamera(model: Model, player: Player, entityDef: any, origin: Vector3, session: any)
    local teleportCooldown = 0

    while session.alive and model.Parent do
        local entityPos = model.PrimaryPart and model.PrimaryPart.Position

        if entityPos and not isInCameraView(player, entityPos) then
            -- NOT being watched — MOVE FAST toward player
            local playerPos = getPlayerPosition(player)
            if playerPos then
                local humanoid = model:FindFirstChildWhichIsA("Humanoid")
                if humanoid then
                    humanoid.WalkSpeed = entityDef.Speed * 1.3
                    humanoid:MoveTo(playerPos)
                end
            end

            -- Occasional teleport to nearby cell (terrifying)
            teleportCooldown += 0.15
            if teleportCooldown > 8 and math.random() < 0.15 then
                local pp = getPlayerPosition(player)
                if pp and model.PrimaryPart then
                    -- Teleport to a position near (but not on top of) the player
                    local offset = Vector3.new(
                        math.random(-3, 3) * MazeConfig.TileSize / 2,
                        0,
                        math.random(-3, 3) * MazeConfig.TileSize / 2
                    )
                    local teleportPos = pp + offset
                    model:SetPrimaryPartCFrame(CFrame.new(teleportPos.X, pp.Y, teleportPos.Z))
                    teleportCooldown = 0
                end
            end
        else
            -- Being watched — FREEZE
            local humanoid = model:FindFirstChildWhichIsA("Humanoid")
            if humanoid then
                humanoid:MoveTo(model.PrimaryPart.Position)
            end
        end

        task.wait(0.15)
    end
end

--------------------------------------------------------------------------------
-- BEHAVIOR: Erratic — unpredictable with player-seeking bias
--------------------------------------------------------------------------------

local function behaviorErratic(model: Model, player: Player, entityDef: any, origin: Vector3, session: any)
    while session.alive and model.Parent do
        local action = math.random()

        if action < entityDef.PlayerSeekChance then
            -- Seek player
            local playerPos = getPlayerPosition(player)
            if playerPos then
                navigateTo(model, playerPos, entityDef.Speed * (0.8 + math.random() * 0.6))
            end
        elseif action < 0.8 then
            -- Random wander
            local target = getRandomMazePosition(origin)
            navigateTo(model, target, entityDef.Speed * (0.5 + math.random() * 1))
        else
            -- Pause with chance of sudden rush
            task.wait(math.random() * 2 + 0.5)

            -- 50% chance of sudden sprint toward player
            if math.random() < 0.5 then
                local playerPos = getPlayerPosition(player)
                if playerPos then
                    navigateTo(model, playerPos, entityDef.Speed * 1.5)
                end
            end
        end

        task.wait(0.3)
    end
end

-- Behavior dispatcher
local BEHAVIORS = {
    Patrol  = behaviorPatrol,
    Stalk   = behaviorStalk,
    Chase   = behaviorChase,
    Camera  = behaviorCamera,
    Erratic = behaviorErratic,
}

--------------------------------------------------------------------------------
-- PUBLIC: Spawn an entity for a player's maze run
--------------------------------------------------------------------------------

function EntityManager.spawnEntity(player: Player, mazeFolder: Folder, origin: Vector3, onKillCallback: (Player) -> ())
    -- Pick a random entity type
    local entityId = EntityConfig.EntityIds[math.random(1, #EntityConfig.EntityIds)]
    local entityDef = EntityConfig.Entities[entityId]

    -- Spawn at a random position (not too close to start)
    local spawnPos = getRandomMazePosition(origin)
    local startPos = Vector3.new(
        origin.X + MazeConfig.TileSize / 2,
        origin.Y + 3,
        origin.Z + MazeConfig.TileSize / 2
    )

    local attempts = 0
    while (spawnPos - startPos).Magnitude < MazeConfig.TileSize * 3 and attempts < 20 do
        spawnPos = getRandomMazePosition(origin)
        attempts += 1
    end

    local spawnCFrame = CFrame.new(spawnPos)

    -- Create the entity model
    local model = createEntityModel(entityDef, spawnCFrame, mazeFolder)

    -- Session tracking
    local session = {
        model = model,
        alive = true,
        entityDef = entityDef,
        onKill = onKillCallback,
    }

    activeEntities[player.UserId] = session

    -- Start position broadcasting
    task.spawn(function()
        while session.alive and model.Parent do
            local hrp = model.PrimaryPart
            if hrp then
                Remotes.EntityPosition:FireClient(player, hrp.Position)
            end
            task.wait(EntityConfig.PositionUpdateRate)
        end
    end)

    -- Start fast kill check loop
    startKillCheckLoop(model, player, entityDef, session)

    -- Start AI behavior after spawn delay
    task.spawn(function()
        task.wait(EntityConfig.SpawnDelay)
        if not session.alive then return end

        local behaviorFn = BEHAVIORS[entityDef.BehaviorType]
        if behaviorFn then
            behaviorFn(model, player, entityDef, origin, session)
        else
            warn("[EntityManager] Unknown behavior: " .. entityDef.BehaviorType)
        end
    end)

    print("[EntityManager] Spawned " .. entityDef.Name .. " for " .. player.Name)
    return model, entityDef.Name
end

--------------------------------------------------------------------------------
-- PUBLIC: Cleanup entity for a player
--------------------------------------------------------------------------------

function EntityManager.cleanup(player: Player)
    local session = activeEntities[player.UserId]
    if session then
        session.alive = false
        if session.model and session.model.Parent then
            session.model:Destroy()
        end
        activeEntities[player.UserId] = nil
        print("[EntityManager] Cleaned up entity for " .. player.Name)
    end
end

--------------------------------------------------------------------------------
-- PUBLIC: Check if a player has an active entity
--------------------------------------------------------------------------------

function EntityManager.hasActiveEntity(player: Player): boolean
    return activeEntities[player.UserId] ~= nil
end

--------------------------------------------------------------------------------
-- Cleanup on player leave
--------------------------------------------------------------------------------

Players.PlayerRemoving:Connect(function(player)
    EntityManager.cleanup(player)
    playerCameraData[player.UserId] = nil
end)

print("[EntityManager] Initialized")

return EntityManager
