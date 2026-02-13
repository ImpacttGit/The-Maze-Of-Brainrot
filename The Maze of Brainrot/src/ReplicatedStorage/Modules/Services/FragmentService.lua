--[[
    FragmentService.lua
    ===================
    Manages the Fragment currency for The Maze of Brainrot.
    
    Fragments are the primary currency earned by selling collected items.
    Legendaries cannot be sold (they return 0 Fragments).
    
    Operates on a plain playerData table:
        playerData = { fragments = 0 }
    
    Future phases will wire this into DataStore persistence.
]]

local FragmentService = {}

--------------------------------------------------------------------------------
-- Get the current Fragment balance
-- @param playerData (table) — Player's data table with a `fragments` field
-- @return number — Current balance
--------------------------------------------------------------------------------

function FragmentService.getBalance(playerData: any): number
    assert(playerData, "playerData is required")
    return playerData.fragments or 0
end

--------------------------------------------------------------------------------
-- Add Fragments to the player's balance
-- @param playerData (table) — Player's data table
-- @param amount (number) — Amount to add (must be >= 0)
-- @return number — New balance after addition
--------------------------------------------------------------------------------

function FragmentService.addFragments(playerData: any, amount: number): number
    assert(playerData, "playerData is required")
    assert(amount >= 0, "Cannot add negative Fragments")

    playerData.fragments = (playerData.fragments or 0) + amount
    return playerData.fragments
end

--------------------------------------------------------------------------------
-- Spend Fragments from the player's balance
-- @param playerData (table) — Player's data table
-- @param amount (number) — Amount to spend (must be >= 0)
-- @return boolean — true if transaction succeeded, false if insufficient funds
--------------------------------------------------------------------------------

function FragmentService.spendFragments(playerData: any, amount: number): boolean
    assert(playerData, "playerData is required")
    assert(amount >= 0, "Cannot spend negative Fragments")

    local currentBalance = playerData.fragments or 0
    if currentBalance < amount then
        return false
    end

    playerData.fragments = currentBalance - amount
    return true
end

--------------------------------------------------------------------------------
-- Sell an item for its Fragment value
-- Legendaries are non-sellable and return 0
-- @param playerData (table) — Player's data table
-- @param itemInstance (table) — The item instance to sell
-- @return number — Fragments earned from the sale (0 for Legendaries)
-- @return boolean — false if the item is a Legendary (cannot be sold)
--------------------------------------------------------------------------------

function FragmentService.sellItem(playerData: any, itemInstance: any): (number, boolean)
    assert(playerData, "playerData is required")
    assert(itemInstance, "itemInstance is required")

    -- Legendaries cannot be sold
    if itemInstance.Rarity == "Legendary" then
        return 0, false
    end

    local value = itemInstance.FragmentValue or 0
    FragmentService.addFragments(playerData, value)

    return value, true
end

--------------------------------------------------------------------------------
-- Sell multiple items at once and return total Fragments earned
-- Skips Legendaries automatically
-- @param playerData (table) — Player's data table
-- @param items ({ table }) — Array of item instances to sell
-- @return number — Total Fragments earned
-- @return number — Number of items successfully sold
--------------------------------------------------------------------------------

function FragmentService.sellBulk(playerData: any, items: { any }): (number, number)
    assert(playerData, "playerData is required")
    assert(items, "items array is required")

    local totalEarned = 0
    local soldCount = 0

    for _, item in ipairs(items) do
        local earned, success = FragmentService.sellItem(playerData, item)
        if success then
            totalEarned += earned
            soldCount += 1
        end
    end

    return totalEarned, soldCount
end

return FragmentService
