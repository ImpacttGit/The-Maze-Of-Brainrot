# The Maze of Brainrot

**Genre:** Survival Horror / Loot-Extraction / Collection  
**Platform:** Roblox  
**Aesthetic:** Liminal Space / Nostalgic Office / "Backrooms"

## Project Structure

```
src/
├── ServerScriptService/         # Server-only Scripts
├── ReplicatedStorage/           # Shared modules (client + server)
│   └── Modules/
│       ├── Data/                # Pure data/config ModuleScripts
│       │   ├── RarityConfig.lua
│       │   └── ItemDatabase.lua
│       └── Services/            # Logic ModuleScripts
│           ├── LootService.lua
│           ├── InventoryService.lua
│           ├── FragmentService.lua
│           └── TradeUpService.lua
├── StarterPlayerScripts/        # Client-side LocalScripts
└── ServerStorage/               # Server-only assets
tests/
└── TestRunner.lua               # Assertion-based test suite
```

## Setup

### Option A: Rojo (Recommended)
1. Install [Rojo](https://rojo.space/) and create a `default.project.json` mapping `src/` to your Roblox containers.
2. Run `rojo serve` and connect from Roblox Studio.

### Option B: Manual
1. Open Roblox Studio.
2. For each file in `src/`, create a matching ModuleScript/Script in the corresponding Explorer container.
3. Copy-paste the Luau source code into each script.

## Lighting
This project uses **Future** lighting technology. Set `Lighting.Technology = Enum.Technology.Future` in Studio.
