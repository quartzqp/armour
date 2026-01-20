local inventory = exports.ox_inventory

local function T(key)
    return (Config.Locales and Config.Locales["en"] and Config.Locales["en"][key]) or key
end

local function FormatRigDescription(armour, plates, refills)
    armour = math.floor(armour or 0)
    plates = plates or 0
    refills = refills or 0

    local maxRefills = Config.RefillCapacity or 30
    local maxActive = Config.PlateSlotLimit or 5

    local labelA = Config.Locales['en']['label_armour'] or 'Armour'
    local labelP = Config.Locales['en']['label_plates'] or 'Plates'
    local labelR = Config.Locales['en']['label_refills'] or 'Refills'

    return table.concat({
        string.format('%s: %d%%', labelA, armour),
        string.format('%s: %d/%d', labelP, plates, maxActive),
        string.format('%s: %d/%d', labelR, refills, maxRefills)
    }, "\n")
end

-- -------------------------------------------------------------------------- --
--                           STACK LIMITER HOOK                               --
-- -------------------------------------------------------------------------- --

local function LimitPlateStacking(payload)
    if payload.toSlot then
        local targetItem = inventory:GetSlot(payload.toInventory, payload.toSlot)
        if targetItem and targetItem.name == 'armour_plate' then
            local newTotal = (targetItem.count or 0) + (payload.count or 0)
            if newTotal > 5 then
                TriggerClientEvent('ox_lib:notify', payload.source, {
                    type = 'error',
                    description = T('plate_carrier_full')
                })
                return false
            end
        end
    end
    return true
end

exports.ox_inventory:registerHook('swapItems', LimitPlateStacking, {
    itemFilter = { ['armour_plate'] = true }
})

-- -------------------------------------------------------------------------- --
--                           RIG PERSISTENCE HOOK                             --
-- -------------------------------------------------------------------------- --

local function OnRigMoved(payload)
    if not payload or not payload.source then return true end

    local ok, err = pcall(function()
        local src = payload.source

        -- 1) moving OUT of player inventory (drop/give/stash)
        if payload.fromInventory == src and payload.toInventory ~= src then
            local itemData = inventory:GetSlot(src, payload.fromSlot)
            if not itemData or itemData.name ~= 'body_armour' then return end

            local meta = itemData.metadata or {}
            local platesInside = meta.plates or 0
            local savedArmour = meta.savedArmour or 0
            local refills = meta.refills or 0

            local rigCount = inventory:GetItemCount(src, 'body_armour') or 0

            local shouldStrip = false
            if rigCount <= 1 then
                shouldStrip = true
            elseif platesInside > 0 then
                shouldStrip = true
            elseif savedArmour > 0 then
                shouldStrip = true
            end

            if shouldStrip then
                local ped = GetPlayerPed(src)
                local currentArmour = GetPedArmour(ped)

                payload.metadata = payload.metadata or {}
                payload.metadata.plates = payload.metadata.plates or platesInside
                payload.metadata.refills = payload.metadata.refills or refills

                payload.metadata.savedArmour = currentArmour
                payload.metadata.description = FormatRigDescription(
                    currentArmour,
                    payload.metadata.plates,
                    payload.metadata.refills
                )

                SetPedArmour(ped, 0)
                TriggerClientEvent('armour:serverForceStrip', src)
            end
        end

        -- 2) moving INTO player inventory (equip)
        if payload.toInventory == src then
            SetTimeout(200, function()
                TriggerClientEvent('armour:rigAcquired', src)
            end)
        end
    end)

    if not ok then
        print('^1[ARMOUR ERROR] Hook failed: ' .. tostring(err) .. '^7')
    end

    return true
end

exports.ox_inventory:registerHook('swapItems', OnRigMoved, {
    itemFilter = { ['body_armour'] = true }
})

-- -------------------------------------------------------------------------- --
--                                  EVENTS                                    --
-- -------------------------------------------------------------------------- --

RegisterNetEvent('armour:server:completedPlateUse', function(slot)
    local src = source
    if not slot then return end

    local item = inventory:GetSlot(src, slot)
    if item and item.name == 'armour_plate' then
        inventory:RemoveItem(src, 'armour_plate', 1, nil, slot)
    else
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = T('plate_validation') })
    end
end)

RegisterNetEvent('armour:returnArmourItem', function(armourValue, label, image)
    local src = source
    armourValue = tonumber(armourValue) or 0
    if armourValue <= 0 then return end

    local metadata = {
        durability = math.floor(armourValue),
        label = label or 'Armour Plate',
        image = image or 'armour_plate'
    }

    if inventory:CanCarryItem(src, 'armour_plate', 1, metadata) then
        inventory:AddItem(src, 'armour_plate', 1, metadata)
    else
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = T('inventory_full') })
    end
end)

RegisterNetEvent('armour:updateRigMetadata', function(slot, label, image, armourValue, plates, refills)
    local src = source
    if not slot then return end

    local item = inventory:GetSlot(src, slot)
    if not item or item.name ~= 'body_armour' then return end

    local newMetadata = item.metadata or {}
    newMetadata.lastPlateLabel = label
    newMetadata.lastPlateImage = image
    newMetadata.savedArmour = tonumber(armourValue) or 0

    newMetadata.plates = plates or newMetadata.plates or 0
    newMetadata.refills = refills or newMetadata.refills or 0

    newMetadata.description = FormatRigDescription(newMetadata.savedArmour, newMetadata.plates, newMetadata.refills)
    inventory:SetMetadata(src, slot, newMetadata)
end)

RegisterNetEvent('armour:nilRigMetadata', function(slot)
    local src = source
    if not slot then return end

    local item = inventory:GetSlot(src, slot)
    if not item or item.name ~= 'body_armour' then return end

    local newMetadata = item.metadata or {}
    local plates = newMetadata.plates or 0
    local refills = newMetadata.refills or 0

    newMetadata.lastPlateLabel = nil
    newMetadata.lastPlateImage = nil
    newMetadata.savedArmour = 0
    newMetadata.description = FormatRigDescription(0, plates, refills)

    inventory:SetMetadata(src, slot, newMetadata)
end)