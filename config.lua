return {
    -- Screen-space dimensions remain fixed until the resize/scaling stage.
    viewport = {
        width = 800,
        height = 600
    },
    -- World-space bounds are larger than the visible viewport.
    world = {
        width = 1200,
        height = 900
    },
    game = {
        waveDelay = 2.0
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