local inventory = exports.ox_inventory

-- ============================================================
-- LOCALE
-- ============================================================
local function L(key)
    local loc = Config.Locales and Config.Locales['en']
    return (loc and loc[key]) or key
end

-- ============================================================
-- DESCRIPTION BUILDER (FIXED: broken plates count)
-- ============================================================
local function FormatBodyArmourDescription(meta, itemName)
    local plates = meta.plates or {}
    local cfg = Config.BodyArmours[itemName] or {}

    local plateCount = #plates

    local maxPlates = cfg.maxPlates or 5
    local refills = meta.refills or 0
    local maxRefills = cfg.maxRefills or 0
    local armour = meta.armour or 0

    return string.format(
        "%s: %d%%\n%s: %d/%d\n%s: %d/%d",
        L('label_armour'),
        armour,
        L('label_plates'),
        plateCount, maxPlates,
        L('label_refills'),
        refills, maxRefills
    )
end

-- ============================================================
-- STACK LIMITER (optional)
-- ============================================================
local function LimitPlateStacking(payload)
    if payload.toSlot then
        local targetItem = inventory:GetSlot(payload.toInventory, payload.toSlot)

        if targetItem and Config.ArmourPlates[targetItem.name] then
            local newTotal = (targetItem.count or 0) + (payload.count or 0)

            if newTotal > 5 then
                TriggerClientEvent('ox_lib:notify', payload.source, {
                    type = 'error',
                    description = L('body_armour_full')
                })
                return false
            end
        end
    end
    return true
end

exports.ox_inventory:registerHook('swapItems', LimitPlateStacking, {
    itemFilter = {
        ['armour_plate'] = true,
        ['improved_armour_plate'] = true,
        ['broken_armour_plate'] = true
    }
})

-- ============================================================
-- BODY ARMOUR MOVEMENT HOOK
-- ============================================================
local function OnBodyArmourMoved(payload)
    if not payload or not payload.source then return true end

    local ok, err = pcall(function()
        local src = payload.source

        if payload.fromInventory == src and payload.toInventory ~= src then
            local itemData = inventory:GetSlot(src, payload.fromSlot)
            if not itemData or not Config.BodyArmours[itemData.name] then return end

            local meta = itemData.metadata or {}
            meta.plates = meta.plates or {}
            meta.refills = meta.refills or 0
            meta.armour = meta.armour or 0

            payload.metadata = meta

            TriggerClientEvent('armour:clientForceStrip', src)
        end

        if payload.toInventory == src then
            SetTimeout(200, function()
                TriggerClientEvent('armour:clientBodyArmourAcquired', src)
            end)
        end
    end)

    if not ok then
        print('^1[ARMOUR ERROR] Hook failed: ' .. tostring(err) .. '^7')
    end

    return true
end

exports.ox_inventory:registerHook('swapItems', OnBodyArmourMoved, {
    itemFilter = {
        ['body_armour'] = true,
        ['heavy_body_armour'] = true,
        ['improved_body_armour'] = true,
        ['pd_body_armour'] = true
    }
})

exports.ox_inventory:registerHook('removeItem', OnBodyArmourMoved, {
    itemFilter = {
        ['body_armour'] = true,
        ['heavy_body_armour'] = true,
        ['improved_body_armour'] = true,
        ['pd_body_armour'] = true
    }
})

exports.ox_inventory:registerHook('dropItem', OnBodyArmourMoved, {
    itemFilter = {
        ['body_armour'] = true,
        ['heavy_body_armour'] = true,
        ['improved_body_armour'] = true,
        ['pd_body_armour'] = true
    }
})

-- ============================================================
-- REMOVE PLATE AFTER USE
-- ============================================================
RegisterNetEvent('armour:server:completedPlateUse', function(slot)
    local src = source
    if not slot then return end

    local item = inventory:GetSlot(src, slot)
    if item and Config.ArmourPlates[item.name] then
        inventory:RemoveItem(src, item.name, 1, nil, slot)
    else
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = L('armour_plate_validation')
        })
    end
end)

-- ============================================================
-- RETURN PLATE WHEN PULLED
-- ============================================================
RegisterNetEvent('armour:returnArmourItem', function(durability, originalItemName)
    local src = source
    durability = tonumber(durability) or 0
    originalItemName = originalItemName

    local items = exports.ox_inventory:Items()
    local baseLabel = (items[originalItemName] and items[originalItemName].label) or 'Armour Plate'

    local giveItem = originalItemName
    local meta = {
        durability = durability
    }

    if durability <= 0 then
        giveItem = 'broken_armour_plate'
        meta.label = 'Broken ' .. baseLabel
        meta.description = 'A Broken ' .. baseLabel .. '.'
    end

    inventory:AddItem(src, giveItem, 1, meta)
end)

-- ============================================================
-- UPDATE BODY ARMOUR METADATA
-- ============================================================
RegisterNetEvent('armour:updateBodyArmourMetadata', function(slot, plates, refills)
    local src = source
    if not slot then return end

    local item = inventory:GetSlot(src, slot)
    if not item or not Config.BodyArmours[item.name] then return end

    local meta = item.metadata or {}
    meta.plates = plates or meta.plates or {}
    meta.refills = refills or meta.refills or 0

    local total = 0
    for _, plate in ipairs(meta.plates) do
        if plate.durability and plate.durability > 0 then
            total = total + plate.durability
        end
    end
    if total > 100 then total = 100 end
    meta.armour = total

    meta.description = FormatBodyArmourDescription(meta, item.name)

    inventory:SetMetadata(src, slot, meta)
end)

-- ============================================================
-- CLEAR BODY ARMOUR METADATA
-- ============================================================
RegisterNetEvent('armour:nilBodyArmourMetadata', function(slot)
    local src = source
    if not slot then return end

    local item = inventory:GetSlot(src, slot)
    if not item or not Config.BodyArmours[item.name] then return end

    local meta = item.metadata or {}
    meta.plates = {}
    meta.armour = 0

    meta.description = FormatBodyArmourDescription(meta, item.name)

    inventory:SetMetadata(src, slot, meta)
end)

