--[[
    InventoryService.lua
    ====================
    Per-player inventory management for The Maze of Brainrot.
    
    Operates on plain Luau tables (not DataStore — that comes in a later phase).
    Provides add, remove, query, and serialization methods.
    
    Usage:
        local inv = InventoryService.new()
        inv:addItem(itemInstance)
        local items = inv:getItemsByRarity("Rare")
        local data = inv:serialize()
        local restored = InventoryService.deserialize(data)
]]

local InventoryService = {}
InventoryService.__index = InventoryService

--------------------------------------------------------------------------------
-- Constructor: create a new empty inventory
-- @return Inventory object
--------------------------------------------------------------------------------

function InventoryService.new()
    local self = setmetatable({}, InventoryService)

    -- Items stored by UniqueId for O(1) lookup
    self._items = {} -- { [UniqueId] = ItemInstance }
    self._count = 0

    return self
end

--------------------------------------------------------------------------------
-- Add an item instance to the inventory
-- @param itemInstance — The item to add (must have UniqueId)
-- @return boolean — true if added successfully
--------------------------------------------------------------------------------

function InventoryService:addItem(itemInstance): boolean
    assert(itemInstance and itemInstance.UniqueId, "Item must have a UniqueId")

    -- Prevent duplicates
    if self._items[itemInstance.UniqueId] then
        warn("[InventoryService] Duplicate UniqueId: " .. itemInstance.UniqueId)
        return false
    end

    self._items[itemInstance.UniqueId] = itemInstance
    self._count += 1
    return true
end

--------------------------------------------------------------------------------
-- Remove an item from the inventory by UniqueId
-- @param uniqueId (string) — The UniqueId of the item to remove
-- @return ItemInstance? — The removed item, or nil if not found
--------------------------------------------------------------------------------

function InventoryService:removeItem(uniqueId: string): any?
    local item = self._items[uniqueId]
    if not item then
        return nil
    end

    self._items[uniqueId] = nil
    self._count -= 1
    return item
end

--------------------------------------------------------------------------------
-- Get an item by its UniqueId
-- @param uniqueId (string)
-- @return ItemInstance?
--------------------------------------------------------------------------------

function InventoryService:getItem(uniqueId: string): any?
    return self._items[uniqueId]
end

--------------------------------------------------------------------------------
-- Get all items as a flat array
-- @return { ItemInstance }
--------------------------------------------------------------------------------

function InventoryService:getAllItems(): { any }
    local result = {}
    for _, item in pairs(self._items) do
        table.insert(result, item)
    end
    return result
end

--------------------------------------------------------------------------------
-- Get all items matching a specific rarity
-- @param rarity (string) — Rarity tier name
-- @return { ItemInstance }
--------------------------------------------------------------------------------

function InventoryService:getItemsByRarity(rarity: string): { any }
    local result = {}
    for _, item in pairs(self._items) do
        if item.Rarity == rarity then
            table.insert(result, item)
        end
    end
    return result
end

--------------------------------------------------------------------------------
-- Get all items matching a specific ItemId
-- @param itemId (string) — The item definition ID (e.g. "pen")
-- @return { ItemInstance }
--------------------------------------------------------------------------------

function InventoryService:getItemsByItemId(itemId: string): { any }
    local result = {}
    for _, item in pairs(self._items) do
        if item.ItemId == itemId then
            table.insert(result, item)
        end
    end
    return result
end

--------------------------------------------------------------------------------
-- Get the current number of items in the inventory
-- @return number
--------------------------------------------------------------------------------

function InventoryService:getCount(): number
    return self._count
end

--------------------------------------------------------------------------------
-- Check if the inventory contains an item with the given UniqueId
-- @param uniqueId (string)
-- @return boolean
--------------------------------------------------------------------------------

function InventoryService:hasItem(uniqueId: string): boolean
    return self._items[uniqueId] ~= nil
end

--------------------------------------------------------------------------------
-- Clear all non-Legendary items (used on death / failed run)
-- Legendaries are permanent and survive death
-- @return { ItemInstance } — Array of items that were removed
--------------------------------------------------------------------------------

function InventoryService:clearNonLegendary(): { any }
    local removed = {}
    for uniqueId, item in pairs(self._items) do
        if item.Rarity ~= "Legendary" then
            table.insert(removed, item)
            self._items[uniqueId] = nil
            self._count -= 1
        end
    end
    return removed
end

--------------------------------------------------------------------------------
-- Serialize the inventory to a plain table for DataStore saving
-- @return { [string]: any } — Serialized data
--------------------------------------------------------------------------------

function InventoryService:serialize(): { [string]: any }
    local data = {
        items = {},
    }

    for uniqueId, item in pairs(self._items) do
        -- Store a clean copy without any metatables
        data.items[uniqueId] = {
            UniqueId = item.UniqueId,
            ItemId = item.ItemId,
            DisplayName = item.DisplayName,
            Rarity = item.Rarity,
            FragmentValue = item.FragmentValue,
            IsFollower = item.IsFollower,
            -- PowerUp is not serialized — it's derived from ItemDatabase on load
        }
    end

    return data
end

--------------------------------------------------------------------------------
-- Deserialize a saved data table back into an Inventory object
-- @param data — A table previously returned by :serialize()
-- @return Inventory
--------------------------------------------------------------------------------

function InventoryService.deserialize(data: { [string]: any })
    local inv = InventoryService.new()

    if data and data.items then
        for _, itemData in pairs(data.items) do
            inv:addItem(itemData)
        end
    end

    return inv
end

return InventoryService
