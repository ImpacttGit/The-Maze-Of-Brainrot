--[[
    TestRunner.lua
    ==============
    Assertion-based test suite for Phase 1: Global Loot & Rarity Module.
    
    HOW TO USE:
    1. Sync/copy all modules into Roblox Studio under ReplicatedStorage.Modules
    2. Place this script into ServerScriptService (as a Script, not ModuleScript)
    3. Run the game — test results print to the Output window
    
    Alternatively, paste the contents into Studio's Command Bar
    (adjust require paths if needed).
]]

-- Adjust these paths to match your Studio hierarchy
local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Data = Modules:WaitForChild("Data")
local Services = Modules:WaitForChild("Services")

local RarityConfig = require(Data:WaitForChild("RarityConfig"))
local ItemDatabase = require(Data:WaitForChild("ItemDatabase"))
local LootService = require(Services:WaitForChild("LootService"))
local InventoryService = require(Services:WaitForChild("InventoryService"))
local FragmentService = require(Services:WaitForChild("FragmentService"))
local TradeUpService = require(Services:WaitForChild("TradeUpService"))

--------------------------------------------------------------------------------
-- Test Framework
--------------------------------------------------------------------------------

local totalTests = 0
local passedTests = 0
local failedTests = 0

local function test(name: string, fn: () -> ())
    totalTests += 1
    local success, err = pcall(fn)
    if success then
        passedTests += 1
        print("  ✅ PASS: " .. name)
    else
        failedTests += 1
        warn("  ❌ FAIL: " .. name .. " — " .. tostring(err))
    end
end

local function section(name: string)
    print("\n" .. string.rep("=", 60))
    print("📦 " .. name)
    print(string.rep("=", 60))
end

--------------------------------------------------------------------------------
-- 1. RarityConfig Tests
--------------------------------------------------------------------------------

section("RarityConfig")

test("All 4 rarity tiers exist", function()
    assert(RarityConfig.Tiers.Common, "Missing Common tier")
    assert(RarityConfig.Tiers.Rare, "Missing Rare tier")
    assert(RarityConfig.Tiers.Epic, "Missing Epic tier")
    assert(RarityConfig.Tiers.Legendary, "Missing Legendary tier")
end)

