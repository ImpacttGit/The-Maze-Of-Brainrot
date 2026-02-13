--[[
    LootService.lua
    ===============
    Handles all loot generation logic for The Maze of Brainrot.
    
    Responsibilities:
        - Rolling weighted random rarity tiers (with optional luck multiplier)
        - Generating concrete item instances with rolled Fragment values
        - Generating batches of loot for populating maze floors
    
    Dependencies:
        - RarityConfig
        - ItemDatabase
]]

local RarityConfig = require(script.Parent.Parent.Data.RarityConfig)
local ItemDatabase = require(script.Parent.Parent.Data.ItemDatabase)

local HttpService = game:GetService("HttpService")

local LootService = {}

--------------------------------------------------------------------------------
-- INTERNAL: Build weighted rarity pool
-- Each tier's weight is multiplied by an optional luck factor for Rare+ tiers
--------------------------------------------------------------------------------

local function buildWeightedPool(luckMultiplier: number?): { { Name: string, Weight: number } }
    local luck = luckMultiplier or 1.0
    local pool = {}

    for _, tierName in ipairs(RarityConfig.OrderedTiers) do
        local tier = RarityConfig.Tiers[tierName]
        local weight = tier.SpawnWeight

        -- Luck multiplier boosts Rare and above, reduces Common
        if tier.Order >= 2 and luck > 1.0 then
            weight = weight * luck
        elseif tier.Order == 1 and luck > 1.0 then
            weight = weight / luck -- Reduce Common spawn rate
        end

        table.insert(pool, {
            Name = tierName,
            Weight = weight,
        })
    end

    return pool
end

--------------------------------------------------------------------------------
-- Roll a random rarity tier using weighted selection
-- @param luckMultiplier (number?) — Optional multiplier for Loot Luck boost
-- @return string — Rarity tier name (e.g. "Common", "Rare", etc.)
--------------------------------------------------------------------------------

function LootService.rollRarity(luckMultiplier: number?): string
    local pool = buildWeightedPool(luckMultiplier)

    -- Calculate total weight
    local totalWeight = 0
    for _, entry in ipairs(pool) do
        totalWeight += entry.Weight
    end

    -- Roll a random value in the total weight range
    local roll = math.random() * totalWeight
    local cumulative = 0

    for _, entry in ipairs(pool) do
        cumulative += entry.Weight
        if roll <= cumulative then
            return entry.Name
        end
    end

    -- Fallback (should never reach here)
    return "Common"
end

--------------------------------------------------------------------------------
-- Generate a single item instance with a rolled Fragment value
-- @param rarityOverride (string?) — Force a specific rarity tier
-- @param luckMultiplier (number?) — Optional luck multiplier for rarity roll
-- @return ItemInstance table
--------------------------------------------------------------------------------

function LootService.generateItem(rarityOverride: string?, luckMultiplier: number?): any
    -- Determine rarity
    local rarity = rarityOverride or LootService.rollRarity(luckMultiplier)
    local tierConfig = RarityConfig.Tiers[rarity]

    -- Pick a random item from this rarity's pool
    local itemIds = ItemDatabase.getItemIdsByRarity(rarity)
    assert(#itemIds > 0, "No items found for rarity: " .. rarity)

    local chosenId = itemIds[math.random(1, #itemIds)]
    local itemDef = ItemDatabase.getItem(chosenId)

    -- Roll a Fragment value within the tier's range
    local fragmentValue = 0
    if tierConfig.MinValue > 0 and tierConfig.MaxValue > 0 then
        fragmentValue = math.random(tierConfig.MinValue, tierConfig.MaxValue)
    end

    -- Generate a unique ID for this specific instance
    local uniqueId = HttpService:GenerateGUID(false)

    -- Build the item instance
    local itemInstance = {
        UniqueId = uniqueId,
        ItemId = itemDef.ItemId,
        DisplayName = itemDef.DisplayName,
        Rarity = rarity,
        FragmentValue = fragmentValue,
        IsFollower = itemDef.IsFollower,
        PowerUp = itemDef.PowerUp, -- nil for non-Epics
    }

    return itemInstance
end

--------------------------------------------------------------------------------
-- Generate a batch of items for populating a maze floor
-- @param count (number) — Number of items to generate
-- @param luckMultiplier (number?) — Optional luck multiplier
-- @return { ItemInstance } — Array of item instances
--------------------------------------------------------------------------------

function LootService.generateLootTable(count: number, luckMultiplier: number?): { any }
    assert(count > 0, "Loot table count must be greater than 0")

    local lootTable = {}
    for i = 1, count do
        local item = LootService.generateItem(nil, luckMultiplier)
        table.insert(lootTable, item)
    end

    return lootTable
end

return LootService
