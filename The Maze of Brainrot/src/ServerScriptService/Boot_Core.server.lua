--[[
    Boot_Core.server.lua
    ====================
    Auto-running Script — bootstraps core systems.
    
    Loads PlayerManager, builds the lobby, and starts the game pass service.
]]

local ServerScriptService = game:GetService("ServerScriptService")

print("[Boot_Core] Starting core systems...")

local PlayerManager = require(ServerScriptService:WaitForChild("PlayerManager"))
print("[Boot_Core] PlayerManager loaded ✓")

local LobbyBuilder = require(ServerScriptService:WaitForChild("LobbyBuilder"))
LobbyBuilder.build()
print("[Boot_Core] Lobby built ✓")

local GamePassService = require(ServerScriptService:WaitForChild("GamePassService"))
print("[Boot_Core] GamePassService loaded ✓")

local FollowerService = require(ServerScriptService:WaitForChild("FollowerService"))
print("[Boot_Core] FollowerService loaded ✓")

print("[Boot_Core] All core systems ready ✓")
