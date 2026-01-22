local inventory = exports.ox_inventory

-- ============================================================
-- LOCALE
-- ============================================================
local function L(key)
    local loc = Config.Locales and Config.Locales['en']
    return (loc and loc[key]) or key
end

-- ============================================================
-- STATE
-- ============================================================
local currentArmour = {
    name = nil,
    slot = nil,
    metadata = nil,
}

local prevArmour = 0

-- ============================================================
-- HELPERS
-- ============================================================
local function getArmourConfig(itemName)
    return Config.BodyArmours[itemName]
end

local function ensurePlateArray(meta)
    meta.plates = meta.plates or {}
    return meta.plates
end

local function calculateTotalArmour(meta)
    local plates = ensurePlateArray(meta)
    local total = 0
    for _, plate in ipairs(plates) do
        if plate.durability and plate.durability > 0 then
            total = total + plate.durability
        end
    end
    if total > 100 then total = 100 end
    return total
end

local function getTopPlate(meta)
    local plates = ensurePlateArray(meta)
    return plates[#plates], #plates
end

local function buildArmourDescription(meta, itemName)
    local plates = ensurePlateArray(meta)
    local nonBroken = 0
    for _, plate in ipairs(plates) do
        if plate.durability and plate.durability > 0 then
            nonBroken = nonBroken + 1
        end
    end

    local cfg = getArmourConfig(itemName) or {}
    local maxPlates = cfg.maxPlates or 5
    local refills = meta.refills or 0
    local maxRefills = cfg.maxRefills or 0
    local armour = meta.armour or 0

    return string.format(
        "%s: %d%%\n%s: %d/%d\n%s: %d/%d",
        L('label_armour'),
        armour,
        L('label_plates'),
        nonBroken, maxPlates,
        L('label_refills'),
        refills, maxRefills
    )
end

local function syncArmourToPed(meta)
    local armour = calculateTotalArmour(meta)
    SetPedArmour(cache.ped, armour)
    prevArmour = armour
    meta.armour = armour
end

local function EnsureCurrentArmour()
    if currentArmour.name and currentArmour.metadata then
        return true
    end

    for name, _ in pairs(Config.BodyArmours) do
        local slots = inventory:Search('slots', name)
        if slots and slots[1] then
            local item = slots[1]
            SetCurrentArmour(item.name, item.slot, item.metadata or {})
            return true
        end
    end

    return false
end

-- ============================================================
-- BODY ARMOUR CORE
-- ============================================================
function SetCurrentArmour(itemName, slot, metadata)
    local cfg = getArmourConfig(itemName)
    if not cfg then return end

    currentArmour.name = itemName
    currentArmour.slot = slot
    currentArmour.metadata = metadata or {}

    local meta = currentArmour.metadata
    ensurePlateArray(meta)
    meta.refills = meta.refills or 0

    syncArmourToPed(meta)
    meta.description = buildArmourDescription(meta, itemName)

    lib.notify({ type = 'success', description = L('body_armour_applied') })
end
exports('SetCurrentArmour', SetCurrentArmour)

RegisterNetEvent('armour:clientForceStrip', function()
    if not currentArmour.metadata then return end

    currentArmour.name = nil
    currentArmour.slot = nil
    currentArmour.metadata = nil
    SetPedArmour(cache.ped, 0)
    prevArmour = 0

    lib.notify({ type = 'info', description = L('body_armour_removed') })
end)

RegisterNetEvent('armour:clientBodyArmourAcquired', function()
    for name, _ in pairs(Config.BodyArmours) do
        local slots = inventory:Search('slots', name)
        if slots and slots[1] then
            local item = slots[1]
            SetCurrentArmour(item.name, item.slot, item.metadata or {})
            break
        end
    end
end)

-- Watchdog: if the armour item disappears, clear state
CreateThread(function()
    while true do
        Wait(1000)

        if currentArmour.name then
            local slots = inventory:Search('slots', currentArmour.name)
            if not slots or not slots[1] then
                currentArmour.name = nil
                currentArmour.slot = nil
                currentArmour.metadata = nil
                SetPedArmour(cache.ped, 0)
                prevArmour = 0
            end
        end
    end
end)

-- ============================================================
-- SERVER SYNC
-- ============================================================
local function BodyArmour_UpdateMetadata()
    if not currentArmour or not currentArmour.metadata then return end

    local meta = currentArmour.metadata
    local itemName = currentArmour.name

    meta.description = buildArmourDescription(meta, itemName)

    TriggerServerEvent(
        'armour:updateBodyArmourMetadata',
        currentArmour.slot,
        meta.plates,
        meta.refills or 0
    )
end

-- ============================================================
-- APPLY ARMOUR PLATE
-- ============================================================
function armour_plate(item, metadata, slot)
    if not EnsureCurrentArmour() then
        lib.notify({ type = 'error', description = L('body_armour_required') })
        return
    end

    local cfg = getArmourConfig(currentArmour.name)
    if not cfg then
        lib.notify({ type = 'error', description = L('body_armour_required') })
        return
    end

    local meta = currentArmour.metadata
    local plates = ensurePlateArray(meta)

    if #plates >= (cfg.maxPlates or 5) then
        lib.notify({ type = 'error', description = L('body_armour_full') })
        return
    end

    local plateDurability = Config.ArmourPlates[item.name]
    if not plateDurability or plateDurability <= 0 then
        lib.notify({ type = 'error', description = L('armour_plate_validation') })
        return
    end

    local currentArmourValue = calculateTotalArmour(meta)
    if currentArmourValue >= 100 then
        lib.notify({ type = 'error', description = L('body_armour_full') })
        return
    end

    local label = (metadata and metadata.label) or item.label or 'Armour Plate'

    local success = lib.progressCircle({
        label = L('armour_plate_apply'),
        duration = 3000,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = false, car = false, combat = true },
        anim = { dict = "missmic4", clip = "michael_tux_fidget" },
    })

    if not success then return end

    plates[#plates + 1] = {
        durability = plateDurability,
        label = label,
        item = item.name,
    }

    -- increment refills
    meta.refills = (meta.refills or 0) + 1

    syncArmourToPed(meta)
    BodyArmour_UpdateMetadata()

    lib.notify({ type = 'success', description = L('armour_plate_applied') })

    TriggerServerEvent('armour:server:completedPlateUse', slot or item.slot)
