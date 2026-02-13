--[[
    ItemDatabase.lua
    ================
    Master registry of every collectable item in The Maze of Brainrot.
    
    Each item is keyed by a unique ItemId (snake_case string).
    Fields:
        ItemId       (string)  — Unique identifier
        DisplayName  (string)  — Human-readable name shown in UI
        Rarity       (string)  — Key into RarityConfig.Tiers
        Description  (string)  — Flavor text / tooltip
        IsFollower   (boolean) — True for Legendary 3D followers
        PowerUp      (table?)  — Only for Epic consumables
    
    This table is frozen — do NOT mutate at runtime.
]]

local ItemDatabase = {}

--------------------------------------------------------------------------------
-- COMMON ITEMS (12 total)
-- Value range: 10–50 Fragments | Outline: White
-- No special effects — trade-up fodder
--------------------------------------------------------------------------------

local CommonItems = {
    pen = {
        ItemId = "pen",
        DisplayName = "Pen",
        Rarity = "Common",
        Description = "A standard ballpoint pen. Nothing special.",
        IsFollower = false,
        PowerUp = nil,
    },
    pencil = {
        ItemId = "pencil",
        DisplayName = "Pencil",
        Rarity = "Common",
        Description = "A #2 pencil, slightly chewed.",
        IsFollower = false,
        PowerUp = nil,
    },
    stapler = {
        ItemId = "stapler",
        DisplayName = "Stapler",
        Rarity = "Common",
        Description = "Red Swingline. Someone will miss this.",
        IsFollower = false,
        PowerUp = nil,
    },
    paper = {
        ItemId = "paper",
        DisplayName = "Paper",
        Rarity = "Common",
        Description = "A blank sheet of copy paper.",
        IsFollower = false,
        PowerUp = nil,
    },
    ruler = {
        ItemId = "ruler",
        DisplayName = "Ruler",
        Rarity = "Common",
        Description = "12 inches of pure measurement.",
        IsFollower = false,
        PowerUp = nil,
    },
    eraser = {
        ItemId = "eraser",
        DisplayName = "Eraser",
        Rarity = "Common",
        Description = "Pink rubber eraser, well-worn.",
        IsFollower = false,
        PowerUp = nil,
    },
    tape = {
        ItemId = "tape",
        DisplayName = "Tape",
        Rarity = "Common",
        Description = "Scotch tape dispenser. Surprisingly heavy.",
        IsFollower = false,
        PowerUp = nil,
    },
    scissors = {
        ItemId = "scissors",
        DisplayName = "Scissors",
        Rarity = "Common",
        Description = "Safety scissors. Don't run with them.",
        IsFollower = false,
        PowerUp = nil,
    },
    paperclip = {
        ItemId = "paperclip",
        DisplayName = "Paperclip",
        Rarity = "Common",
        Description = "A single bent paperclip.",
        IsFollower = false,
        PowerUp = nil,
    },
    sticky_note = {
        ItemId = "sticky_note",
        DisplayName = "Sticky Note",
        Rarity = "Common",
        Description = "Yellow. Has 'HELP' written on it.",
        IsFollower = false,
        PowerUp = nil,
    },
    folder = {
        ItemId = "folder",
        DisplayName = "Folder",
        Rarity = "Common",
        Description = "Manila folder. Empty... or is it?",
        IsFollower = false,
        PowerUp = nil,
    },
    binder = {
        ItemId = "binder",
        DisplayName = "Binder",
        Rarity = "Common",
        Description = "3-ring binder. The rings don't close properly.",
        IsFollower = false,
        PowerUp = nil,
    },
}

--------------------------------------------------------------------------------
-- RARE ITEMS (10 total)
-- Value range: 200–500 Fragments | Outline: Blue
-- Pickup effect: Pulsing blue light on screen
--------------------------------------------------------------------------------

