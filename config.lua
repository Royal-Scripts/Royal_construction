Config = {}

-- NPC Location
Config.Ped = {
    model = 's_m_y_construct_01',
    coords = vec4(140.95, -379.38, 43.26, 56.61)
}

-- Blip settings
Config.Blip = {
    sprite = 566,
    color = 47,
    scale = 0.7,
    label = 'სამშენებლო სამუშაო'
}

-- Quest settings
Config.Quest = {
    totalCheckpoints = 150,
    bonusPercent = 0.10 -- 10% bonus
}

-- Reward settings (based on distance)
Config.Rewards = {
    minReward = 1,
    maxReward = 4,
    baseDistance = 50.0 -- Distance for max reward calculation
}

-- Work checkpoints with animations and props
Config.Checkpoints = {
    {
        coords = vec4(81.1, -418.06, 36.55, 244.75),
        anim = {
            dict = 'amb@world_human_hammering@male@base',
            name = 'base',
            duration = 5000
        },
        prop = {
            model = 'prop_tool_hammer',
            bone = 28422, -- PH_L_Hand
            offset = vec3(0.0, 0.0, 0.0),
            rotation = vec3(0.0, 0.0, 0.0)
        },
        label = 'ჩაქუჩით მუშაობა',
        type = 'work' -- normal work checkpoint
    },
    {
        coords = vec4(79.3, -443.98, 36.55, 71.16),
        anim = {
            dict = 'anim@heists@fleeca_bank@drilling',
            name = 'drill_straight_end',
            duration = 5000
        },
        prop = {
            model = 'prop_tool_drill',
            bone = 28422, -- PH_L_Hand
            offset = vec3(0.0, 0.0, 0.0),
            rotation = vec3(0.0, 0.0, 90.0)
        },
        label = 'ბურღვა',
        type = 'work'
    },
    {
        coords = vec4(32.97, -390.8, 54.28, 67.68),
        anim = {
            dict = 'anim@heists@box_carry@',
            name = 'idle',
            duration = 3000
        },
        prop = {
            model = 'hei_prop_heist_box',
            bone = 60309, -- SKEL_ROOT
            offset = vec3(0.025, 0.08, 0.255),
            rotation = vec3(-145.0, 290.0, 0.0)
        },
        label = 'მასალების აღება',
        type = 'carry', -- special carry checkpoint
        dropoff = vec4(52.85, -402.02, 54.28, 8.21)
    },
    {
        coords = vec4(103.0, -374.25, 41.53, 316.94),
        anim = {
            dict = 'amb@world_human_const_drill@male@drill@base',
            name = 'base',
            duration = 5000
        },
        prop = {
            model = 'prop_tool_jackham',
            bone = 28422,
            offset = vec3(0.0, 0.0, 0.0),
            rotation = vec3(0.0, 0.0, 0.0)
        },
        label = 'მძიმე ბურღვა',
        type = 'work'
    }
}

-- Marker settings
Config.Marker = {
    type = 1, -- Cylinder
    size = vec3(1.5, 1.5, 1.0),
    color = { r = 255, g = 165, b = 0, a = 150 } -- Orange
}

-- Progress bar settings  
Config.Progress = {
    duration = 5000,
    label = 'მუშაობს...'
}
