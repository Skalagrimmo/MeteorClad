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
    -- Rare portals appear in the current fog field and lead to distant safe positions.
    portals = {
        enabled = true,
        firstSpawnMin = 5,
        firstSpawnMax = 9,
        spawnDelayMin = 14,
        spawnDelayMax = 22,
        expireDelayMin = 8,
        expireDelayMax = 14,
        activeLifetime = 32,
        openingTime = 0.72,
        spawnDistanceMin = 220,
        spawnDistanceMax = 320,
        radius = 32,
        minTeleportDistance = 700,
        enemyClearance = 260,
        destinationAttempts = 64,
        landingInvulnerability = 0.9
    },
    enemyTypes = {
        grunt = {
            radius = 16,
            speedMin = 95, speedMax = 125,
            hp = 40, damage = 15, xp = 15,
            knockbackResist = 1.0,
            behavior = "melee"
        },
        rusher = {
            radius = 12,
            speedMin = 175, speedMax = 210,
            hp = 22, damage = 10, xp = 12,
            knockbackResist = 1.3,
            behavior = "melee"
        },
        tank = {
            radius = 25,
            speedMin = 55, speedMax = 70,
            hp = 130, damage = 25, xp = 40,
            knockbackResist = 0.25,
            behavior = "melee"
        },
        shooter = {
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