local RareItems = {
    mouse = {
        ItemId = "mouse",
        DisplayName = "Mouse",
        Rarity = "Rare",
        Description = "Wireless office mouse. The scroll wheel squeaks.",
        IsFollower = false,
        PowerUp = nil,
    },
    keyboard = {
        ItemId = "keyboard",
        DisplayName = "Keyboard",
        Rarity = "Rare",
        Description = "Mechanical keyboard. The 'E' key is missing.",
        IsFollower = false,
        PowerUp = nil,
    },
    laptop = {
        ItemId = "laptop",
        DisplayName = "Laptop",
        Rarity = "Rare",
        Description = "Company laptop. Screen still flickers.",
        IsFollower = false,
        PowerUp = nil,
    },
    phone = {
        ItemId = "phone",
        DisplayName = "Phone",
        Rarity = "Rare",
        Description = "Office desk phone. Sometimes it rings...",
        IsFollower = false,
        PowerUp = nil,
    },
    camera = {
        ItemId = "camera",
        DisplayName = "Camera",
        Rarity = "Rare",
        Description = "Security camera. The red light is still on.",
        IsFollower = false,
        PowerUp = nil,
    },
    monitor = {
        ItemId = "monitor",
        DisplayName = "Monitor",
        Rarity = "Rare",
        Description = "CRT monitor. Displays only static.",
        IsFollower = false,
        PowerUp = nil,
    },
    tablet = {
        ItemId = "tablet",
        DisplayName = "Tablet",
        Rarity = "Rare",
        Description = "Cracked screen tablet. Touch still works.",
        IsFollower = false,
        PowerUp = nil,
    },
    usb_drive = {
        ItemId = "usb_drive",
        DisplayName = "USB Drive",
        Rarity = "Rare",
        Description = "16GB flash drive. What's on it?",
        IsFollower = false,
        PowerUp = nil,
    },
    headset = {
        ItemId = "headset",
        DisplayName = "Headset",
        Rarity = "Rare",
        Description = "Noise-cancelling headset. You hear whispers.",
        IsFollower = false,
        PowerUp = nil,
    },
    smartwatch = {
        ItemId = "smartwatch",
        DisplayName = "Smartwatch",
        Rarity = "Rare",
        Description = "The time displayed is always 3:33 AM.",
        IsFollower = false,
        PowerUp = nil,
    },
}

--------------------------------------------------------------------------------
-- EPIC ITEMS (7 total)
-- Value range: 1,500–3,000 Fragments | Outline: Purple
-- Pickup effect: Purple particle burst + Temporary Power-up
--------------------------------------------------------------------------------

local EpicItems = {
    stapler_of_speed = {
        ItemId = "stapler_of_speed",
        DisplayName = "Stapler of Speed",
        Rarity = "Epic",
        Description = "Staple your way to safety. Temporary 1.5x speed boost.",
        IsFollower = false,
        PowerUp = {
            Type = "SpeedBoost",
            Multiplier = 1.5,
            Duration = 15, -- seconds
        },
    },
    supersonic_headphones = {
        ItemId = "supersonic_headphones",
        DisplayName = "Supersonic Headphones",
        Rarity = "Epic",
        Description = "Hear everything. Heartbeat and Legendary chimes go louder.",
        IsFollower = false,
        PowerUp = {
            Type = "DetectionBoost",
            RangeMultiplier = 2.0,
            Duration = 30,
        },
    },
    powerbank = {
        ItemId = "powerbank",
        DisplayName = "Powerbank",
        Rarity = "Epic",
        Description = "Full charge. Instantly refills flashlight battery.",
        IsFollower = false,
        PowerUp = {
            Type = "FlashlightRecharge",
            RechargePercent = 100,
        },
    },
    radiant_water_cooler = {
        ItemId = "radiant_water_cooler",
        DisplayName = "Radiant Water Cooler",
        Rarity = "Epic",
        Description = "Glow with neon light. See better... but they see you too.",
        IsFollower = false,
        PowerUp = {
            Type = "NeonAura",
            VisionBoost = 1.5,
            EntityDetectionMultiplier = 2.0, -- Entities detect you easier
            Duration = 20,
        },
    },
    glitching_printer = {
        ItemId = "glitching_printer",
        DisplayName = "The Glitching Printer",
        Rarity = "Epic",
        Description = "Forces all nearby lights to flicker and turn off.",
        IsFollower = false,
        PowerUp = {
            Type = "LightDisruption",
            Radius = 40, -- studs
            Duration = 10,
        },
    },
    cursed_telephone = {
        ItemId = "cursed_telephone",
        DisplayName = "The Cursed Telephone",
        Rarity = "Epic",
        Description = "Ring ring... the sound moves. Distracts entities.",
        IsFollower = false,
        PowerUp = {
            Type = "SoundDecoy",
            DecoyDuration = 8,
            TeleportDistance = 50, -- studs away
        },
    },
    possessed_compass = {
        ItemId = "possessed_compass",
        DisplayName = "Possessed Compass",
        Rarity = "Epic",
        Description = "Points to riches. Turns gold near Legendaries.",
        IsFollower = false,
        PowerUp = {
            Type = "ItemRadar",
            TargetRarities = { "Epic", "Legendary" },
            Duration = 45,
            LegendaryChime = true,
        },
    },
}

