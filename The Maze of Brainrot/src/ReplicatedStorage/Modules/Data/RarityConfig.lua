--[[
    RarityConfig.lua
    ================
    Pure data module defining all rarity tiers for The Maze of Brainrot.
    
    Each tier specifies its display properties, value range, trade-up rules,
    and base spawn weight for the loot system.
    
    This table is frozen — do NOT mutate at runtime.
]]

local RarityConfig = {}

--------------------------------------------------------------------------------
-- Rarity Tier Definitions
--------------------------------------------------------------------------------

RarityConfig.Tiers = {
    Common = {
        Name = "Common",
        Order = 1,
        OutlineColor = Color3.fromRGB(255, 255, 255), -- White
        MinValue = 10,
        MaxValue = 50,
        CanTradeUpTo = true,   -- Items CAN be traded up TO Common (N/A in practice)
        CanTradeUpFrom = true, -- Items CAN be traded up FROM Common → Rare
        SpawnWeight = 60,      -- 60% relative weight
    },

    Rare = {
        Name = "Rare",
        Order = 2,
        OutlineColor = Color3.fromRGB(0, 120, 255), -- Blue
        MinValue = 200,
        MaxValue = 500,
        CanTradeUpTo = true,
        CanTradeUpFrom = true, -- Rare → Epic allowed
        SpawnWeight = 25,      -- 25% relative weight
    },

    Epic = {
        Name = "Epic",
        Order = 3,
        OutlineColor = Color3.fromRGB(163, 53, 238), -- Purple
        MinValue = 1500,
        MaxValue = 3000,
        CanTradeUpTo = true,
        CanTradeUpFrom = false, -- Epic → Legendary BLOCKED
        SpawnWeight = 12,       -- 12% relative weight
    },

    Legendary = {
        Name = "Legendary",
        Order = 4,
        OutlineColor = Color3.fromRGB(255, 215, 0), -- Gold
        MinValue = 0,
        MaxValue = 0,          -- Non-sellable
        CanTradeUpTo = false,  -- Cannot be the TARGET of a trade-up
        CanTradeUpFrom = false,
        SpawnWeight = 3,       -- 3% relative weight
    },
}

--------------------------------------------------------------------------------
-- Ordered list for iteration (lowest → highest)
--------------------------------------------------------------------------------

RarityConfig.OrderedTiers = { "Common", "Rare", "Epic", "Legendary" }

--------------------------------------------------------------------------------
-- Lookup: get the next tier name for trade-ups
-- Returns nil if no valid next tier exists
--------------------------------------------------------------------------------

function RarityConfig.getNextTier(currentTierName: string): string?
    local currentTier = RarityConfig.Tiers[currentTierName]
    if not currentTier then
        return nil
    end

    local nextOrder = currentTier.Order + 1
    for _, tierName in ipairs(RarityConfig.OrderedTiers) do
        local tier = RarityConfig.Tiers[tierName]
        if tier.Order == nextOrder then
            return tierName
        end
    end

    return nil
end

--------------------------------------------------------------------------------
-- Freeze tables to prevent accidental mutation
--------------------------------------------------------------------------------

for _, tier in pairs(RarityConfig.Tiers) do
    table.freeze(tier)
end
table.freeze(RarityConfig.Tiers)
table.freeze(RarityConfig.OrderedTiers)
table.freeze(RarityConfig)

return RarityConfig
