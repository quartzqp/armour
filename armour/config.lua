Config = {}

-- Interval (in seconds) to check if the player is still wearing the rig.
-- Keep >0 for safety. Even at 0.0ms UI you still want some validation.
Config.CheckArmourSeconds = 0

Config.Debug = false

-- RIG SETTINGS
Config.RefillCapacity = 30
Config.PlateSlotLimit = 5
Config.ArmorPerPlate = 20

-- REALISM SETTINGS
Config.ArmourBleedThrough = 0.20

Config.Locales = {
    ['en'] = {
        ['label_armour']            = 'Armour',
        ['label_plates']            = 'Plates',
        ['label_refills']           = 'Refills',

        ['armour_removed']          = 'Armour Removed.',
        ['inventory_full']          = 'Inventory Full.',
        ['plate_carrier_full']      = 'This Plate Carrier is Full.',
        ['plate_carrier_worn']      = 'This Plate Carrier is Worn Out.',
        ['plate_carrier_required']  = 'You Must Have a Plate Carrier.',
        ['plate_applied']           = 'Armour Plate Applied.',
        ['plate_unequip']           = 'Armour Plate Pulled.',
        ['plate_validation']        = 'ERROR: Armour Plate Validation Failed.',
    },
}