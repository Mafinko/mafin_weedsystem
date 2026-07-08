fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'Mafin'
description 'A lightweight ESX cannabis workflow with configurable target or TextUI interactions and JSON-backed setup.'
version '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@es_extended/imports.lua',
    '@es_extended/locale.lua',
    'locales/en.lua',
    'locales/cs.lua',
    'config.lua'
}

client_script 'client/main.lua'
server_script 'server/main.lua'

files {
    'data/items.json',
    'data/licenses.json'
}

dependencies {
    'es_extended',
    'ox_lib'
}
