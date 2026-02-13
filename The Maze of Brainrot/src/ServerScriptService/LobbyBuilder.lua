--[[
    LobbyBuilder.lua
    ================
    Server Module — generates a full office-themed lobby in Workspace.
    
    Called once on server boot to create the static lobby environment.
    Uses only basic Parts (no meshes) to create an atmospheric space.
    
    Layout (top-down, centered at 0,0,0):
        +------------------------------------------+
        |                CEILING                    |
        |  [Spawn]     [Main Hall]    [Elevator]   |
        |                                          |
        |  [Merchant]  [Trade-Up]   [Crate Shop]   |
        |                                          |
        +------------------------------------------+
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local LobbyBuilder = {}

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local LOBBY_WIDTH = 100   -- X axis
local LOBBY_DEPTH = 80    -- Z axis
local LOBBY_HEIGHT = 16   -- Wall height
local FLOOR_Y = 0
local WALL_THICKNESS = 3

local COLORS = {
    Floor = Color3.fromRGB(180, 170, 155),       -- Warm beige tile
    FloorAccent = Color3.fromRGB(140, 130, 115),  -- Darker tile stripe
    Walls = Color3.fromRGB(200, 195, 185),        -- Off-white drywall
    WallTrim = Color3.fromRGB(90, 80, 65),        -- Dark wood trim
    Ceiling = Color3.fromRGB(220, 218, 210),      -- Light ceiling
    Metal = Color3.fromRGB(120, 120, 130),        -- Metal accents
    DarkMetal = Color3.fromRGB(60, 60, 65),       -- Dark machinery
    Wood = Color3.fromRGB(140, 100, 60),          -- Wooden furniture
    WoodDark = Color3.fromRGB(90, 60, 35),        -- Dark wood
    Glass = Color3.fromRGB(180, 220, 240),        -- Glass panels
    GreenAccent = Color3.fromRGB(50, 180, 80),    -- Elevator highlight
    RedAccent = Color3.fromRGB(180, 50, 50),      -- Warning
    GoldAccent = Color3.fromRGB(255, 200, 50),    -- Premium
    CrateBlue = Color3.fromRGB(60, 120, 220),     -- Crate shop
    WarmLight = Color3.fromRGB(255, 240, 210),    -- Warm lighting
    CoolLight = Color3.fromRGB(200, 220, 255),    -- Cool accent lighting
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function createPart(props): Part
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = props.CanCollide ~= false
    part.Size = props.Size or Vector3.new(1, 1, 1)
    part.Position = props.Position or Vector3.new(0, 0, 0)
    part.CFrame = props.CFrame or part.CFrame
    part.Color = props.Color or COLORS.Floor
    part.Material = props.Material or Enum.Material.SmoothPlastic
    part.Transparency = props.Transparency or 0
    part.Name = props.Name or "LobbyPart"
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = props.Parent
    return part
end

local function addLight(parent, props)
    local light = Instance.new(props.Type or "PointLight")
    light.Brightness = props.Brightness or 1
    light.Range = props.Range or 20
    light.Color = props.Color or COLORS.WarmLight
    if light:IsA("SpotLight") then
        light.Angle = props.Angle or 90
        light.Face = props.Face or Enum.NormalId.Bottom
    end
    light.Parent = parent
    return light
end

local function addBillboard(parent, text, textColor, bgColor, size, studOffset)
    local bb = Instance.new("BillboardGui")
    bb.Size = size or UDim2.new(0, 200, 0, 50)
    bb.StudsOffset = studOffset or Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = false
    bb.LightInfluence = 0.3
    bb.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundColor3 = bgColor or Color3.fromRGB(0, 0, 0)
    label.BackgroundTransparency = 0.3
    label.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
    label.Text = text
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = bb

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = label

    return bb
end

--------------------------------------------------------------------------------
-- Build: Floor
--------------------------------------------------------------------------------

local function buildFloor(folder)
    -- Main floor (tiled pattern)
    local mainFloor = createPart({
        Name = "LobbyFloor",
        Size = Vector3.new(LOBBY_WIDTH, 1, LOBBY_DEPTH),
        Position = Vector3.new(0, FLOOR_Y - 0.5, 0),
        Color = COLORS.Floor,
        Material = Enum.Material.Marble,
        Parent = folder,
    })

    -- Accent stripe lines on floor
    for z = -LOBBY_DEPTH/2 + 10, LOBBY_DEPTH/2 - 10, 20 do
        createPart({
            Name = "FloorStripe",
            Size = Vector3.new(LOBBY_WIDTH - 6, 1.02, 1.5),
            Position = Vector3.new(0, FLOOR_Y - 0.49, z),
            Color = COLORS.FloorAccent,
            Material = Enum.Material.Marble,
            Parent = folder,
        })
    end

    -- Center logo area (darker circle approximation)
    createPart({
        Name = "CenterLogo",
        Size = Vector3.new(16, 1.02, 16),
        Position = Vector3.new(0, FLOOR_Y - 0.49, 0),
        Color = COLORS.WallTrim,
        Material = Enum.Material.Granite,
        Parent = folder,
    })
end

--------------------------------------------------------------------------------
-- Build: Walls & Ceiling
--------------------------------------------------------------------------------

local function buildWalls(folder)
    local hw = LOBBY_WIDTH / 2
    local hd = LOBBY_DEPTH / 2

    -- Four walls
    local wallDefs = {
        { Name = "WallNorth", Size = Vector3.new(LOBBY_WIDTH, LOBBY_HEIGHT, WALL_THICKNESS), Pos = Vector3.new(0, LOBBY_HEIGHT/2, -hd) },
        { Name = "WallSouth", Size = Vector3.new(LOBBY_WIDTH, LOBBY_HEIGHT, WALL_THICKNESS), Pos = Vector3.new(0, LOBBY_HEIGHT/2, hd) },
        { Name = "WallEast", Size = Vector3.new(WALL_THICKNESS, LOBBY_HEIGHT, LOBBY_DEPTH), Pos = Vector3.new(hw, LOBBY_HEIGHT/2, 0) },
        { Name = "WallWest", Size = Vector3.new(WALL_THICKNESS, LOBBY_HEIGHT, LOBBY_DEPTH), Pos = Vector3.new(-hw, LOBBY_HEIGHT/2, 0) },
    }

    for _, def in ipairs(wallDefs) do
        local wall = createPart({
            Name = def.Name,
            Size = def.Size,
            Position = def.Pos,
            Color = COLORS.Walls,
            Material = Enum.Material.Concrete,
            Parent = folder,
        })

        -- Bottom trim
        createPart({
            Name = def.Name .. "_Trim",
            Size = Vector3.new(
                def.Size.X == WALL_THICKNESS and WALL_THICKNESS + 0.5 or def.Size.X,
                2,
                def.Size.Z == WALL_THICKNESS and WALL_THICKNESS + 0.5 or def.Size.Z
            ),
            Position = def.Pos - Vector3.new(0, LOBBY_HEIGHT/2 - 1, 0),
            Color = COLORS.WallTrim,
            Material = Enum.Material.Wood,
            Parent = folder,
        })
    end

    -- Ceiling
    createPart({
        Name = "Ceiling",
        Size = Vector3.new(LOBBY_WIDTH, 1, LOBBY_DEPTH),
        Position = Vector3.new(0, LOBBY_HEIGHT + 0.5, 0),
        Color = COLORS.Ceiling,
        Material = Enum.Material.SmoothPlastic,
        Parent = folder,
    })
end

--------------------------------------------------------------------------------
-- Build: Ceiling Lights
--------------------------------------------------------------------------------

local function buildCeilingLights(folder)
    for x = -LOBBY_WIDTH/2 + 15, LOBBY_WIDTH/2 - 15, 20 do
        for z = -LOBBY_DEPTH/2 + 12, LOBBY_DEPTH/2 - 12, 16 do
            -- Fluorescent panel
            local lightPanel = createPart({
                Name = "CeilingLight",
                Size = Vector3.new(8, 0.4, 3),
                Position = Vector3.new(x, LOBBY_HEIGHT - 0.2, z),
                Color = Color3.fromRGB(255, 250, 240),
                Material = Enum.Material.Neon,
                Transparency = 0.1,
                Parent = folder,
            })

            addLight(lightPanel, {
                Type = "PointLight",
                Brightness = 1.2,
                Range = 25,
                Color = COLORS.WarmLight,
            })
        end
    end
end

--------------------------------------------------------------------------------
-- Build: Elevator (Maze Entrance) — East wall
--------------------------------------------------------------------------------

local function buildElevator(folder)
    local elevX = LOBBY_WIDTH/2 - 3
    local elevZ = 0

    -- Elevator frame (dark metal surround)
    createPart({
        Name = "ElevatorFrame",
        Size = Vector3.new(2, 14, 14),
        Position = Vector3.new(elevX - 1, 7, elevZ),
        Color = COLORS.DarkMetal,
        Material = Enum.Material.DiamondPlate,
        Parent = folder,
    })

    -- Left door
    createPart({
        Name = "ElevatorDoorL",
        Size = Vector3.new(1, 10, 5),
        Position = Vector3.new(elevX, 5.5, elevZ - 3),
        Color = COLORS.Metal,
        Material = Enum.Material.Metal,
        Parent = folder,
    })

    -- Right door
    createPart({
        Name = "ElevatorDoorR",
        Size = Vector3.new(1, 10, 5),
        Position = Vector3.new(elevX, 5.5, elevZ + 3),
        Color = COLORS.Metal,
        Material = Enum.Material.Metal,
        Parent = folder,
    })

    -- Warning stripes above elevator
    createPart({
        Name = "WarningStripe",
        Size = Vector3.new(1, 2, 12),
        Position = Vector3.new(elevX, 11.5, elevZ),
        Color = Color3.fromRGB(255, 200, 0),
        Material = Enum.Material.Neon,
        Transparency = 0.4,
        Parent = folder,
    })

    -- Elevator sign
    local signPart = createPart({
        Name = "ElevatorSign",
        Size = Vector3.new(1, 1, 1),
        Position = Vector3.new(elevX - 2, 13, elevZ),
        Transparency = 1,
        CanCollide = false,
        Parent = folder,
    })
    addBillboard(signPart, "⚠️ ENTER THE MAZE", Color3.fromRGB(255, 200, 0), Color3.fromRGB(30, 20, 0), UDim2.new(0, 280, 0, 50), Vector3.new(0, 0, 0))

    -- Green accent lights
    for _, zOff in ipairs({-7.5, 7.5}) do
        local accent = createPart({
            Name = "ElevAccentLight",
            Size = Vector3.new(0.5, 10, 0.5),
            Position = Vector3.new(elevX - 0.5, 5.5, elevZ + zOff),
            Color = COLORS.GreenAccent,
            Material = Enum.Material.Neon,
            Transparency = 0.3,
            Parent = folder,
        })
        addLight(accent, {
            Brightness = 2,
            Range = 12,
            Color = COLORS.GreenAccent,
        })
    end

    -- Floor arrows pointing to elevator
    for i = 1, 3 do
        createPart({
            Name = "FloorArrow" .. i,
            Size = Vector3.new(3, 1.02, 1),
            Position = Vector3.new(elevX - 8 - (i * 5), FLOOR_Y - 0.48, elevZ),
            Color = COLORS.GreenAccent,
            Material = Enum.Material.Neon,
            Transparency = 0.5,
            Parent = folder,
        })
    end
end

--------------------------------------------------------------------------------
-- Build: Merchant Station — Southwest
--------------------------------------------------------------------------------

local function buildMerchant(folder)
    local mx, mz = -25, 20

    -- Counter desk
    createPart({
        Name = "MerchantCounter",
        Size = Vector3.new(14, 4, 3),
        Position = Vector3.new(mx, 2, mz),
        Color = COLORS.WoodDark,
        Material = Enum.Material.Wood,
        Parent = folder,
    })

    -- Counter top (lighter)
    createPart({
        Name = "MerchantCounterTop",
        Size = Vector3.new(14.5, 0.5, 3.5),
        Position = Vector3.new(mx, 4.25, mz),
        Color = COLORS.Wood,
        Material = Enum.Material.Wood,
        Parent = folder,
    })

    -- Cash register (small box)
    createPart({
        Name = "CashRegister",
        Size = Vector3.new(3, 2, 2),
        Position = Vector3.new(mx + 3, 5.25, mz),
        Color = COLORS.DarkMetal,
        Material = Enum.Material.Metal,
        Parent = folder,
    })

    -- NPC Merchant body (behind counter)
    local npcBody = createPart({
        Name = "MerchantNPC",
        Size = Vector3.new(2, 5, 1.5),
        Position = Vector3.new(mx, 4.5, mz + 3),
        Color = Color3.fromRGB(100, 70, 50),
        Material = Enum.Material.SmoothPlastic,
        Parent = folder,
    })

    -- NPC Head
    createPart({
        Name = "MerchantHead",
        Size = Vector3.new(1.6, 1.6, 1.6),
        Position = Vector3.new(mx, 7.8, mz + 3),
        Color = Color3.fromRGB(210, 180, 150),
        Material = Enum.Material.SmoothPlastic,
        Parent = folder,
    })

    -- Sign
    local signPart = createPart({
        Name = "MerchantSign",
        Size = Vector3.new(1, 1, 1),
        Position = Vector3.new(mx, 9, mz),
        Transparency = 1,
        CanCollide = false,
        Parent = folder,
    })
    addBillboard(signPart, "💰 MERCHANT", COLORS.GoldAccent, Color3.fromRGB(20, 15, 0), UDim2.new(0, 200, 0, 45))

    -- Desk lamp
    local lamp = createPart({
        Name = "DeskLamp",
        Size = Vector3.new(1, 1.5, 1),
        Position = Vector3.new(mx - 4, 5.5, mz),
        Color = COLORS.GoldAccent,
        Material = Enum.Material.Neon,
        Transparency = 0.3,
        Parent = folder,
    })
    addLight(lamp, { Brightness = 2, Range = 10, Color = COLORS.GoldAccent })
end

--------------------------------------------------------------------------------
-- Build: Trade-Up Station — Northwest  
--------------------------------------------------------------------------------

local function buildTradeUp(folder)
    local tx, tz = -25, -20

    -- Machine base (industrial look)
    createPart({
        Name = "TradeUpBase",
        Size = Vector3.new(8, 6, 6),
        Position = Vector3.new(tx, 3, tz),
        Color = COLORS.DarkMetal,
        Material = Enum.Material.DiamondPlate,
        Parent = folder,
    })

    -- Top funnel
    createPart({
        Name = "TradeUpFunnel",
        Size = Vector3.new(6, 2, 4),
        Position = Vector3.new(tx, 7, tz),
        Color = COLORS.Metal,
        Material = Enum.Material.Metal,
        Parent = folder,
    })

    -- Glowing output slot
    local outputSlot = createPart({
        Name = "TradeUpOutput",
        Size = Vector3.new(3, 3, 1),
        Position = Vector3.new(tx, 3, tz - 3.5),
        Color = Color3.fromRGB(0, 200, 255),
        Material = Enum.Material.Neon,
        Transparency = 0.4,
        Parent = folder,
    })
    addLight(outputSlot, { Brightness = 2, Range = 12, Color = Color3.fromRGB(0, 200, 255) })

    -- Sign
    local signPart = createPart({
        Name = "TradeUpSign",
        Size = Vector3.new(1, 1, 1),
        Position = Vector3.new(tx, 10, tz),
        Transparency = 1,
        CanCollide = false,
        Parent = folder,
    })
    addBillboard(signPart, "🔄 TRADE-UP MACHINE", Color3.fromRGB(0, 200, 255), Color3.fromRGB(0, 20, 30), UDim2.new(0, 260, 0, 45))

    -- Pipes connecting to wall
    for _, yOff in ipairs({2, 5}) do
        createPart({
            Name = "Pipe",
            Size = Vector3.new(20, 1, 1),
            Position = Vector3.new(tx - 14, yOff, tz),
            Color = COLORS.Metal,
            Material = Enum.Material.Metal,
            Parent = folder,
        })
    end
end

--------------------------------------------------------------------------------
-- Build: Crate Shop — Southeast
--------------------------------------------------------------------------------

local function buildCrateShop(folder)
    local cx, cz = 25, 20

    -- Display platform
    createPart({
        Name = "CratePlatform",
        Size = Vector3.new(16, 1, 10),
        Position = Vector3.new(cx, 0.5, cz),
        Color = COLORS.DarkMetal,
        Material = Enum.Material.DiamondPlate,
        Parent = folder,
    })

    -- Display crates (3 tiers)
    local crateColors = {
        { Color3.fromRGB(180, 180, 180), "Standard" },
        { Color3.fromRGB(0, 120, 255), "Rare" },
        { Color3.fromRGB(163, 53, 238), "Epic" },
    }

    for i, crateInfo in ipairs(crateColors) do
        local xOff = (i - 2) * 5
        local crate = createPart({
            Name = "DisplayCrate_" .. crateInfo[2],
            Size = Vector3.new(3.5, 3.5, 3.5),
            Position = Vector3.new(cx + xOff, 3.25, cz),
            Color = crateInfo[1],
            Material = Enum.Material.Metal,
            Parent = folder,
        })

        -- Glow
        addLight(crate, { Brightness = 1.5, Range = 8, Color = crateInfo[1] })

        -- Floating particles
        local particles = Instance.new("ParticleEmitter")
        particles.Color = ColorSequence.new(crateInfo[1])
        particles.Size = NumberSequence.new(0.2, 0)
        particles.Lifetime = NumberRange.new(0.5, 1.5)
        particles.Rate = 8
        particles.Speed = NumberRange.new(0.5, 2)
        particles.SpreadAngle = Vector2.new(360, 360)
        particles.LightEmission = 0.8
        particles.Parent = crate

        -- Crate label
        local labelPart = createPart({
            Name = "CrateLabel_" .. crateInfo[2],
            Size = Vector3.new(1, 1, 1),
            Position = Vector3.new(cx + xOff, 6, cz),
            Transparency = 1,
            CanCollide = false,
            Parent = folder,
        })
        addBillboard(labelPart, crateInfo[2], crateInfo[1], Color3.fromRGB(10, 10, 15), UDim2.new(0, 120, 0, 30), Vector3.new(0, 0, 0))
    end

    -- Main sign
    local signPart = createPart({
        Name = "CrateShopSign",
        Size = Vector3.new(1, 1, 1),
        Position = Vector3.new(cx, 10, cz),
        Transparency = 1,
        CanCollide = false,
        Parent = folder,
    })
    addBillboard(signPart, "📦 CRATE SHOP", COLORS.CrateBlue, Color3.fromRGB(5, 10, 25), UDim2.new(0, 220, 0, 45))
end

--------------------------------------------------------------------------------
-- Build: Decorations (furniture, props)
--------------------------------------------------------------------------------

local function buildDecorations(folder)
    -- Filing cabinets along north wall
    for x = -35, 35, 8 do
        createPart({
            Name = "FilingCabinet",
            Size = Vector3.new(3, 6, 2),
            Position = Vector3.new(x, 3, -LOBBY_DEPTH/2 + 3),
            Color = COLORS.Metal,
            Material = Enum.Material.Metal,
            Parent = folder,
        })
    end

    -- Benches near spawn
    for _, zOff in ipairs({-8, 8}) do
        -- Seat
        createPart({
            Name = "Bench",
            Size = Vector3.new(8, 0.5, 2),
            Position = Vector3.new(0, 2, zOff),
            Color = COLORS.Wood,
            Material = Enum.Material.Wood,
            Parent = folder,
        })
        -- Legs
        for _, xOff in ipairs({-3, 3}) do
            createPart({
                Name = "BenchLeg",
                Size = Vector3.new(0.5, 2, 2),
                Position = Vector3.new(xOff, 1, zOff),
                Color = COLORS.DarkMetal,
                Material = Enum.Material.Metal,
                Parent = folder,
            })
        end
    end

    -- Water cooler
    createPart({
        Name = "WaterCoolerBase",
        Size = Vector3.new(2, 4, 2),
        Position = Vector3.new(15, 2, -LOBBY_DEPTH/2 + 4),
        Color = Color3.fromRGB(220, 220, 230),
        Material = Enum.Material.SmoothPlastic,
        Parent = folder,
    })
    local waterTop = createPart({
        Name = "WaterCoolerJug",
        Size = Vector3.new(1.5, 2.5, 1.5),
        Position = Vector3.new(15, 5.25, -LOBBY_DEPTH/2 + 4),
        Color = Color3.fromRGB(150, 200, 255),
        Material = Enum.Material.Glass,
        Transparency = 0.5,
        Parent = folder,
    })

    -- Potted plants in corners
    local plantPositions = {
        Vector3.new(-LOBBY_WIDTH/2 + 4, 0, -LOBBY_DEPTH/2 + 4),
        Vector3.new(LOBBY_WIDTH/2 - 4, 0, -LOBBY_DEPTH/2 + 4),
        Vector3.new(-LOBBY_WIDTH/2 + 4, 0, LOBBY_DEPTH/2 - 4),
        Vector3.new(LOBBY_WIDTH/2 - 4, 0, LOBBY_DEPTH/2 - 4),
    }

    for _, pos in ipairs(plantPositions) do
        -- Pot
        createPart({
            Name = "PlantPot",
            Size = Vector3.new(2.5, 3, 2.5),
            Position = pos + Vector3.new(0, 1.5, 0),
            Color = Color3.fromRGB(140, 80, 50),
            Material = Enum.Material.SmoothPlastic,
            Parent = folder,
        })
        -- Foliage
        createPart({
            Name = "PlantFoliage",
            Size = Vector3.new(3.5, 4, 3.5),
            Position = pos + Vector3.new(0, 5, 0),
            Color = Color3.fromRGB(40, 120, 40),
            Material = Enum.Material.Grass,
            Parent = folder,
        })
    end

    -- Columns (structural pillars)
    local pillarPositions = {
        Vector3.new(-20, LOBBY_HEIGHT / 2, -15),
        Vector3.new(20, LOBBY_HEIGHT / 2, -15),
        Vector3.new(-20, LOBBY_HEIGHT / 2, 15),
        Vector3.new(20, LOBBY_HEIGHT / 2, 15),
    }

    for _, pos in ipairs(pillarPositions) do
        createPart({
            Name = "Pillar",
            Size = Vector3.new(3, LOBBY_HEIGHT, 3),
            Position = pos,
            Color = COLORS.Walls,
            Material = Enum.Material.Concrete,
            Parent = folder,
        })
        -- Pillar cap
        createPart({
            Name = "PillarCap",
            Size = Vector3.new(4, 1, 4),
            Position = pos + Vector3.new(0, LOBBY_HEIGHT / 2 + 0.5, 0),
            Color = COLORS.WallTrim,
            Material = Enum.Material.Wood,
            Parent = folder,
        })
    end

    -- Vent grates on ceiling
    for _, pos in ipairs({Vector3.new(-30, LOBBY_HEIGHT, 0), Vector3.new(30, LOBBY_HEIGHT, 0)}) do
        createPart({
            Name = "VentGrate",
            Size = Vector3.new(4, 0.3, 4),
            Position = pos,
            Color = COLORS.DarkMetal,
            Material = Enum.Material.DiamondPlate,
            Parent = folder,
        })
    end
end

--------------------------------------------------------------------------------
-- Build: Spawn Area
--------------------------------------------------------------------------------

local function buildSpawnArea(folder)
    -- Spawn platform (slightly raised, glowing edges)
    local spawnPlat = createPart({
        Name = "SpawnPlatform",
        Size = Vector3.new(12, 0.3, 12),
        Position = Vector3.new(0, FLOOR_Y + 0.15, 0),
        Color = COLORS.GoldAccent,
        Material = Enum.Material.Neon,
        Transparency = 0.7,
        Parent = folder,
    })

    -- "LOBBY" text on floor
    local floorSign = createPart({
        Name = "LobbyFloorSign",
        Size = Vector3.new(1, 1, 1),
        Position = Vector3.new(0, 2, 0),
        Transparency = 1,
        CanCollide = false,
        Parent = folder,
    })
    addBillboard(floorSign, "THE MAZE OF BRAINROT", COLORS.GoldAccent, Color3.fromRGB(10, 8, 0), UDim2.new(0, 400, 0, 60), Vector3.new(0, 6, 0))
end

--------------------------------------------------------------------------------
-- Configure Lighting
--------------------------------------------------------------------------------

local function configureLighting()
    Lighting.Ambient = Color3.fromRGB(40, 38, 35)
    Lighting.OutdoorAmbient = Color3.fromRGB(30, 28, 25)
    Lighting.Brightness = 0.3
    Lighting.ClockTime = 0    -- Night
    Lighting.FogEnd = 200
    Lighting.FogStart = 100
    Lighting.FogColor = Color3.fromRGB(20, 18, 15)
    Lighting.GlobalShadows = true
    -- Lighting.Technology cannot be set by script at runtime
    -- Lighting.Technology = Enum.Technology.Future
    Lighting.ShadowSoftness = 0.2
    local existing = Lighting:FindFirstChildWhichIsA("Atmosphere")
    if not existing then
        local atmo = Instance.new("Atmosphere")
        atmo.Density = 0.3
        atmo.Offset = 0.1
        atmo.Color = Color3.fromRGB(200, 190, 170)
        atmo.Decay = Color3.fromRGB(40, 35, 30)
        atmo.Glare = 0
        atmo.Haze = 2
        atmo.Parent = Lighting
    end

    -- Bloom for neon glow
    local bloom = Lighting:FindFirstChildWhichIsA("BloomEffect")
    if not bloom then
        bloom = Instance.new("BloomEffect")
        bloom.Intensity = 0.5
        bloom.Size = 24
        bloom.Threshold = 0.8
        bloom.Parent = Lighting
    end

    -- Color correction for warm tones
    local cc = Lighting:FindFirstChildWhichIsA("ColorCorrectionEffect")
    if not cc then
        cc = Instance.new("ColorCorrectionEffect")
        cc.Brightness = 0.02
        cc.Contrast = 0.15
        cc.Saturation = 0.1
        cc.TintColor = Color3.fromRGB(255, 248, 240)
        cc.Parent = Lighting
    end
end

--------------------------------------------------------------------------------
-- PUBLIC: Build the entire lobby
--------------------------------------------------------------------------------

function LobbyBuilder.build()
    print("[LobbyBuilder] Building lobby...")

    -- Create lobby folder
    local folder = Instance.new("Folder")
    folder.Name = "Lobby"
    folder.Parent = Workspace

    buildFloor(folder)
    buildWalls(folder)
    buildCeilingLights(folder)
    buildElevator(folder)
    buildMerchant(folder)
    buildTradeUp(folder)
    buildCrateShop(folder)
    buildDecorations(folder)
    buildSpawnArea(folder)
    configureLighting()

    local partCount = 0
    for _, child in ipairs(folder:GetDescendants()) do
        if child:IsA("BasePart") then partCount += 1 end
    end

    print("[LobbyBuilder] Lobby built! (" .. partCount .. " parts)")
    return folder
end

return LobbyBuilder