--------------------------------------------------------------------------------
-- LEGENDARY ITEMS (5 total)
-- Value: Non-Sellable (0 Fragments) | Outline: Gold
-- Permanent 3D Followers + Gold shimmer effect
-- Survive death — never lost on a failed run
--------------------------------------------------------------------------------

local LegendaryItems = {
    tralalero_tralala = {
        ItemId = "tralalero_tralala",
        DisplayName = "Tralalero Tralala",
        Rarity = "Legendary",
        Description = "A shark in sneakers. He walks beside you now.",
        IsFollower = true,
        PowerUp = nil,
        FollowerInfo = {
            Position = "WalkBeside",
            ModelName = "Tralalero_Tralala_Model",
        },
    },
    ballerina_cappuccina = {
        ItemId = "ballerina_cappuccina",
        DisplayName = "Ballerina Cappuccina",
        Rarity = "Legendary",
        Description = "A dancing ballerina perched on your shoulder.",
        IsFollower = true,
        PowerUp = nil,
        FollowerInfo = {
            Position = "Shoulder",
            ModelName = "Ballerina_Cappuccina_Model",
        },
    },
    chimpanzini_bananini = {
        ItemId = "chimpanzini_bananini",
        DisplayName = "Chimpanzini Bananini",
        Rarity = "Legendary",
        Description = "A monkey with a banana body. Your new best friend.",
        IsFollower = true,
        PowerUp = nil,
        FollowerInfo = {
            Position = "WalkBeside",
            ModelName = "Chimpanzini_Bananini_Model",
        },
    },
    bombardiro_crocodilo = {
        ItemId = "bombardiro_crocodilo",
        DisplayName = "Bombardiro Crocodilo",
        Rarity = "Legendary",
        Description = "A crocodile-jet hybrid circling your head.",
        IsFollower = true,
        PowerUp = nil,
        FollowerInfo = {
            Position = "CircleHead",
            ModelName = "Bombardiro_Crocodilo_Model",
        },
    },
    tung_tung_tung_sahur = {
        ItemId = "tung_tung_tung_sahur",
        DisplayName = "Tung Tung Tung Sahur",
        Rarity = "Legendary",
        Description = "A bat-wielding wooden plank. Occasionally 'bops'.",
        IsFollower = true,
        PowerUp = nil,
        FollowerInfo = {
            Position = "Back",
            ModelName = "Tung_Tung_Tung_Sahur_Model",
            IdleAnimation = "Bop", -- Plays occasionally
        },
    },
}

--------------------------------------------------------------------------------
-- Master Items Table
-- Merges all tiers into a single flat dictionary keyed by ItemId
--------------------------------------------------------------------------------

local Items = {}

local function mergeItems(source)
    for itemId, itemData in pairs(source) do
        assert(Items[itemId] == nil, "Duplicate ItemId: " .. itemId)
        Items[itemId] = itemData
    end
end

mergeItems(CommonItems)
mergeItems(RareItems)
mergeItems(EpicItems)
mergeItems(LegendaryItems)

ItemDatabase.Items = Items

--------------------------------------------------------------------------------
-- Lookup helpers
--------------------------------------------------------------------------------

-- Get all items belonging to a specific rarity tier
function ItemDatabase.getItemsByRarity(rarity: string): { [string]: any }
    local results = {}
    for itemId, itemData in pairs(Items) do
        if itemData.Rarity == rarity then
            results[itemId] = itemData
        end
    end
    return results
end

-- Get a flat array of ItemIds for a specific rarity
function ItemDatabase.getItemIdsByRarity(rarity: string): { string }
    local results = {}
    for itemId, itemData in pairs(Items) do
        if itemData.Rarity == rarity then
            table.insert(results, itemId)
        end
    end
    return results
end

-- Get a single item definition by its ItemId
function ItemDatabase.getItem(itemId: string): any?
    return Items[itemId]
end

-- Get the total count of items for a specific rarity
function ItemDatabase.getCountByRarity(rarity: string): number
    local count = 0
    for _, itemData in pairs(Items) do
        if itemData.Rarity == rarity then
            count += 1
        end
    end
    return count
end

--------------------------------------------------------------------------------
-- Freeze all item tables to prevent accidental mutation
--------------------------------------------------------------------------------

for _, itemData in pairs(Items) do
    if itemData.PowerUp then
        if itemData.PowerUp.TargetRarities then
            table.freeze(itemData.PowerUp.TargetRarities)
        end
        table.freeze(itemData.PowerUp)
    end
    if itemData.FollowerInfo then
        table.freeze(itemData.FollowerInfo)
    end
    table.freeze(itemData)
end
table.freeze(Items)

return ItemDatabase
