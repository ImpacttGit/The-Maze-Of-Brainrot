--[[
    PartyService.lua
    ================
    Server Service — Manages multiplayer parties.
    
    Structure:
    - Parties = { [PartyId] = { Leader = Player, Members = {Player} } }
    - PlayerParty = { [Player] = PartyId }
    
    Features:
    - Create Party
    - Invite Player
    - Join Party (via invite)
    - Leave Party
    - Kick Player
    - Party Chat (optional, maybe just Roblox chat channel)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))

local PartyService = {}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local Parties = {}      -- [PartyId] = { Leader = player, Members = {player}, Invites = {userId=true} }
local PlayerParty = {}  -- [Player] = PartyId

local MAX_PARTY_SIZE = 4

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

local function generatePartyId()
    return HttpService:GenerateGUID(false)
end

local function getPartyDataForClient(partyId)
    local party = Parties[partyId]
    if not party then return nil end
    
    local membersData = {}
    for _, member in ipairs(party.Members) do
        table.insert(membersData, {
            UserId = member.UserId,
            Name = member.Name,
            IsLeader = (member == party.Leader)
        })
    end
    
    return {
        PartyId = partyId,
        Members = membersData,
        IsLeader = (Players.LocalPlayer == party.Leader) -- Wait, this is server logic
    }
end

local function broadcastPartyUpdate(partyId)
    local party = Parties[partyId]
    if not party then return end
    
    local data = {
        PartyId = partyId,
        Members = {},
        LeaderId = party.Leader.UserId
    }
    
    for _, member in ipairs(party.Members) do
        table.insert(data.Members, {
            UserId = member.UserId,
            Name = member.Name,
            DisplayName = member.DisplayName
        })
    end
    
    for _, member in ipairs(party.Members) do
        Remotes.PartyUpdate:FireClient(member, data)
    end
end

--------------------------------------------------------------------------------
-- Core Logic
--------------------------------------------------------------------------------

function PartyService.createParty(leader)
    if PlayerParty[leader] then return end -- Already in party
    
    local partyId = generatePartyId()
    local party = {
        Leader = leader,
        Members = {leader},
        Invites = {}
    }
    
    Parties[partyId] = party
    PlayerParty[leader] = partyId
    
    broadcastPartyUpdate(partyId)
    print("[PartyService] Party created by " .. leader.Name)
end

function PartyService.leaveParty(player)
    local partyId = PlayerParty[player]
    if not partyId then return end
    
    local party = Parties[partyId]
    if not party then return end
    
    -- Remove player
    for i, member in ipairs(party.Members) do
        if member == player then
            table.remove(party.Members, i)
            break
        end
    end
    PlayerParty[player] = nil
    
    -- Notify player they left
    Remotes.PartyUpdate:FireClient(player, nil) -- nil means "no party"
    
    -- Perform leadership transfer or disband
    if #party.Members == 0 then
        -- Disband
        Parties[partyId] = nil
        print("[PartyService] Party " .. partyId .. " disbanded")
    else
        if party.Leader == player then
            -- Transfer leadership to first remaining member
            party.Leader = party.Members[1]
            print("[PartyService] Leadership transferred to " .. party.Leader.Name)
        end
        broadcastPartyUpdate(partyId)
    end
end

function PartyService.invitePlayer(sender, targetPlayer)
    local partyId = PlayerParty[sender]
    if not partyId then
        -- Auto-create party if not in one?
        PartyService.createParty(sender)
        partyId = PlayerParty[sender]
    end
    
    local party = Parties[partyId]
    
    -- Validation
    if party.Leader ~= sender then return end -- Only leader invites
    if #party.Members >= MAX_PARTY_SIZE then return end
    if PlayerParty[targetPlayer] then return end -- Target already busy
    
    -- Add invite
    party.Invites[targetPlayer.UserId] = true
    
    -- Send invite to target
    Remotes.PartyInviteReceived:FireClient(targetPlayer, {
        PartyId = partyId,
        LeaderName = sender.Name
    })
end

function PartyService.joinParty(player, partyId)
    local party = Parties[partyId]
    if not party then return end
    
    -- Validate invite
    if not party.Invites[player.UserId] then return end
    if #party.Members >= MAX_PARTY_SIZE then return end
    if PlayerParty[player] then return end -- Already in party
    
    -- Join
    table.insert(party.Members, player)
    PlayerParty[player] = partyId
    party.Invites[player.UserId] = nil -- Consume invite
    
    broadcastPartyUpdate(partyId)
end

function PartyService.kickPlayer(leader, targetPlayer)
    local partyId = PlayerParty[leader]
    if not partyId then return end
    
    local party = Parties[partyId]
    if party.Leader ~= leader then return end
    if targetPlayer == leader then return end
    
    -- Verify target is in party
    local inParty = false
    for _, member in ipairs(party.Members) do
        if member == targetPlayer then
            inParty = true
            break
        end
    end
    
    if inParty then
        PartyService.leaveParty(targetPlayer) -- Re-use leave logic
        -- Maybe invoke different message? "You were kicked"
    end
end

function PartyService.getPartyMembers(player)
    local partyId = PlayerParty[player]
    if not partyId then return {player} end -- Solo "party"
    return Parties[partyId].Members
end

--------------------------------------------------------------------------------
-- Remote Handlers
--------------------------------------------------------------------------------

Remotes.CreateParty.OnServerEvent:Connect(function(player)
    PartyService.createParty(player)
end)

Remotes.LeaveParty.OnServerEvent:Connect(function(player)
    PartyService.leaveParty(player)
end)

Remotes.InvitePlayer.OnServerEvent:Connect(function(sender, targetName)
    -- Find target player by name (simple lookup)
    local target = Players:FindFirstChild(targetName)
    if target then
        PartyService.invitePlayer(sender, target)
    end
end)

Remotes.KickPlayer.OnServerEvent:Connect(function(sender, targetUserId)
    local target = Players:GetPlayerByUserId(targetUserId)
    if target then
        PartyService.kickPlayer(sender, target)
    end
end)

Remotes.AcceptInvite.OnServerEvent:Connect(function(player, partyId)
    PartyService.joinParty(player, partyId)
end)

--------------------------------------------------------------------------------
-- Cleanup on Leave
--------------------------------------------------------------------------------

Players.PlayerRemoving:Connect(function(player)
    PartyService.leaveParty(player)
end)

print("[PartyService] Initialized")

return PartyService
