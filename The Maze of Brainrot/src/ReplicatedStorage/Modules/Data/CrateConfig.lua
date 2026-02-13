--[[
    CrateConfig.lua
    ===============
    Data module defining crate tiers, costs, and drop odds.
    
    Used by CrateService (server) for validation and loot rolls,
    and by CrateClient (client) for UI display.
    
    Frozen at runtime.
]]

local CrateConfig = {}

--------------------------------------------------------------------------------
-- Crate Definitions
--------------------------------------------------------------------------------

CrateConfig.Crates = {
    Common = {
        Name = "Common Crate",
        CrateId = "Common",
        Description = "Basic loot. Mostly commons with a chance at rares.",
        RobuxPrice = 75,
        FragmentPrice = 500,
        CanBuyWithFragments = true,
        -- Weighted odds (must sum to 100)
        Odds = {
            { Rarity = "Common", Weight = 70 },
            { Rarity = "Rare",   Weight = 30 },
        },
        Color = Color3.fromRGB(200, 200, 200), -- Silver
        ProductId = 0, -- Placeholder DeveloperProduct ID
    },

    Rare = {
        Name = "Rare Crate",
        CrateId = "Rare",
        Description = "Higher tier loot. Rares and Epics.",
        RobuxPrice = 250,
        FragmentPrice = 2000,
        CanBuyWithFragments = true,
        Odds = {
            { Rarity = "Rare", Weight = 60 },
            { Rarity = "Epic", Weight = 40 },
        },
        Color = Color3.fromRGB(0, 120, 255), -- Blue
        ProductId = 0,
    },

    Legendary = {
        Name = "Legendary Crate",
        CrateId = "Legendary",
        Description = "The ultimate crate. Robux only.",
        RobuxPrice = 500,
        FragmentPrice = 0,
        CanBuyWithFragments = false, -- Robux only
        Odds = {
            { Rarity = "Rare",      Weight = 25 },
            { Rarity = "Epic",      Weight = 50 },
            { Rarity = "Legendary", Weight = 25 },
        },
        Color = Color3.fromRGB(255, 215, 0), -- Gold
        ProductId = 0,
    },
}

--------------------------------------------------------------------------------
-- Ordered list for UI display
--------------------------------------------------------------------------------

CrateConfig.CrateOrder = { "Common", "Rare", "Legendary" }

--------------------------------------------------------------------------------
-- Freeze
--------------------------------------------------------------------------------

for _, crate in pairs(CrateConfig.Crates) do
    for _, odd in ipairs(crate.Odds) do
        table.freeze(odd)
    end
    table.freeze(crate.Odds)
    table.freeze(crate)
end
table.freeze(CrateConfig.Crates)
table.freeze(CrateConfig.CrateOrder)
table.freeze(CrateConfig)

return CrateConfig
