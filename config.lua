return {
    -- Screen-space dimensions remain fixed until the resize/scaling stage.
    viewport = {
        width = 800,
        height = 600
    },
    window = {
        resizableDesktop = true,
        minWidth = 640,
        minHeight = 480
    },
    -- A broad black world: three logical viewports wide and high.
    world = {
        width = 2400,
        height = 1800
    },
    game = {
        waveDelay = 2.0,
        -- Keep incoming waves just beyond the camera view as the world grows.
        enemySpawnMargin = 80
    },
    -- Ambient atmosphere is a world-space layer behind all gameplay entities.
    ambientFog = {
        enabled = true,
        patchCount = 30,
        moteCount = 24,
        opacity = 1.0,
        moteOpacity = 0.75
    },
    enemyTypes = {
        grunt = {
            color = {0.9, 0.25, 0.25},
            radius = 16,
            speedMin = 95, speedMax = 125,
            hp = 40, damage = 15, xp = 15,
            knockbackResist = 1.0,
            behavior = "melee"
        },
        rusher = {
            color = {1.0, 0.55, 0.1},
            radius = 12,
            speedMin = 175, speedMax = 210,
            hp = 22, damage = 10, xp = 12,
            knockbackResist = 1.3,
            behavior = "melee"
        },
        tank = {
            color = {0.55, 0.1, 0.15},
            radius = 25,
            speedMin = 55, speedMax = 70,
            hp = 130, damage = 25, xp = 40,
            knockbackResist = 0.25,
            behavior = "melee"
        },
        shooter = {
            color = {0.75, 0.2, 0.9},
            radius = 15,
            speedMin = 85, speedMax = 105,
            hp = 35, damage = 12, xp = 25,
            knockbackResist = 1.0,
            behavior = "ranged",
            preferredDist = 250,
            shootCooldown = 2.4
        }
    }
}