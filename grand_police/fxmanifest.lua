-- ─────────────────────────────────────────────────────────────
--  resources/[grand_systems]/grand_police/fxmanifest.lua
--  LSPD / SAHP / FIB / EMS / Bolingbroke Penitentiary.
--  Framework-agnostic: grand_core + oxmysql + ox_lib.
--  NO NUI. Map, MDT and dispatch are chat/marker driven.
-- ─────────────────────────────────────────────────────────────

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'grand_police'
author 'Grand RP'
description 'Police, EMS, MDT, warrants, fines, traffic stops and Bolingbroke prison'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/util.lua',
}

client_scripts {
    'client/pd.lua',
    'client/mdt.lua',
    'client/prison.lua',
    'client/ems.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/duty.lua',
    'server/wanted.lua',
    'server/prison.lua',
    'server/mdt.lua',
    'server/traffic.lua',
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'grand_core',
}
