local armourMonitorRunning = false
local lastArmourPlate = { label = nil, image = nil }

-- LOCAL CACHE
local storedPlates = 0
local storedRefills = 0
local activeRigSlot = nil
local activeRigMeta = nil

-- DAMAGE TRACKING CACHE
local prevArmour = 0

-- PERF / THROTTLE
local LOOP_WAIT_MS = 350              -- higher wait = lower CPU
local RESCAN_INTERVAL_MS = 2000       -- inventory rescan interval (expensive call)
local lastRescanAt = 0

-- NET THROTTLE / DEDUPE
local lastSent = {
    slot = nil, label = nil, image = nil,
    armour = nil, plates = nil, refills = nil
}
local lastSendAt = 0
local SEND_MIN_INTERVAL_MS = 500

local function T(key)
    return Config.Locales["en"][key] or key
end

local function DebugPrint(data)
    if Config.Debug then
        print('^3[ARMOUR DEBUG]^7 ' .. tostring(data))
    end
end

-- EXPENSIVE: avoid using frequently
local function findArmourRig()
    local items = exports.ox_inventory:Search('slots', 'body_armour')
    if items then
        for _, item in pairs(items) do
            return item
        end
    end
    return nil
end

local function syncLocalStateFromRigItem(rigItem)
    if rigItem and rigItem.metadata then
        activeRigSlot = rigItem.slot
        activeRigMeta = rigItem.metadata

        storedPlates = rigItem.metadata.plates or 0
        storedRefills = rigItem.metadata.refills or 0
        lastArmourPlate.label = rigItem.metadata.lastPlateLabel or nil
        lastArmourPlate.image = rigItem.metadata.lastPlateImage or nil
    else
        activeRigSlot = nil
        activeRigMeta = nil
        storedPlates = 0
        storedRefills = 0
        lastArmourPlate.label = nil
        lastArmourPlate.image = nil
    end
end

local function clampCounts()
    if storedPlates < 0 then storedPlates = 0 end
    if storedPlates > Config.PlateSlotLimit then storedPlates = Config.PlateSlotLimit end
    if storedRefills < 0 then storedRefills = 0 end
    if storedRefills > Config.RefillCapacity then storedRefills = Config.RefillCapacity end
end

local function rescanRigIfNeeded(force)
    local now = GetGameTimer()
    if not force and (now - lastRescanAt) < RESCAN_INTERVAL_MS then
        return
    end
    lastRescanAt = now

    local rig = findArmourRig()
    if rig then
        if activeRigSlot == nil or rig.slot ~= activeRigSlot then
            DebugPrint(("Rig rescan update. slot: %s -> %s"):format(tostring(activeRigSlot), tostring(rig.slot)))
            syncLocalStateFromRigItem(rig)

            local saved = (rig.metadata and rig.metadata.savedArmour) or 0
            SetPedArmour(cache.ped, saved)
            prevArmour = saved
        end
    else
        if activeRigSlot ~= nil then
            DebugPrint("Rig lost on rescan; stripping armour.")
            SetPedArmour(cache.ped, 0)
        end
        syncLocalStateFromRigItem(nil)
    end
end

local function sendRigMetadataIfChanged(armourValue)
    if not activeRigSlot then return end

    local now = GetGameTimer()
    if (now - lastSendAt) < SEND_MIN_INTERVAL_MS then
        return
    end

    local slot = activeRigSlot
    local label = lastArmourPlate.label
    local image = lastArmourPlate.image
    local plates = storedPlates
    local refills = storedRefills
    local armour = armourValue

    if lastSent.slot == slot and lastSent.label == label and lastSent.image == image
        and lastSent.armour == armour and lastSent.plates == plates and lastSent.refills == refills then
        return
    end

    lastSendAt = now
    lastSent.slot = slot
    lastSent.label = label
    lastSent.image = image
    lastSent.armour = armour
    lastSent.plates = plates
    lastSent.refills = refills

    TriggerServerEvent('armour:updateRigMetadata', slot, label, image, armour, plates, refills)
end

local function updateRig(changePlates, changeRefills)
    if not activeRigSlot then
        rescanRigIfNeeded(true)
        if not activeRigSlot then return end
    end

    if changePlates then storedPlates = storedPlates + changePlates end
    if changeRefills then storedRefills = storedRefills + changeRefills end
    clampCounts()

    sendRigMetadataIfChanged(GetPedArmour(cache.ped))
end

local function nilRig()
    if not activeRigSlot then
        rescanRigIfNeeded(true)
    end
    if activeRigSlot then
        TriggerServerEvent('armour:nilRigMetadata', activeRigSlot)
    end
    storedPlates = 0
end

-- -------------------------------------------------------------------------- --
--                           REALISM & MONITORING                             --
-- -------------------------------------------------------------------------- --

local function hasCompatibleRig()
    return activeRigSlot ~= nil
end

