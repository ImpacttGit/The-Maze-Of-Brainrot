--[[
    EntityConfig.lua
    ================
    Data module defining the five maze entities and their behaviors.
    
    Each entity has movement speed, sound properties, AI behavior type,
    and visual configuration.
    
    AI params:
        DetectionRange   — starts actively tracking player
        KillRange        — instant kill if within this distance
        PursuitDuration  — seconds to chase after losing sight
        PlayerSeekChance — probability of picking player's location as next wander target
        LoseInterestRange — distance beyond which entity gives up chase
]]

local EntityConfig = {}

--------------------------------------------------------------------------------
-- Entity Definitions
--------------------------------------------------------------------------------

EntityConfig.Entities = {
    GlitchingGuard = {
        Name = "Glitching Guard",
        EntityId = "GlitchingGuard",
        Speed = 14,
        Description = "Patrols a fixed path. Lethal on contact.",
        BehaviorType = "Patrol",
        Color = Color3.fromRGB(200, 50, 50),
        BodyScale = 1.2,
        SoundId = "rbxassetid://0",
        SoundVolume = 0.6,
        SoundMaxDistance = 60,
        DetectionRange = 45,
        KillRange = 5,
        PursuitDuration = 6,
        PlayerSeekChance = 0.35,
        LoseInterestRange = 80,
    },

    FacelessWorker = {
        Name = "Faceless Worker",
        EntityId = "FacelessWorker",
        Speed = 10,
        Description = "Stalks players. Stops when the player stops.",
        BehaviorType = "Stalk",
        Color = Color3.fromRGB(100, 100, 120),
        BodyScale = 1.0,
        SoundId = "rbxassetid://0",
        SoundVolume = 0.4,
        SoundMaxDistance = 40,
        DetectionRange = 55,
        KillRange = 5,
        PursuitDuration = 8,
        PlayerSeekChance = 0.5,
        LoseInterestRange = 90,
    },

    ScurryingShadow = {
        Name = "Scurrying Shadow",
        EntityId = "ScurryingShadow",
        Speed = 22,
        Description = "Fast & aggressive. Chases on sight.",
        BehaviorType = "Chase",
        Color = Color3.fromRGB(30, 30, 30),
        BodyScale = 0.8,
        SoundId = "rbxassetid://0",
        SoundVolume = 0.8,
        SoundMaxDistance = 50,
        DetectionRange = 50,
        KillRange = 4,
        PursuitDuration = 10,
        PlayerSeekChance = 0.6,
        LoseInterestRange = 70,
    },

    MuteMannequin = {
        Name = "Mute Mannequin",
        EntityId = "MuteMannequin",
        Speed = 18,
        Description = "Only moves when not being watched. Deadly fast.",
        BehaviorType = "Camera",
        Color = Color3.fromRGB(240, 230, 210),
        BodyScale = 1.1,
        SoundId = "rbxassetid://0",
        SoundVolume = 0.9,
        SoundMaxDistance = 30,
        DetectionRange = 999,
        KillRange = 5,
        PursuitDuration = 999,
        PlayerSeekChance = 1.0,
        LoseInterestRange = 999,
    },

    RustedJanitor = {
        Name = "Rusted Janitor",
        EntityId = "RustedJanitor",
        Speed = 12,
        Description = "Erratic movement. Occasional loud bangs. Unpredictable.",
        BehaviorType = "Erratic",
        Color = Color3.fromRGB(160, 120, 60),
        BodyScale = 1.3,
        SoundId = "rbxassetid://0",
        SoundVolume = 0.7,
        SoundMaxDistance = 55,
        DetectionRange = 40,
        KillRange = 6,
        PursuitDuration = 5,
        PlayerSeekChance = 0.4,
        LoseInterestRange = 75,
    },
}

--------------------------------------------------------------------------------
-- Ordered list of entity IDs (for random selection)
--------------------------------------------------------------------------------

EntityConfig.EntityIds = {
    "GlitchingGuard",
    "FacelessWorker",
    "ScurryingShadow",
    "MuteMannequin",
    "RustedJanitor",
}

--------------------------------------------------------------------------------
-- Spawn timing
--------------------------------------------------------------------------------

EntityConfig.SpawnDelay = 8            -- Seconds before entity spawns (slightly faster)
EntityConfig.PositionUpdateRate = 0.5  -- How often to send position to client

return EntityConfig
