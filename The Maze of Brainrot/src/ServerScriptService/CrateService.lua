--[[
    CrateService.lua
    ================
    Server Script — handles crate purchases and item reveal.
    
    Supports purchase via Fragments or Robux (DeveloperProducts).
    Rolls items using weighted odds from CrateConfig.
    
    Dependencies:
        - CrateConfig
        - LootService
        - PlayerManager
        - MarketplaceService
        - RemoteEvents
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local CrateConfig = require(Modules.Data.CrateConfig)
local LootService = require(Modules.Services.LootService)
local Remotes = require(ReplicatedStorage:WaitForChild("RemoteEvents"))

local PlayerManager = require(ServerScriptService:WaitForChild("PlayerManager"))

--------------------------------------------------------------------------------
-- INTERNAL: Roll a rarity from a crate's weighted odds
--------------------------------------------------------------------------------

local function rollCrateRarity(crateDef: any): string
    local totalWeight = 0
    for _, odd in ipairs(crateDef.Odds) do
        totalWeight += odd.Weight
    end

    local roll = math.random() * totalWeight
    local cumulative = 0

    for _, odd in ipairs(crateDef.Odds) do
        cumulative += odd.Weight
        if roll <= cumulative then
            return odd.Rarity
        end
    end

    return "Common" -- Fallback
end

--------------------------------------------------------------------------------
-- Pending Robux purchases (track which crate the player is buying)
--------------------------------------------------------------------------------

local pendingPurchases = {} -- { [UserId] = crateId }

--------------------------------------------------------------------------------
-- Handle crate purchase request
-- Client sends: { crateId = string, paymentType = "Fragments" | "Robux" }
--------------------------------------------------------------------------------

Remotes.RequestCratePurchase.OnServerEvent:Connect(function(player: Player, purchaseData: any)
    if not PlayerManager then return end

    if typeof(purchaseData) ~= "table" then
        Remotes.CrateResult:FireClient(player, false, nil, "Invalid request")
        return
    end

    local crateId = purchaseData.crateId
    local paymentType = purchaseData.paymentType

    -- Validate crate exists
    local crateDef = CrateConfig.Crates[crateId]
    if not crateDef then
        Remotes.CrateResult:FireClient(player, false, nil, "Unknown crate: " .. tostring(crateId))
        return
    end

    -- Handle payment
    if paymentType == "Fragments" then
        -- Check if this crate can be bought with fragments
        if not crateDef.CanBuyWithFragments then
            Remotes.CrateResult:FireClient(player, false, nil, "This crate is Robux only!")
            return
        end

        -- Check and spend fragments
        local spent = PlayerManager.spendFragments(player, crateDef.FragmentPrice)
        if not spent then
            Remotes.CrateResult:FireClient(player, false, nil,
                "Not enough fragments! Need " .. crateDef.FragmentPrice)
            return
        end

        -- Payment successful — roll and give item
        giveItem(player, crateDef)

    elseif paymentType == "Robux" then
        -- Store pending purchase and prompt Robux payment
        if crateDef.ProductId and crateDef.ProductId > 0 then
            pendingPurchases[player.UserId] = crateId
            MarketplaceService:PromptProductPurchase(player, crateDef.ProductId)
        else
            -- No real product ID set — for testing, just give the item
            warn("[CrateService] No ProductId set for " .. crateId .. " — giving item for free (testing)")
            giveItem(player, crateDef)
        end
    else
        Remotes.CrateResult:FireClient(player, false, nil, "Invalid payment type")
    end
end)

--------------------------------------------------------------------------------
-- INTERNAL: Roll item and add to inventory
--------------------------------------------------------------------------------

function giveItem(player: Player, crateDef: any)
    -- Roll rarity
    local rarity = rollCrateRarity(crateDef)

    -- Generate the item
    local item = LootService.generateItem(rarity)

    -- Add to inventory
    local added = PlayerManager.addItem(player, item)
    if not added then
        -- Inventory full — refund fragments if applicable
        -- (For simplicity, just notify the player)
        Remotes.CrateResult:FireClient(player, false, nil, "Inventory full! Cannot open crate.")
        return
    end

    -- Fire result to client for reveal animation
    Remotes.CrateResult:FireClient(player, true, {
        ItemId = item.ItemId,
        DisplayName = item.DisplayName,
        Rarity = item.Rarity,
        FragmentValue = item.FragmentValue,
        IsFollower = item.IsFollower,
        CrateId = crateDef.CrateId,
    }, "Crate opened!")

    print("[CrateService] " .. player.Name .. " opened " .. crateDef.Name ..
        " → " .. item.DisplayName .. " (" .. item.Rarity .. ")")
end

--------------------------------------------------------------------------------
-- Handle Robux purchase receipts (DeveloperProduct)
--------------------------------------------------------------------------------

MarketplaceService.ProcessReceipt = function(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local crateId = pendingPurchases[player.UserId]
    if not crateId then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local crateDef = CrateConfig.Crates[crateId]
    if not crateDef then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    -- Verify the product ID matches
    if receiptInfo.ProductId ~= crateDef.ProductId then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    -- Give the item
    pendingPurchases[player.UserId] = nil
    giveItem(player, crateDef)

    return Enum.ProductPurchaseDecision.PurchaseGranted
end

--------------------------------------------------------------------------------
-- Cleanup on player leave
--------------------------------------------------------------------------------

Players.PlayerRemoving:Connect(function(player)
    pendingPurchases[player.UserId] = nil
end)

print("[CrateService] Initialized")

local CrateService = {}
return CrateService
