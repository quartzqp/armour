fx_version 'cerulean'
lua54 'yes'
game 'gta5'

name 'armour'
author 'quartzqp'
version '0.0.2'
description 'Armour Plate Script (Optimized)'

dependencies {
    'ox_lib',
    'ox_inventory'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

server_scripts {
    'server/server.lua'
}

client_scripts {
    'client/client.lua'
}

exports {
    'armour_plate'
}