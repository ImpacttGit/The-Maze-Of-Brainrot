--[[
    TradeUpService.lua
    ==================
    Implements the Trade-Up Machine logic for The Maze of Brainrot.
    
    Rules:
        - Requires exactly 5 items with the SAME ItemId
        - The source rarity must allow trading up (CanTradeUpFrom = true)
        - The target rarity must allow being traded up to (CanTradeUpTo = true)
        - Epic → Legendary trade-ups are BLOCKED
        - Produces 1 random item of the next rarity tier
    
    Dependencies:
        - RarityConfig
        - ItemDatabase
        - LootService (for generating the result item)
        - InventoryService (for removing/adding items)
]]

local RarityConfig = require(script.Parent.Parent.Data.RarityConfig)
local ItemDatabase = require(script.Parent.Parent.Data.ItemDatabase)

local TradeUpService = {}

-- Number of identical items required for a trade-up
TradeUpService.REQUIRED_COUNT = 5

--------------------------------------------------------------------------------
-- Validate whether a set of items can be traded up
-- @param items ({ ItemInstance }) — Array of item instances to fuse
-- @return boolean — Whether the trade-up is valid
-- @return string? — Error message if invalid
--------------------------------------------------------------------------------

function TradeUpService.canTradeUp(items: { any }): (boolean, string?)
    -- Check count
    if not items or #items ~= TradeUpService.REQUIRED_COUNT then
        return false, string.format(
            "Trade-up requires exactly %d items, got %d",
            TradeUpService.REQUIRED_COUNT,
            items and #items or 0
        )
    end

    -- Check all items have the same ItemId
    local firstItemId = items[1].ItemId
    for i = 2, #items do
        if items[i].ItemId ~= firstItemId then
            return false, string.format(
                "All %d items must be identical. Expected '%s', got '%s' at position %d",
                TradeUpService.REQUIRED_COUNT,
                firstItemId,
                items[i].ItemId,
                i
            )
        end
    end

    -- Check rarity allows trading up FROM this tier
    local sourceRarity = items[1].Rarity
    local sourceTier = RarityConfig.Tiers[sourceRarity]
    if not sourceTier then
        return false, "Unknown rarity: " .. tostring(sourceRarity)
    end

    if not sourceTier.CanTradeUpFrom then
        return false, string.format(
            "Cannot trade up from %s tier",
            sourceRarity
        )
    end

    -- Check there is a valid next tier
    local nextTierName = RarityConfig.getNextTier(sourceRarity)
    if not nextTierName then
        return false, string.format(
            "No higher tier exists above %s",
            sourceRarity
        )
    end

    -- Check the target tier allows being traded up TO
    local targetTier = RarityConfig.Tiers[nextTierName]
    if not targetTier.CanTradeUpTo then
        return false, string.format(
            "Cannot trade up to %s tier",
            nextTierName
        )
    end

    return true, nil
end

--------------------------------------------------------------------------------
-- Execute a trade-up: remove 5 identical items, produce 1 item of next tier
-- @param inventory (Inventory) — The player's InventoryService instance
-- @param items ({ ItemInstance }) — The 5 items to consume
-- @param LootService (module) — LootService reference (passed to avoid circular dep)
-- @return ItemInstance? — The newly generated item, or nil on failure
-- @return string? — Error message on failure
--------------------------------------------------------------------------------

function TradeUpService.executeTradeUp(inventory: any, items: { any }, LootService: any): (any?, string?)
    -- Validate first
    local canDo, errMsg = TradeUpService.canTradeUp(items)
    if not canDo then
        return nil, errMsg
    end

    -- Determine the target rarity
    local sourceRarity = items[1].Rarity
    local targetRarity = RarityConfig.getNextTier(sourceRarity)

    -- Remove all 5 items from the inventory
    for _, item in ipairs(items) do
        local removed = inventory:removeItem(item.UniqueId)
        if not removed then
            -- This shouldn't happen, but guard against it
            warn("[TradeUpService] Failed to remove item: " .. item.UniqueId)
            return nil, "Failed to remove item from inventory: " .. item.UniqueId
        end
    end

    -- Generate 1 random item of the next tier
    local newItem = LootService.generateItem(targetRarity)

    -- Add the new item to the inventory
    inventory:addItem(newItem)

    return newItem, nil
end

--------------------------------------------------------------------------------
-- Get a summary of available trade-ups from an inventory
-- Returns a table of ItemIds that have >= 5 copies and can be traded up
-- @param inventory (Inventory) — The player's inventory
-- @return { { ItemId: string, Count: number, Rarity: string } }
--------------------------------------------------------------------------------

function TradeUpService.getAvailableTradeUps(inventory: any): { any }
    local allItems = inventory:getAllItems()

    -- Count items by ItemId
    local countByItemId = {} -- { [ItemId] = { count, rarity, displayName } }
    for _, item in ipairs(allItems) do
        if not countByItemId[item.ItemId] then
            countByItemId[item.ItemId] = {
                ItemId = item.ItemId,
                DisplayName = item.DisplayName,
                Rarity = item.Rarity,
                Count = 0,
            }
        end
        countByItemId[item.ItemId].Count += 1
    end

    -- Filter to only items with enough copies AND valid for trade-up
    local available = {}
    for _, info in pairs(countByItemId) do
        if info.Count >= TradeUpService.REQUIRED_COUNT then
            local canDo = TradeUpService.canTradeUp({
                { ItemId = info.ItemId, Rarity = info.Rarity },
                { ItemId = info.ItemId, Rarity = info.Rarity },
                { ItemId = info.ItemId, Rarity = info.Rarity },
                { ItemId = info.ItemId, Rarity = info.Rarity },
                { ItemId = info.ItemId, Rarity = info.Rarity },
            })
            if canDo then
                table.insert(available, info)
            end
        end
    end

    return available
end

return TradeUpService
