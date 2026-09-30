fx_version 'bodacious'
game 'gta5'

name 'DepAITaxi - AI Taxi System (Vivanite2)'
author 'Deploy Store'
description 'Advanced Autonomous AI Taxi System linked to Vivanite2 with Vue 3 NUI & Multi-Framework Support'
version '1.0.1'
lua54 'yes'

escrow_ignore {
    'config.lua',
    'locales.lua',
    'locales/*.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/prompt.css',
    'html/vue.global.prod.js',
    'html/app.js',
    'html/prompt.js',
    'html/img/*'
}

shared_scripts {
    'config.lua',
    'locales.lua',
    'locales/*.lua'
}

client_scripts {
    'client/cl_framework.lua',
    'client/cl_taxi.lua',
    'client/cl_main.lua'
}

server_scripts {
    'server/sv_main.lua'
}