local function DamageLoop()
    prevArmour = GetPedArmour(cache.ped)
    local checkTimer = 0

    while armourMonitorRunning do
        Wait(LOOP_WAIT_MS)

        rescanRigIfNeeded(false)

        if not activeRigSlot then
            SetPedArmour(cache.ped, 0)
            armourMonitorRunning = false
            lib.notify({ type = 'error', description = T('armour_removed') })
            break
        end

        local currentArmour = GetPedArmour(cache.ped)

        checkTimer = checkTimer + LOOP_WAIT_MS
        if checkTimer >= (Config.CheckArmourSeconds * 1000) then
            checkTimer = 0
            if not hasCompatibleRig() and currentArmour > 0 then
                SetPedArmour(cache.ped, 0)
                armourMonitorRunning = false
                lib.notify({ type = 'error', description = T('armour_removed') })
                break
            end
        end

        if currentArmour < prevArmour then
            local damageAmount = prevArmour - currentArmour

            if Config.ArmourBleedThrough > 0 then
                local healthDamage = math.ceil(damageAmount * Config.ArmourBleedThrough)
                if healthDamage > 0 then
                    SetEntityHealth(cache.ped, GetEntityHealth(cache.ped) - healthDamage)
                end
            end

            local armorPerPlate = Config.ArmorPerPlate or 20
            local expectedPlates = math.ceil(currentArmour / armorPerPlate)

            if storedPlates > expectedPlates then
                local diff = expectedPlates - storedPlates
                updateRig(diff, 0)
            else
                sendRigMetadataIfChanged(currentArmour)
            end

            prevArmour = currentArmour

        elseif currentArmour > prevArmour then
            prevArmour = currentArmour
            sendRigMetadataIfChanged(currentArmour)
        end

        if currentArmour <= 0 then
            if storedPlates > 0 then
                updateRig(-storedPlates, 0)
            else
                sendRigMetadataIfChanged(0)
            end
            armourMonitorRunning = false
            break
        end
    end
end

local function startArmourMonitoringIfNeeded()
    if GetPedArmour(cache.ped) > 0 and activeRigSlot and not armourMonitorRunning then
        armourMonitorRunning = true
        CreateThread(DamageLoop)
    end
end

local function loadAndEquipRig()
    -- One forced scan on spawn/rig acquire
    local rigItem = findArmourRig()
    syncLocalStateFromRigItem(rigItem)

    if not rigItem or not rigItem.metadata then
        return
    end

    local saved = rigItem.metadata.savedArmour or 0
    SetPedArmour(cache.ped, saved)
    prevArmour = saved

    startArmourMonitoringIfNeeded()
end

-- -------------------------------------------------------------------------- --
--                                   EVENTS                                   --
-- -------------------------------------------------------------------------- --

RegisterNetEvent('armour:rigAcquired', function()
    loadAndEquipRig()
end)

RegisterNetEvent('armour:serverForceStrip', function()
    SetPedArmour(cache.ped, 0)
    armourMonitorRunning = false
    storedPlates = 0
    storedRefills = 0
    activeRigSlot = nil
    activeRigMeta = nil
end)

RegisterNetEvent('armour:forceStripArmour', function()
    if hasCompatibleRig() then return end
    SetPedArmour(cache.ped, 0)
    armourMonitorRunning = false
    storedPlates = 0
    storedRefills = 0
    activeRigSlot = nil
    activeRigMeta = nil
end)

RegisterNetEvent('armour:nilRig', function()
    Wait(500)
    nilRig()
end)

RegisterNetEvent('armour:checkAndSendArmourLevel', function()
    local currentArmour = GetPedArmour(cache.ped)
    if currentArmour <= 0 then return end

    local success = lib.progressCircle({
        label = 'Pulling Armour Plate',
        duration = 1500,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = false, car = false, combat = true },
        anim = { dict = "anim@male@holding_vest", clip = "holding_vest_clip" },
    })

    if not success then return end

    local amountToRemove = Config.ArmorPerPlate or 20
    if currentArmour < amountToRemove then amountToRemove = currentArmour end

    local newArmourLevel = currentArmour - amountToRemove
    SetPedArmour(cache.ped, newArmourLevel)
    prevArmour = newArmourLevel

    TriggerServerEvent('armour:returnArmourItem', amountToRemove, lastArmourPlate.label, lastArmourPlate.image)
    lib.notify({ type = 'success', description = T('plate_unequip') })

    updateRig(-1, 0)

    if newArmourLevel <= 0 then
        nilRig()
        armourMonitorRunning = false
    end
end)

AddEventHandler('playerSpawned', function()
    CreateThread(loadAndEquipRig)
end)

-- -------------------------------------------------------------------------- --
--                              ITEM USE LOGIC                                --
-- -------------------------------------------------------------------------- --

local function AddArmour(metadata, slotNumber)
    if not activeRigSlot then
        rescanRigIfNeeded(true)
    end

    if not activeRigSlot then
        lib.notify({ type = 'error', description = T('plate_carrier_required') })
        return
    end

    if storedPlates >= Config.PlateSlotLimit then
        lib.notify({ type = 'error', description = T('plate_carrier_full') })
        return
    end

    if storedRefills >= Config.RefillCapacity then
        lib.notify({ type = 'error', description = T('plate_carrier_worn') })
        return
    end

    if lib.progressCircle({
        label = 'Applying Armour Plate',
        duration = 3000,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = false, car = false, combat = true },
        anim = { dict = "missmic4", clip = "michael_tux_fidget" },
    }) then
        local plateValue = metadata.durability or Config.ArmorPerPlate or 20

        lastArmourPlate.label = metadata.label
        lastArmourPlate.image = metadata.image

        local currentArmour = GetPedArmour(cache.ped)
        local newArmour = math.min(currentArmour + plateValue, 100)

        SetPedArmour(cache.ped, newArmour)
        prevArmour = newArmour

        lib.notify({ type = 'success', description = T('plate_applied') })

        updateRig(1, 1)
        TriggerServerEvent('armour:server:completedPlateUse', slotNumber)

        startArmourMonitoringIfNeeded()
    end
end

exports('armour_plate', function(_, slot)
    if not slot or not slot.metadata then return end
    AddArmour(slot.metadata, slot.slot)
end)