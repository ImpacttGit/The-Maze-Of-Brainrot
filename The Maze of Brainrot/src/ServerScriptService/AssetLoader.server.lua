--[[
    AssetLoader.server.lua
    ======================
    Server Script — Preloads 3D assets on server startup.
    
    Ensures that required models for Loot and Entities are present in ServerStorage.
    If they are missing, attempts to load them via InsertService and parent them
    correctly.
    
    Dependencies:
        - ItemDatabase (for Loot IDs)
]]

local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ItemDatabase = require(Modules.Data.ItemDatabase)

-- Ensure folders exist
local LootModels = ServerStorage:FindFirstChild("LootModels") or Instance.new("Folder")
LootModels.Name = "LootModels"
LootModels.Parent = ServerStorage

local EntityModels = ServerStorage:FindFirstChild("Entities") or Instance.new("Folder")
EntityModels.Name = "Entities"
EntityModels.Parent = ServerStorage

--------------------------------------------------------------------------------
-- Helper: Load Asset safely
--------------------------------------------------------------------------------

local function loadAsset(assetId, targetName, targetParent)
    if targetParent:FindFirstChild(targetName) then
        return -- Already exists
    end

    if not assetId or assetId == "" then
        return -- No ID provided
    end

    local success, model = pcall(function()
        return InsertService:LoadAsset(tonumber(assetId))
    end)

    if success and model then
        -- InsertService loads a Model containing the asset. Unwrap it.
        local asset = model:GetChildren()[1]
        if asset then
            asset.Name = targetName
            asset.Parent = targetParent
            
            -- If it's a model, ensure PrimaryPart exists for easier positioning
            if asset:IsA("Model") and not asset.PrimaryPart then
                asset.PrimaryPart = asset:FindFirstChildWhichIsA("BasePart")
            end
            
            -- If it's a MeshPart/Part, anchor it by default for storage
            if asset:IsA("BasePart") then
                asset.Anchored = true
                asset.CanCollide = false
            elseif asset:IsA("Model") then
                for _, desc in ipairs(asset:GetDescendants()) do
                    if desc:IsA("BasePart") then
                        desc.Anchored = true
                        desc.CanCollide = false
                    end
                end
            end
            
            print("[AssetLoader] Loaded " .. targetName .. " (" .. assetId .. ")")
        else
            warn("[AssetLoader] Asset " .. assetId .. " loaded empty model")
        end
        model:Destroy() -- Destroy container
    else
        warn("[AssetLoader] Failed to load asset " .. assetId .. " for " .. targetName .. ": " .. tostring(model))
    end
end

--------------------------------------------------------------------------------
-- 1. Load Loot Items from Database
--------------------------------------------------------------------------------

print("[AssetLoader] Checking Loot Items...")

-- We iterate the flattened Items table
for itemId, itemData in pairs(ItemDatabase.Items) do
    if itemData.AssetId then
        loadAsset(itemData.AssetId, itemId, LootModels)
    end
end

--------------------------------------------------------------------------------
-- 2. Load Environment Assets (Optional, usually handled by specific methods)
--------------------------------------------------------------------------------

-- Just in case we want to store them here too, though LobbyBuilder might load directly.
-- For now, LobbyBuilder handles its own Environment assets.

print("[AssetLoader] Asset loading complete.")
