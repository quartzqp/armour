Config = {}

Config.Debug = false
Config.CheckArmourSeconds = 1
Config.ArmourBleedThrough = 1.0

Config.BodyArmours = {
    body_armour = {
        maxPlates = 5,
        maxRefills = 15,
    },

    heavy_body_armour = {
        maxPlates = 5,
        maxRefills = 30,
    },

    improved_body_armour = {
        maxPlates = 10,
        maxRefills = 60,
    },

    pd_body_armour = {
        maxPlates = 5,
        maxRefills = 30,
        job = "police",
    }
}

Config.ArmourPlates = {
    armour_plate = 20,
    improved_armour_plate = 25,
    broken_armour_plate = 0,
}

Config.Locales = {
    ['en'] = {
        ['label_armour']            = 'Armour',
        ['label_plates']            = 'Plates',
        ['label_refills']           = 'Refills',

        ['body_armour_applied']     = 'Body Armour Equipped.',
        ['body_armour_removed']     = 'Body Armour Removed.',
        ['body_armour_required']    = 'You Must Have a Body Armour.',
        ['body_armour_full']        = 'This Body Armour is Full.',
        ['body_armour_worn']        = 'This Body Armour is Worn.',
        ['body_armour_no_plates']   = 'No Plates Available in this Armour.',

        ['armour_plate_applied']    = 'Armour Plate Applied.',
        ['armour_plate_pulled']     = 'Armour Plate Pulled.',
        ['armour_plate_apply']      = 'Applying Armour Plate',
        ['armour_plate_pull']       = 'Pulling Armour Plate',
        ['armour_plate_cancelled']  = 'Armour Plate Cancelled',
        ['armour_plate_validation'] = 'ERROR: Armour Plate Validation Failed.',
    }
}