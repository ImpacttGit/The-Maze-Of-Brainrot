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

local function startMazeRun(player: Player)
    if not MazeGenerator or not LootSpawner then
        Remotes.MazeEntryResult:FireClient(player, false, "Server still loading...")
        return
    end

    -- Clean up any existing maze for this player
    if activeMazes[player.UserId] then
        MazeGenerator.destroy(activeMazes[player.UserId].folder)
        activeMazes[player.UserId] = nil
    end

    -- 1. Generate maze
    local folder, startCFrame, exitCFrame, grid, origin = MazeGenerator.generate(player)

    -- 2. Spawn loot in the maze
    local items, lootParts = LootSpawner.spawnLoot(folder, grid, origin)

    -- 3. Store active maze session
    local exitPart = folder:FindFirstChild("MazeExit")
    activeMazes[player.UserId] = {
        folder = folder,
        exitPart = exitPart,
        grid = grid,
        origin = origin,
    }

    -- 4. Connect exit elevator prompt
    if exitPart then
        local exitPrompt = exitPart:FindFirstChildWhichIsA("ProximityPrompt")
        if exitPrompt then
            exitPrompt.Triggered:Connect(function(triggerPlayer)
                if triggerPlayer == player then
                    exitMazeRun(player)
                end
            end)
        end
    end

    -- 5. Teleport player to maze start
    local teleported = teleportPlayer(player, startCFrame)
    if not teleported then
        MazeGenerator.destroy(folder)
        activeMazes[player.UserId] = nil
        Remotes.MazeEntryResult:FireClient(player, false, "Failed to teleport")
        return
    end

    -- 6. Fire success to client
    Remotes.MazeEntryResult:FireClient(player, true, "Entering the Maze...")

    -- 7. Equip flashlight on client
    Remotes.EquipFlashlight:FireClient(player, true)

    -- 8. Set battery to 100% and activate maze backpack limit
    if PlayerManager then
        PlayerManager.setBattery(player, 100)
        PlayerManager.setInMaze(player, true)
    end

    -- 9. Spawn entity after delay
    if EntityManager and DeathHandler then
        EntityManager.spawnEntity(player, folder, origin, function(killedPlayer)
            DeathHandler.onEntityKill(killedPlayer)
        end)
    end

    print("[ElevatorService] " .. player.Name .. " started maze run")
end

--------------------------------------------------------------------------------
-- Exit maze: teleport back to Hub, cleanup
--------------------------------------------------------------------------------

function exitMazeRun(player: Player)
    local session = activeMazes[player.UserId]
    if not session then return end

    -- Teleport back to Hub
    local hubCFrame = CFrame.new(MazeConfig.HubSpawnPosition)
    teleportPlayer(player, hubCFrame)

    -- Deactivate flashlight
    Remotes.EquipFlashlight:FireClient(player, false)

    -- Cleanup entity
    if EntityManager then
        EntityManager.cleanup(player)
    end

    -- Cleanup maze
    MazeGenerator.destroy(session.folder)
    activeMazes[player.UserId] = nil

    -- Deactivate backpack limit
    if PlayerManager then
        PlayerManager.setInMaze(player, false)
    end

    -- Notify client
    Remotes.ReturnToHub:FireClient(player, "Extracted successfully!")

    print("[ElevatorService] " .. player.Name .. " extracted from maze")
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