test("OrderedTiers has 4 entries in correct order", function()
    assert(#RarityConfig.OrderedTiers == 4, "Expected 4 ordered tiers")
    assert(RarityConfig.OrderedTiers[1] == "Common")
    assert(RarityConfig.OrderedTiers[2] == "Rare")
    assert(RarityConfig.OrderedTiers[3] == "Epic")
    assert(RarityConfig.OrderedTiers[4] == "Legendary")
end)

test("Each tier has required fields", function()
    for _, tierName in ipairs(RarityConfig.OrderedTiers) do
        local tier = RarityConfig.Tiers[tierName]
        assert(tier.Name == tierName, tierName .. " Name mismatch")
        assert(type(tier.Order) == "number", tierName .. " missing Order")
        assert(typeof(tier.OutlineColor) == "Color3", tierName .. " missing OutlineColor")
        assert(type(tier.MinValue) == "number", tierName .. " missing MinValue")
        assert(type(tier.MaxValue) == "number", tierName .. " missing MaxValue")
        assert(type(tier.SpawnWeight) == "number", tierName .. " missing SpawnWeight")
    end
end)

test("Tier Order is sequential (1-4)", function()
    for i, tierName in ipairs(RarityConfig.OrderedTiers) do
        assert(RarityConfig.Tiers[tierName].Order == i, tierName .. " has wrong Order")
    end
end)

test("getNextTier returns correct next tiers", function()
    assert(RarityConfig.getNextTier("Common") == "Rare")
    assert(RarityConfig.getNextTier("Rare") == "Epic")
    assert(RarityConfig.getNextTier("Epic") == "Legendary")
    assert(RarityConfig.getNextTier("Legendary") == nil)
end)

test("Epic cannot trade up FROM", function()
    assert(RarityConfig.Tiers.Epic.CanTradeUpFrom == false,
        "Epic should not allow trading up from")
end)

test("Legendary cannot be traded up TO", function()
    assert(RarityConfig.Tiers.Legendary.CanTradeUpTo == false,
        "Legendary should not allow trading up to")
end)

--------------------------------------------------------------------------------
-- 2. ItemDatabase Tests
--------------------------------------------------------------------------------

section("ItemDatabase")

test("Contains 12 Common items", function()
    assert(ItemDatabase.getCountByRarity("Common") == 12,
        "Expected 12 Common items, got " .. ItemDatabase.getCountByRarity("Common"))
end)

test("Contains 10 Rare items", function()
    assert(ItemDatabase.getCountByRarity("Rare") == 10,
        "Expected 10 Rare items, got " .. ItemDatabase.getCountByRarity("Rare"))
end)

test("Contains 7 Epic items", function()
    assert(ItemDatabase.getCountByRarity("Epic") == 7,
        "Expected 7 Epic items, got " .. ItemDatabase.getCountByRarity("Epic"))
end)

test("Contains 5 Legendary items", function()
    assert(ItemDatabase.getCountByRarity("Legendary") == 5,
        "Expected 5 Legendary items, got " .. ItemDatabase.getCountByRarity("Legendary"))
end)

test("Total item count is 34", function()
    local total = 0
    for _ in pairs(ItemDatabase.Items) do
        total += 1
    end
    assert(total == 34, "Expected 34 total items, got " .. total)
end)

test("All items reference a valid rarity key", function()
    for itemId, itemData in pairs(ItemDatabase.Items) do
        assert(RarityConfig.Tiers[itemData.Rarity],
            itemId .. " has invalid rarity: " .. tostring(itemData.Rarity))
    end
end)

test("All Epic items have a PowerUp defined", function()
    for itemId, itemData in pairs(ItemDatabase.Items) do
        if itemData.Rarity == "Epic" then
            assert(itemData.PowerUp and itemData.PowerUp.Type,
                itemId .. " is Epic but missing PowerUp.Type")
        end
    end
end)

test("All Legendary items are followers", function()
    for itemId, itemData in pairs(ItemDatabase.Items) do
        if itemData.Rarity == "Legendary" then
            assert(itemData.IsFollower == true,
                itemId .. " is Legendary but not a follower")
            assert(itemData.FollowerInfo,
                itemId .. " is Legendary but missing FollowerInfo")
        end
    end
end)

test("getItem returns correct data for 'pen'", function()
    local pen = ItemDatabase.getItem("pen")
    assert(pen, "pen not found")
    assert(pen.DisplayName == "Pen")
    assert(pen.Rarity == "Common")
end)

test("getItem returns nil for nonexistent item", function()
    local nope = ItemDatabase.getItem("nonexistent_item_xyz")
    assert(nope == nil, "Expected nil for nonexistent item")
end)

--------------------------------------------------------------------------------
-- 3. LootService Tests
--------------------------------------------------------------------------------

section("LootService")

test("rollRarity returns a valid rarity string", function()
    for i = 1, 50 do
        local rarity = LootService.rollRarity()
        assert(RarityConfig.Tiers[rarity],
            "rollRarity returned invalid rarity: " .. tostring(rarity))
    end
end)

test("generateItem produces valid item instances", function()
    for i = 1, 20 do
        local item = LootService.generateItem()
        assert(item.UniqueId, "Missing UniqueId")
        assert(item.ItemId, "Missing ItemId")
        assert(item.DisplayName, "Missing DisplayName")
        assert(item.Rarity, "Missing Rarity")
        assert(type(item.FragmentValue) == "number", "FragmentValue is not a number")
    end
end)

test("generateItem respects rarity value ranges", function()
    for _, tierName in ipairs(RarityConfig.OrderedTiers) do
        local tier = RarityConfig.Tiers[tierName]
        for i = 1, 10 do
            local item = LootService.generateItem(tierName)
            assert(item.Rarity == tierName,
                "Expected " .. tierName .. " but got " .. item.Rarity)
            if tier.MaxValue > 0 then
                assert(item.FragmentValue >= tier.MinValue,
                    tierName .. " value below min: " .. item.FragmentValue)
                assert(item.FragmentValue <= tier.MaxValue,
                    tierName .. " value above max: " .. item.FragmentValue)
            else
                assert(item.FragmentValue == 0,
                    tierName .. " should have 0 value, got " .. item.FragmentValue)
            end
        end
    end
end)

test("generateItem with rarityOverride forces correct rarity", function()
    local item = LootService.generateItem("Legendary")
    assert(item.Rarity == "Legendary", "Override to Legendary failed")
    assert(item.FragmentValue == 0, "Legendary should have 0 fragments")
end)

test("generateLootTable returns correct number of items", function()
    local loot = LootService.generateLootTable(15)
    assert(#loot == 15, "Expected 15 items, got " .. #loot)
end)

test("Each generated item has a unique UniqueId", function()
    local loot = LootService.generateLootTable(50)
    local seen = {}
    for _, item in ipairs(loot) do
        assert(not seen[item.UniqueId],
            "Duplicate UniqueId found: " .. item.UniqueId)
        seen[item.UniqueId] = true
    end
end)

--------------------------------------------------------------------------------
-- 4. InventoryService Tests
--------------------------------------------------------------------------------

section("InventoryService")

test("new() creates empty inventory with 0 count", function()
    local inv = InventoryService.new()
    assert(inv:getCount() == 0, "New inventory should have 0 items")
end)

test("addItem increases count", function()
    local inv = InventoryService.new()
    local item = LootService.generateItem("Common")
    local added = inv:addItem(item)
    assert(added == true, "addItem should return true")
    assert(inv:getCount() == 1, "Count should be 1")
end)

test("addItem rejects duplicate UniqueId", function()
    local inv = InventoryService.new()
    local item = LootService.generateItem("Common")
    inv:addItem(item)
    local added = inv:addItem(item) -- Same UniqueId
    assert(added == false, "Duplicate add should return false")
    assert(inv:getCount() == 1, "Count should still be 1")
end)

test("removeItem removes and returns the item", function()
    local inv = InventoryService.new()
    local item = LootService.generateItem("Common")
    inv:addItem(item)
    local removed = inv:removeItem(item.UniqueId)
    assert(removed, "removeItem should return the item")
    assert(removed.UniqueId == item.UniqueId)
    assert(inv:getCount() == 0)
end)

test("removeItem returns nil for nonexistent item", function()
    local inv = InventoryService.new()
    local removed = inv:removeItem("fake-id-123")
    assert(removed == nil, "Should return nil for nonexistent item")
end)

test("getItemsByRarity filters correctly", function()
    local inv = InventoryService.new()
    for i = 1, 5 do
        inv:addItem(LootService.generateItem("Common"))
    end
    for i = 1, 3 do
        inv:addItem(LootService.generateItem("Rare"))
    end
    local commons = inv:getItemsByRarity("Common")
    local rares = inv:getItemsByRarity("Rare")
    assert(#commons == 5, "Expected 5 Commons, got " .. #commons)
    assert(#rares == 3, "Expected 3 Rares, got " .. #rares)
end)

test("clearNonLegendary keeps only Legendaries", function()
    local inv = InventoryService.new()
    for i = 1, 3 do
        inv:addItem(LootService.generateItem("Common"))
    end
    for i = 1, 2 do
        inv:addItem(LootService.generateItem("Legendary"))
    end
    assert(inv:getCount() == 5, "Should have 5 items before clear")
    local removed = inv:clearNonLegendary()
    assert(#removed == 3, "Should remove 3 non-Legendary items")
    assert(inv:getCount() == 2, "Should keep 2 Legendaries")
end)

test("serialize and deserialize round-trip", function()
    local inv = InventoryService.new()
    for i = 1, 5 do
        inv:addItem(LootService.generateItem("Common"))
    end
    inv:addItem(LootService.generateItem("Legendary"))

    local data = inv:serialize()
    local restored = InventoryService.deserialize(data)

    assert(restored:getCount() == 6,
        "Restored inventory should have 6 items, got " .. restored:getCount())
end)

--------------------------------------------------------------------------------
-- 5. FragmentService Tests
--------------------------------------------------------------------------------

section("FragmentService")

test("getBalance returns 0 for new player", function()
    local pd = { fragments = 0 }
    assert(FragmentService.getBalance(pd) == 0)
end)

test("addFragments increases balance", function()
    local pd = { fragments = 100 }
    local newBal = FragmentService.addFragments(pd, 250)
    assert(newBal == 350, "Expected 350, got " .. newBal)
    assert(pd.fragments == 350)
end)

test("spendFragments succeeds with sufficient balance", function()
    local pd = { fragments = 500 }
    local success = FragmentService.spendFragments(pd, 200)
    assert(success == true, "Should succeed")
    assert(pd.fragments == 300, "Expected 300, got " .. pd.fragments)
end)

test("spendFragments fails with insufficient balance", function()
    local pd = { fragments = 50 }
    local success = FragmentService.spendFragments(pd, 100)
    assert(success == false, "Should fail")
    assert(pd.fragments == 50, "Balance should be unchanged")
end)

test("sellItem earns correct Fragments for Common", function()
    local pd = { fragments = 0 }
    local item = LootService.generateItem("Common")
    local earned, success = FragmentService.sellItem(pd, item)
    assert(success == true, "Should succeed")
    assert(earned == item.FragmentValue, "Earned should match item value")
    assert(pd.fragments == item.FragmentValue)
end)

test("sellItem returns 0 and false for Legendary", function()
    local pd = { fragments = 0 }
    local item = LootService.generateItem("Legendary")
    local earned, success = FragmentService.sellItem(pd, item)
    assert(success == false, "Legendary sell should fail")
    assert(earned == 0, "Legendary should earn 0 Fragments")
    assert(pd.fragments == 0, "Balance should remain 0")
end)

test("sellBulk skips Legendaries", function()
    local pd = { fragments = 0 }
    local items = {
        LootService.generateItem("Common"),
        LootService.generateItem("Common"),
        LootService.generateItem("Legendary"),
    }
    local totalEarned, soldCount = FragmentService.sellBulk(pd, items)
    assert(soldCount == 2, "Should sell 2 items, not " .. soldCount)
    assert(totalEarned > 0, "Should earn some Fragments")
end)

--------------------------------------------------------------------------------
-- 6. TradeUpService Tests
--------------------------------------------------------------------------------

section("TradeUpService")

test("canTradeUp succeeds with 5 identical Common items", function()
    local items = {}
    for i = 1, 5 do
        table.insert(items, { ItemId = "pen", Rarity = "Common" })
    end
    local canDo, err = TradeUpService.canTradeUp(items)
    assert(canDo == true, "Should succeed: " .. tostring(err))
end)

test("canTradeUp fails with < 5 items", function()
    local items = {}
    for i = 1, 3 do
        table.insert(items, { ItemId = "pen", Rarity = "Common" })
    end
    local canDo, err = TradeUpService.canTradeUp(items)
    assert(canDo == false, "Should fail with 3 items")
    assert(err, "Should have error message")
end)

test("canTradeUp fails with mismatched ItemIds", function()
    local items = {
        { ItemId = "pen", Rarity = "Common" },
        { ItemId = "pen", Rarity = "Common" },
        { ItemId = "pencil", Rarity = "Common" },
        { ItemId = "pen", Rarity = "Common" },
        { ItemId = "pen", Rarity = "Common" },
    }
    local canDo, err = TradeUpService.canTradeUp(items)
    assert(canDo == false, "Should fail with mixed items")
end)

test("canTradeUp fails for Epic → Legendary (blocked)", function()
    local items = {}
    for i = 1, 5 do
        table.insert(items, { ItemId = "powerbank", Rarity = "Epic" })
    end
    local canDo, err = TradeUpService.canTradeUp(items)
    assert(canDo == false, "Epic → Legendary should be blocked")
end)

test("canTradeUp succeeds for Rare → Epic", function()
    local items = {}
    for i = 1, 5 do
        table.insert(items, { ItemId = "mouse", Rarity = "Rare" })
    end
    local canDo, err = TradeUpService.canTradeUp(items)
    assert(canDo == true, "Rare → Epic should be allowed: " .. tostring(err))
end)

test("executeTradeUp produces item of next tier", function()
    local inv = InventoryService.new()
    local items = {}
    for i = 1, 5 do
        local item = LootService.generateItem("Common")
        -- Force same ItemId for test
        item.ItemId = "pen"
        item.Rarity = "Common"
        inv:addItem(item)
        table.insert(items, item)
    end

    assert(inv:getCount() == 5, "Should start with 5")
    local result, err = TradeUpService.executeTradeUp(inv, items, LootService)
    assert(result, "Should produce a result item: " .. tostring(err))
    assert(result.Rarity == "Rare", "Result should be Rare, got " .. result.Rarity)
    -- 5 removed, 1 added = 1 remaining
    assert(inv:getCount() == 1, "Should have 1 item after trade-up, got " .. inv:getCount())
end)

--------------------------------------------------------------------------------
-- Summary
--------------------------------------------------------------------------------

print("\n" .. string.rep("=", 60))
print(string.format("🏁 TEST RESULTS: %d/%d passed (%d failed)",
    passedTests, totalTests, failedTests))
print(string.rep("=", 60))

if failedTests > 0 then
    warn("⚠️  Some tests failed! Check the output above for details.")
else
    print("🎉 All tests passed! Phase 1 modules are good to go.")
end
