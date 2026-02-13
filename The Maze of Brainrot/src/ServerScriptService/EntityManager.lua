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
-- INTERNAL: Player Targeting Logic (Multiplayer Support)
--------------------------------------------------------------------------------

local function getPlayerPosition(player: Player): Vector3?
    if not player or not player.Character then return nil end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position or nil
end

-- Find closest valid target from a list of players
local function getClosestPlayer(model: Model, players: {Player}): (Player?, number)
    local hrp = model.PrimaryPart
    if not hrp then return nil, math.huge end
    
    local closestPlayer = nil
    local minDistance = math.huge
    
    for _, player in ipairs(players) do
        local pos = getPlayerPosition(player)
        if pos then
            local dist = (hrp.Position - pos).Magnitude
            if dist < minDistance then
                minDistance = dist
                closestPlayer = player
            end
        end
    end
    
    return closestPlayer, minDistance
end

local function isAnyPlayerLooking(entityPos: Vector3, players: {Player}): boolean
    for _, player in ipairs(players) do
        local data = playerCameraData[player.UserId]
        if data and (tick() - data.timestamp) < 1 then
            local playerPos = getPlayerPosition(player)
            if playerPos then
                local dirToEntity = (entityPos - playerPos).Unit
                local dot = dirToEntity:Dot(data.lookDirection)
                if dot > 0.5 then
                    return true -- At least one player is looking
                end
            end
        end
    end
    return false
end

--------------------------------------------------------------------------------
-- Kill check loop (runs independently from behavior @ 0.1s)
--------------------------------------------------------------------------------

local function startKillCheckLoop(model: Model, players: {Player}, entityDef: any, session: any)
    task.spawn(function()
        while session.alive and model.Parent do
            local hrp = model.PrimaryPart
            if not hrp then break end
            
            for _, player in ipairs(players) do
                local playerPos = getPlayerPosition(player)
                if playerPos and (hrp.Position - playerPos).Magnitude <= entityDef.KillRange then
                    -- Kill this player
                    session.onKill(player)
                    -- Don't stop session unless everyone is dead? 
                    -- For now, kill stops that player. 
                    -- We rely on DeathHandler to handle the logic.
                    -- But we should probably debounce or cooldown logic here?
                    -- Usually DeathHandler respawns them outside or shows screen.
                end
            end
            task.wait(0.1)
        end
    end)
end

--------------------------------------------------------------------------------
-- BEHAVIORS
--------------------------------------------------------------------------------

local function behaviorPatrol(model: Model, players: {Player}, entityDef: any, origin: Vector3, session: any)
    while session.alive and model.Parent do
        local targetPos
        local closest, dist = getClosestPlayer(model, players)

        -- Player-seeking bias
        if closest and math.random() < entityDef.PlayerSeekChance then
            targetPos = getPlayerPosition(closest)
        end
        if not targetPos then
            targetPos = getRandomMazePosition(origin)
        end

        navigateTo(model, targetPos, entityDef.Speed)

        -- Pursuit
        if closest and dist < entityDef.DetectionRange then
            local pursuitEnd = tick() + entityDef.PursuitDuration
            while session.alive and model.Parent and tick() < pursuitEnd do
                -- Re-evaluate closest player constantly
                local newClosest, newDist = getClosestPlayer(model, players)
                if newClosest then
                    local pPos = getPlayerPosition(newClosest)
                    if pPos then
                        navigateTo(model, pPos, entityDef.Speed * 1.1)
                    end
                    if newDist > entityDef.LoseInterestRange then break end
                else
                    break -- No players found
                end
                task.wait(0.2)
            end
        end
        task.wait(0.3)
    end
end

local function behaviorStalk(model: Model, players: {Player}, entityDef: any, origin: Vector3, session: any)
    while session.alive and model.Parent do
        local closest, dist = getClosestPlayer(model, players)
        
        if closest and dist < entityDef.DetectionRange then
             -- Active pursuit
             local pPos = getPlayerPosition(closest)
             if pPos then
                 -- If moving, chase fast. If stopped, creep.
                 local isMoving = closest.Character and closest.Character.HumanoidRootPart.AssemblyLinearVelocity.Magnitude > 1
                 if isMoving then
                     navigateTo(model, pPos, entityDef.Speed)
                 else
                     navigateTo(model, pPos, entityDef.Speed * 0.4)
                 end
             end
        else
            -- Wander
            if closest and math.random() < entityDef.PlayerSeekChance then
                 local pPos = getPlayerPosition(closest)
                 if pPos then navigateTo(model, pPos, entityDef.Speed * 0.7) end
            else
                local target = getRandomMazePosition(origin)
                navigateTo(model, target, entityDef.Speed * 0.6)
            end
        end
        task.wait(0.2)
    end
end

local function behaviorChase(model: Model, players: {Player}, entityDef: any, origin: Vector3, session: any)
    local isChasing = false
    local lastKnownPos = nil
    local chaseLostTime = 0
    
    while session.alive and model.Parent do
        local closest, dist = getClosestPlayer(model, players)
        local canSee = false
        if closest then
            canSee = hasLineOfSight(model, closest)
        end

        if closest and dist < entityDef.DetectionRange and canSee then
            isChasing = true
            lastKnownPos = getPlayerPosition(closest)
            chaseLostTime = 0
        elseif isChasing then
            chaseLostTime += 0.3
            if chaseLostTime > entityDef.PursuitDuration or (closest and dist > entityDef.LoseInterestRange) then
                isChasing = false
                lastKnownPos = nil
            end
        end

        if isChasing then
            local target = (closest and getPlayerPosition(closest)) or lastKnownPos
            if target then
                navigateTo(model, target, entityDef.Speed)
            end
        else
            -- Wander
             if closest and math.random() < entityDef.PlayerSeekChance then
                local pPos = getPlayerPosition(closest)
                if pPos then navigateTo(model, pPos, entityDef.Speed * 0.8) end
             else
                local target = getRandomMazePosition(origin)
                navigateTo(model, target, entityDef.Speed)
             end
        end
        task.wait(0.3)
    end
