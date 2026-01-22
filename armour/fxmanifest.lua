fx_version 'cerulean'
game 'gta5'

name 'armour'
author 'quartzqp'
description 'Stack-based armour and plate system'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua'
}

lua54 'yes'

exports {
    'SetCurrentArmour',
    'armour_plate'
}