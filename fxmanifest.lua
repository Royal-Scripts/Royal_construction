server_script '@Wolf-Block-Backdoor/firewall.lua'
server_script '@Wolf-Block-Backdoor/firewall.js'
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Royal'
description 'Royal Construction Job'
version '1.0.0'

dependencies {
    'qb-core',
    'ox_lib',
    'ox_target'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/styles.css',
    'html/script.js'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}