end

local function behaviorCamera(model: Model, players: {Player}, entityDef: any, origin: Vector3, session: any)
    local teleportCooldown = 0
    while session.alive and model.Parent do
        local entityPos = model.PrimaryPart and model.PrimaryPart.Position
        
        if entityPos and not isAnyPlayerLooking(entityPos, players) then
             -- Not watched - move fast to closest
             local closest, dist = getClosestPlayer(model, players)
             if closest then
                 local pPos = getPlayerPosition(closest)
                 if pPos then
                     local humanoid = model:FindFirstChildWhichIsA("Humanoid")
                     if humanoid then
                         humanoid.WalkSpeed = entityDef.Speed * 1.3
                         humanoid:MoveTo(pPos)
                     end
                 end
                 
                 -- Teleport logic
                 teleportCooldown += 0.15
                 if teleportCooldown > 8 and math.random() < 0.15 then
                     local offset = Vector3.new(math.random(-3,3)*MazeConfig.TileSize/2, 0, math.random(-3,3)*MazeConfig.TileSize/2)
                     local tpPos = pPos + offset
                     model:SetPrimaryPartCFrame(CFrame.new(tpPos.X, pPos.Y, tpPos.Z))
                     teleportCooldown = 0
                 end
             end
        else
            -- Watched - freeze
            local humanoid = model:FindFirstChildWhichIsA("Humanoid")
            if humanoid and model.PrimaryPart then
                humanoid:MoveTo(model.PrimaryPart.Position)
            end
        end
        task.wait(0.15)
    end
end

local function behaviorErratic(model: Model, players: {Player}, entityDef: any, origin: Vector3, session: any)
    while session.alive and model.Parent do
        local closest, dist = getClosestPlayer(model, players)
        local action = math.random()
        
        if closest and action < entityDef.PlayerSeekChance then
            local pPos = getPlayerPosition(closest)
            if pPos then navigateTo(model, pPos, entityDef.Speed * (0.8 + math.random()*0.6)) end
        elseif action < 0.8 then
            local target = getRandomMazePosition(origin)
            navigateTo(model, target, entityDef.Speed * (0.5 + math.random()))
        else
            task.wait(math.random()*2 + 0.5)
            if closest and math.random() < 0.5 then
                local pPos = getPlayerPosition(closest)
                 if pPos then navigateTo(model, pPos, entityDef.Speed * 1.5) end
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
-- Modified: targetPlayers is now a LIST {Player}
--------------------------------------------------------------------------------

function EntityManager.spawnEntity(targetPlayers: {Player}, mazeFolder: Folder, origin: Vector3, onKillCallback: (Player) -> ())
    -- Validate players
    if type(targetPlayers) ~= "table" then
        -- Backwards compatibility or error fix: if passed single player, wrap it
        targetPlayers = {targetPlayers}
    end
    
    local mainPlayer = targetPlayers[1] -- Should prevent nil key
    if not mainPlayer then return end

    -- Pick a random entity type
    local entityId = EntityConfig.EntityIds[math.random(1, #EntityConfig.EntityIds)]
    local entityDef = EntityConfig.Entities[entityId]

    -- Spawn at a random position (not too close to start)
    local spawnPos = getRandomMazePosition(origin)
    local spawnCFrame = CFrame.new(spawnPos)

    -- Create the entity model
    local model = createEntityModel(entityDef, spawnCFrame, mazeFolder)

    -- Session tracking
    local session = {
        model = model,
        alive = true,
        entityDef = entityDef,
        onKill = onKillCallback,
        players = targetPlayers -- Keep reference for behavior
    }

    -- Store active entity session (Keyed by Leader ID for now, or we can use a generated ID)
    -- But ElevatorService manages cleanup.
    -- ElevatorService calls EntityManager.cleanup(player)
    -- We need to map *each* player to this session? Or just the leader?
    -- If we key by leader, cleanup via other players might fail.
    -- Let's map activeEntities[player.UserId] = session for ALL players in list.
    for _, p in ipairs(targetPlayers) do
        activeEntities[p.UserId] = session
    end

    -- Start position broadcasting to ALL targets
    task.spawn(function()
        while session.alive and model.Parent do
            local hrp = model.PrimaryPart
            if hrp then
                for _, p in ipairs(targetPlayers) do
                    Remotes.EntityPosition:FireClient(p, hrp.Position)
                end
            end
            task.wait(EntityConfig.PositionUpdateRate)
        end
    end)

    -- Start fast kill check loop
    startKillCheckLoop(model, targetPlayers, entityDef, session)

    -- Start AI behavior after spawn delay
    task.spawn(function()
        task.wait(EntityConfig.SpawnDelay)
        if not session.alive then return end

        local behaviorFn = BEHAVIORS[entityDef.BehaviorType]
        if behaviorFn then
            behaviorFn(model, targetPlayers, entityDef, origin, session)
        else
            warn("[EntityManager] Unknown behavior: " .. entityDef.BehaviorType)
        end
    end)

    print("[EntityManager] Spawned " .. entityDef.Name .. " targeting " .. #targetPlayers .. " players")
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
        -- Remove reference for this player
        activeEntities[player.UserId] = nil
        
        -- Also clear for other players in the same session?
        -- Yes, if session is shared, we should clear it for everyone to avoid leaks/errors.
        if session.players then
            for _, p in ipairs(session.players) do
                 activeEntities[p.UserId] = nil
            end
        end
        
        print("[EntityManager] Cleaned up entity session")
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
