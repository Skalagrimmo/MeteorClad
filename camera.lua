-- camera.lua
-- Minimal world-to-viewport camera for the first expanded-world stage.
local Camera = {
    x = 0,
    y = 0
}

local ctx

function Camera:bind(gameCtx)
    ctx = gameCtx
end

function Camera:reset()
    if not ctx then return end

    local player = ctx.player
    local world = ctx.config.world
    local viewport = ctx.config.viewport
    local maxX = math.max(0, world.width - viewport.width)
    local maxY = math.max(0, world.height - viewport.height)

    self.x = math.max(0, math.min(maxX, player.x - viewport.width * 0.5))
    self.y = math.max(0, math.min(maxY, player.y - viewport.height * 0.5))
end

function Camera:update(_dt)
    -- Immediate follow keeps aiming and visual position perfectly in sync.
    self:reset()
end

function Camera:apply()
    love.graphics.translate(-self.x, -self.y)
end

function Camera:screenToWorld(screenX, screenY)
    return screenX + self.x, screenY + self.y
end

function Camera:worldToScreen(worldX, worldY)
    return worldX - self.x, worldY - self.y
end

return Camera