end
exports('armour_plate', armour_plate)

-- ============================================================
-- PULL ARMOUR PLATE (top of stack)
-- ============================================================
RegisterNetEvent('armour:checkAndSendArmourLevel', function()
    if not EnsureCurrentArmour() then return end

    local meta = currentArmour.metadata
    local plates = ensurePlateArray(meta)

    if #plates == 0 then
        lib.notify({ type = 'error', description = L('body_armour_no_plates') })
        return
    end

    local success = lib.progressCircle({
        label = L('armour_plate_pull'),
        duration = 1500,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = false, car = false, combat = true },
        anim = { dict = "anim@male@holding_vest", clip = "holding_vest_clip" },
    })

    if not success then return end

    local topPlate, index = getTopPlate(meta)
    if not topPlate then
        lib.notify({ type = 'error', description = L('body_armour_no_plates') })
        return
    end

    table.remove(plates, index)

    local durability = topPlate.durability or 0
    local label = topPlate.label or 'Armour Plate'
    local itemName = topPlate.item or 'armour_plate'

    syncArmourToPed(meta)
    BodyArmour_UpdateMetadata()

    TriggerServerEvent('armour:returnArmourItem', durability, label, itemName)

    lib.notify({ type = 'success', description = L('armour_plate_pulled') })

    if #plates == 0 then
        SetPedArmour(cache.ped, 0)
        prevArmour = 0
        meta.armour = 0
        BodyArmour_UpdateMetadata()
    end
end)

-- ============================================================
-- DAMAGE MONITOR (top plate takes damage, auto-skip broken)
-- ============================================================
CreateThread(function()
    while true do
        Wait(250)

        if not currentArmour.name or not currentArmour.metadata then
            goto continue
        end

        local ped = cache.ped
        local current = GetPedArmour(ped)
        local meta = currentArmour.metadata
        local plates = ensurePlateArray(meta)

        if #plates > 0 and current < prevArmour then
            local damage = prevArmour - current

            while damage > 0 and #plates > 0 do
                local topPlate, index = getTopPlate(meta)
                if not topPlate then break end

                local plateDur = topPlate.durability or 0
                if plateDur <= 0 then
                    -- broken, auto-skip (do not consume further)
                    break
                end

                if damage >= plateDur then
                    damage = damage - plateDur
                    topPlate.durability = 0
                else
                    topPlate.durability = plateDur - damage
                    damage = 0
                end
            end

            syncArmourToPed(meta)
            BodyArmour_UpdateMetadata()
        end

        prevArmour = GetPedArmour(ped)

        ::continue::
    end
end)

-- ============================================================
-- DEATH MECHANIC — convert all plates to broken
-- ============================================================
CreateThread(function()
    while true do
        Wait(500)

        if not currentArmour.name or not currentArmour.metadata then
            goto continue
        end

        local ped = cache.ped
        local health = GetEntityHealth(ped)

        if health <= 101 then
            local meta = currentArmour.metadata
            local plates = ensurePlateArray(meta)

            if #plates > 0 then
                TriggerServerEvent('armour:server:convertAllPlatesToBrokenOnDeath', plates)
            end

            meta.plates = {}
            meta.armour = 0
            meta.description = buildArmourDescription(meta, currentArmour.name)

            SetPedArmour(ped, 0)
            prevArmour = 0

            BodyArmour_UpdateMetadata()
        end

        ::continue::
    end
end)