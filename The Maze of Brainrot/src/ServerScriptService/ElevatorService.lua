--[[
    ElevatorService.lua
    ===================
    Server Script — manages the Elevator Gateway for maze entry and exit.
    
    Integrated with:
        - MazeGenerator (procedural maze creation)
        - LootSpawner (populate maze with loot)
        - PlayerManager (flashlight equip, battery)
        - RemoteEvents
    
    Flow:
        1. Player triggers ElevatorDoor ProximityPrompt
        2. Client fires RequestMazeEntry
        3. Server generates maze, spawns loot, teleports player
        4. Server fires MazeEntryResult + EquipFlashlight
        5. Player finds exit elevator → teleport back to Hub, cleanup
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local MazeConfig = require(Modules.Data.MazeConfig)
local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))

-- Direct requires (load order handled by Init.server.lua bootstrap)
local MazeGenerator = require(ServerScriptService:WaitForChild("MazeGenerator"))
local LootSpawner = require(ServerScriptService:WaitForChild("LootSpawner"))
local PlayerManager = require(ServerScriptService:WaitForChild("PlayerManager"))
local EntityManager = require(ServerScriptService:WaitForChild("EntityManager"))
local DeathHandler = require(ServerScriptService:WaitForChild("DeathHandler"))

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local ELEVATOR_DOOR_NAME = "ElevatorDoor"
local ENTRY_COOLDOWN = 5 -- seconds
local playerCooldowns = {} -- { [UserId] = tick() }

-- Active maze sessions: { [UserId] = { folder, exitPart, grid, origin } }
local activeMazes = {}

--------------------------------------------------------------------------------
-- Placeholder Elevator Door (auto-created for testing)
--------------------------------------------------------------------------------

