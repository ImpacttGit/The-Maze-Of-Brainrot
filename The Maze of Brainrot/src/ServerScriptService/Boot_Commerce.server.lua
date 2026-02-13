--[[
    Boot_Commerce.server.lua
    ========================
    Auto-running Script — bootstraps the commerce systems.
    
    Requires MerchantService, TradeUpHandler, and CrateService.
    Each of these internally require()s PlayerManager.
]]

local ServerScriptService = game:GetService("ServerScriptService")

print("[Boot_Commerce] Starting commerce systems...")

local MerchantService = require(ServerScriptService:WaitForChild("MerchantService"))
print("[Boot_Commerce] MerchantService loaded ✓")

local TradeUpHandler = require(ServerScriptService:WaitForChild("TradeUpHandler"))
print("[Boot_Commerce] TradeUpHandler loaded ✓")

local CrateService = require(ServerScriptService:WaitForChild("CrateService"))
print("[Boot_Commerce] CrateService loaded ✓")

print("[Boot_Commerce] All commerce systems loaded ✓")
