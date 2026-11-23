-- visual_style.lua
-- Shared visual language for MeteorClad: cold alloy, spectral energy, and restrained anomaly light.
-- Colors are normalized RGB values. This module contains no gameplay state.

local Style = {}

Style.player = {
    shell = {0.025, 0.075, 0.105},
    plate = {0.075, 0.21, 0.27},
    edge = {0.19, 0.63, 0.79},
    bright = {0.40, 0.88, 1.00},
    core = {0.82, 0.97, 1.00},
    glow = {0.07, 0.36, 0.58},
    slash = {0.50, 0.89, 1.00}
}

Style.enemy = {
    grunt = {
        body = {0.25, 0.065, 0.085},
        edge = {0.90, 0.29, 0.30},
        accent = {0.53, 0.12, 0.17},
        core = {1.00, 0.69, 0.55}
    },
    rusher = {
        body = {0.29, 0.12, 0.035},
        edge = {1.00, 0.52, 0.16},
        accent = {0.73, 0.25, 0.04},
        core = {1.00, 0.82, 0.50}
    },
    tank = {
        body = {0.20, 0.055, 0.09},
        edge = {0.69, 0.22, 0.29},
        accent = {0.42, 0.08, 0.15},
        core = {1.00, 0.46, 0.32}
    },
    shooter = {
        body = {0.17, 0.095, 0.29},
        edge = {0.68, 0.43, 0.98},
        accent = {0.39, 0.20, 0.64},
        core = {0.91, 0.82, 1.00}
    }
}

Style.projectile = {
    enemy = {
        glow = {0.40, 0.16, 0.62},
        body = {0.48, 0.22, 0.72},
        edge = {0.80, 0.58, 1.00},
        core = {0.98, 0.91, 1.00},
        trail = {0.61, 0.36, 0.84}
    },
    player = {
        glow = {0.06, 0.36, 0.58},
        body = {0.10, 0.58, 0.76},
        edge = {0.34, 0.84, 1.00},
        core = {0.88, 0.98, 1.00},
        trail = {0.26, 0.72, 0.91}
    }
}

Style.loot = {
    glow = {0.08, 0.35, 0.32},
    edge = {0.39, 0.95, 0.76},
    core = {0.90, 1.00, 0.93}
}

Style.impact = {1.00, 0.66, 0.30}

Style.portal = {
    haze = {0.25, 0.04, 0.42},
    void = {0.008, 0.012, 0.028},
    departure = {0.72, 0.34, 1.00},
    arrival = {0.28, 0.82, 1.00},
    outer = {0.55, 0.30, 0.96},
    inner = {0.28, 0.82, 1.00},
    spiral = {0.45, 0.70, 1.00},
    mote = {0.70, 0.86, 1.00},
    rim = {0.76, 0.62, 1.00}
}

Style.fog = {
    base = {0.39, 0.46, 0.54},
    variation = {0.07, 0.08, 0.09},
    mote = {0.52, 0.59, 0.65}
}

Style.ui = {
    track = {0.075, 0.11, 0.15},
    health = {0.93, 0.31, 0.29},
    xp = {0.16, 0.77, 0.68},
    dash = {0.20, 0.72, 0.96},
    whirlwind = {0.40, 0.88, 1.00},
    text = {0.84, 0.92, 0.96},
    mutedText = {0.62, 0.73, 0.80},
    highlight = {0.50, 0.88, 1.00},
    panel = {0.035, 0.07, 0.12},
    panelEdge = {0.18, 0.52, 0.66},
    danger = {1.00, 0.34, 0.32},
    enemyHealth = {1.00, 0.40, 0.27}
}

return Style