local function ensureElevatorDoor()
    if not Workspace:FindFirstChild(ELEVATOR_DOOR_NAME) then
        local door = Instance.new("Part")
        door.Name = ELEVATOR_DOOR_NAME
        door.Size = Vector3.new(8, 12, 1)
        door.Position = Vector3.new(0, 6, -20)
        door.Anchored = true
        door.CanCollide = false
        door.Transparency = 0.5
        door.BrickColor = BrickColor.new("Dark stone grey")
        door.Material = Enum.Material.Metal
        door.Parent = Workspace

        local prompt = Instance.new("ProximityPrompt")
        prompt.ObjectText = "Elevator"
        prompt.ActionText = "Call Elevator"
        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = 10
        prompt.Parent = door

        local billboard = Instance.new("BillboardGui")
        billboard.Size = UDim2.new(0, 200, 0, 50)
        billboard.StudsOffset = Vector3.new(0, 4, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = door

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = "🛗 ELEVATOR"
        label.TextColor3 = Color3.fromRGB(255, 215, 0)
        label.TextSize = 24
        label.Font = Enum.Font.GothamBold
        label.TextStrokeTransparency = 0.5
        label.Parent = billboard

        print("[ElevatorService] Created placeholder ElevatorDoor")
    end
end

--------------------------------------------------------------------------------
-- Teleport player to a CFrame
--------------------------------------------------------------------------------

local function teleportPlayer(player: Player, targetCFrame: CFrame): boolean
    local character = player.Character
    if not character then return false end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    hrp.CFrame = targetCFrame
    return true
end

--------------------------------------------------------------------------------
-- Generate maze + loot + teleport player
--------------------------------------------------------------------------------

local PartyService = require(ServerScriptService:WaitForChild("PartyService"))

--------------------------------------------------------------------------------
-- Generate maze + loot + teleport player(s)
--------------------------------------------------------------------------------

local function startMazeRun(player: Player)
    if not MazeGenerator or not LootSpawner then
        Remotes.MazeEntryResult:FireClient(player, false, "Server still loading...")
        return
    end

    -- Determine party context
    local members = {player}
    local partyData = PartyService.getPartyDataForClient(PartyService.getPlayerPartyId(player)) -- Need server API
    -- Wait, PartyService.getPartyMembers(player) is available
    local partyMembers = PartyService.getPartyMembers(player)
    if partyMembers and #partyMembers > 0 then
        members = partyMembers
    end
    
    -- Check if leader (if in party)
    -- Actually getPartyMembers returns {player} if solo, so logic holds.
    -- But we need to ensure unique session key. Use leader's UserId or PartyId.
    local leader = members[1] -- Assuming first is leader if from PartyService
    local sessionKey = leader.UserId -- Use Leader ID as session key for now

    -- Clean up any existing maze for this session
    if activeMazes[sessionKey] then
        MazeGenerator.destroy(activeMazes[sessionKey].folder)
        activeMazes[sessionKey] = nil
    end

    -- 1. Generate maze (pass first player for seed/difficulty scaling?)
    local folder, startCFrame, exitCFrame, grid, origin = MazeGenerator.generate(leader)

    -- 2. Spawn loot
    LootSpawner.spawnLoot(folder, grid, origin)

    -- 3. Store active maze session
    local exitPart = folder:FindFirstChild("MazeExit")
    activeMazes[sessionKey] = {
        folder = folder,
        exitPart = exitPart,
        grid = grid,
        origin = origin,
        players = members -- Track all players in this session
    }

    -- 4. Connect exit elevator prompt (triggers for ANY member)
    if exitPart then
        local exitPrompt = exitPart:FindFirstChildWhichIsA("ProximityPrompt")
        if exitPrompt then
            exitPrompt.Triggered:Connect(function(triggerPlayer)
                -- Verify player is part of this session
                local isMember = false
                for _, m in ipairs(members) do
                    if m == triggerPlayer then isMember = true break end
                end
                
                if isMember then
                    exitMazeRun(leader) -- Extract WHOLE party
                end
            end)
        end
    end

    -- 5. Teleport ALL players
    for _, member in ipairs(members) do
        local teleported = teleportPlayer(member, startCFrame)
        if teleported then
            Remotes.MazeEntryResult:FireClient(member, true, "Entering the Maze...")
            Remotes.EquipFlashlight:FireClient(member, true)
            if PlayerManager then
                PlayerManager.setBattery(member, 100)
                PlayerManager.setInMaze(member, true)
            end
        end
    end

    -- 6. Spawn entities (Scale count/difficulty?)
    if EntityManager and DeathHandler then
        -- Pass list of players to EntityManager?
        -- EntityManager.spawnEntity checks closest player usually.
        -- We'll just spawn one for now, or loop for #members.
        
        -- Scaling: Spawn 1 entity per player? Or just 1 aggressive one?
        -- Let's do 1 base + chance for extras.
        EntityManager.spawnEntity(leader, folder, origin, function(killedPlayer)
             DeathHandler.onEntityKill(killedPlayer)
        end)
        
        if #members > 1 then
            -- Spawn extra entity for easier pressure
             EntityManager.spawnEntity(members[2], folder, origin, function(killedPlayer)
                 DeathHandler.onEntityKill(killedPlayer)
            end)
        end
    end

    print("[ElevatorService] Party of " .. #members .. " started maze run (Leader: " .. leader.Name .. ")")
end

--------------------------------------------------------------------------------
-- Exit maze: teleport back to Hub, cleanup
--------------------------------------------------------------------------------

function exitMazeRun(playerOrLeader: Player)
    -- Find session. Iterate if we don't know the key.
    -- Better: we used Leader UserId as key.
    -- But player pressing button might not be leader.
    -- Reverse lookup?
    
    local sessionKey = nil
    local session = nil
    
    -- Try direct key
    if activeMazes[playerOrLeader.UserId] then
        sessionKey = playerOrLeader.UserId
        session = activeMazes[sessionKey]
    else
        -- Search
        for key, sess in pairs(activeMazes) do
            for _, m in ipairs(sess.players) do
                if m == playerOrLeader then
                    sessionKey = key
                    session = sess
                    break
                end
            end
            if session then break end
        end
    end

    if not session then return end

    local hubCFrame = CFrame.new(MazeConfig.HubSpawnPosition)

    -- Extract ALL players
    for _, member in ipairs(session.players) do
        teleportPlayer(member, hubCFrame)
        Remotes.EquipFlashlight:FireClient(member, false)
        Remotes.ReturnToHub:FireClient(member, "Extracted successfully!")
        
        if PlayerManager then
            PlayerManager.setInMaze(member, false)
        end
        
        -- Create individual stats?
    end

    -- Cleanup
    if EntityManager then
        EntityManager.cleanup(session.players[1]) -- Cleans up entities targeting this group
        -- Wait, EntityManager might need update to handle group cleanup
    end

    MazeGenerator.destroy(session.folder)
    activeMazes[sessionKey] = nil

    print("[ElevatorService] Session " .. sessionKey .. " ended")
end

--------------------------------------------------------------------------------
-- Handle Maze Entry Requests
--------------------------------------------------------------------------------

Remotes.RequestMazeEntry.OnServerEvent:Connect(function(player: Player)
    -- Cooldown check
    local now = tick()
    local lastEntry = playerCooldowns[player.UserId]
    if lastEntry and (now - lastEntry) < ENTRY_COOLDOWN then
        Remotes.MazeEntryResult:FireClient(player, false, "Please wait before entering again.")
        return
    end

    -- Party Check: Only Leader can start
    local partyMembers = PartyService.getPartyMembers(player)
    if partyMembers and #partyMembers > 1 then
        if partyMembers[1] ~= player then
            Remotes.MazeEntryResult:FireClient(player, false, "Only the Party Leader can start the run!")
            return
        end
    end

    playerCooldowns[player.UserId] = now
    startMazeRun(player)
end)

--------------------------------------------------------------------------------
-- Public API for other scripts (e.g. DeathHandler)
--------------------------------------------------------------------------------

local ElevatorService = {}

function ElevatorService.forceExitMaze(player: Player)
    exitMazeRun(player)
end

function ElevatorService.getActiveSession(player: Player)
    return activeMazes[player.UserId]
end

function ElevatorService.isInMaze(player: Player): boolean
    return activeMazes[player.UserId] ~= nil
end

--------------------------------------------------------------------------------
-- Cleanup on player leave
--------------------------------------------------------------------------------

Players.PlayerRemoving:Connect(function(player: Player)
    playerCooldowns[player.UserId] = nil

    -- Cleanup active maze
    local session = activeMazes[player.UserId]
    if session then
        if PlayerManager then
            PlayerManager.setInMaze(player, false)
        end
        MazeGenerator.destroy(session.folder)
        activeMazes[player.UserId] = nil
    end
end)

--------------------------------------------------------------------------------
-- Initialize
--------------------------------------------------------------------------------

ensureElevatorDoor()
print("[ElevatorService] Elevator service initialized (Phase 3)")

return ElevatorService
