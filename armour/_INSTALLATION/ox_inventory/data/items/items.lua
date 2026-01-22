    -- ============================================================
    -- BODY ARMOURS
    -- ============================================================

    ['body_armour'] = {
        label = 'Body Armour',
        weight = 1000,
        stack = false,
        close = true,
        consume = false,
        description = 'Standard Body Armour.',
        client = {
            image = 'body_armour.png',
            export = "armour.SetCurrentArmour",
        },
        buttons = {
            {
                label = 'Pull Plate',
                action = function(slot)
                    TriggerEvent('armour:checkAndSendArmourLevel', slot)
                end
            }
        }
    },

    ['heavy_body_armour'] = {
        label = 'Heavy Body Armour',
        weight = 1000,
        stack = false,
        close = true,
        consume = false,
        description = 'Heavy Body Armour.',
        client = {
            image = 'heavy_body_armour.png',
            export = "armour.SetCurrentArmour",
        },
        buttons = {
            {
                label = 'Pull Plate',
                action = function(slot)
                    TriggerEvent('armour:checkAndSendArmourLevel', slot)
                end
            }
        }
    },

    ['improved_body_armour'] = {
        label = 'Improved Body Armour',
        weight = 1000,
        stack = false,
        close = true,
        consume = false,
        description = 'Improved Body Armour.',
        client = {
            image = 'improved_body_armour.png',
            export = "armour.SetCurrentArmour",
        },
        buttons = {
            {
                label = 'Pull Plate',
                action = function(slot)
                    TriggerEvent('armour:checkAndSendArmourLevel', slot)
                end
            }
        }
    },

    ['pd_body_armour'] = {
        label = 'PD Body Armour',
        weight = 1000,
        stack = false,
        close = true,
        consume = false,
        description = 'PD Body Armour.',
        client = {
            image = 'pd_body_armour.png',
            export = "armour.SetCurrentArmour",
        },
        buttons = {
            {
                label = 'Pull Plate',
                action = function(slot)
                    TriggerEvent('armour:checkAndSendArmourLevel', slot)
                end
            }
        }
    },

    -- ============================================================
    -- ARMOUR PLATES
    -- ============================================================

    ['armour_plate'] = {
        label = 'Armour Plate',
        weight = 1000,
        stack = true,
        close = true,
        consume = false,
        description = 'Standard Armour Plate.',
        client = {
            image = "armour_plate.png",
            export = 'armour.armour_plate'
        }
    },

    ['improved_armour_plate'] = {
        label = 'Improved Armour Plate',
        weight = 1000,
        stack = true,
        close = true,
        consume = false,
        description = 'Improved Armour Plate.',
        client = {
            image = "improved_armour_plate.png",
            export = 'armour.armour_plate'
        }
    },

    ['broken_armour_plate'] = {
        label = 'Broken Armour Plate',
        weight = 1000,
        stack = true,
        close = true,
        consume = false,
        description = 'Broken Armour Plate.',
        client = {
            image = "broken_armour_plate.png",
        }
    },