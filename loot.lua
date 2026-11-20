-- loot.lua
local Loot = {
    orbs = {}
}

local CircleBatch = require("circle_batch")

local ctx

function Loot:bind(gameCtx)
    ctx = gameCtx
end

function Loot:clear()
    self.orbs = {}
end

function Loot:spawnXP(x, y, value)
    table.insert(self.orbs, {
        x = x,
        y = y,
        value = value,
        radius = value >= 30 and 7 or 5
    })
end

function Loot:update(dt)
    local Player = ctx.player
    local Utils = ctx.utils

    for i = #self.orbs, 1, -1 do
        local orb = self.orbs[i]
        local d = Utils.dist(Player.x, Player.y, orb.x, orb.y)

        if d <= Player.pickupRadius then
            local angle = math.atan2(Player.y - orb.y, Player.x - orb.x)
            orb.x = orb.x + math.cos(angle) * 400 * dt
            orb.y = orb.y + math.sin(angle) * 400 * dt
            d = Utils.dist(Player.x, Player.y, orb.x, orb.y)
        end

        if d <= Player.radius + orb.radius then
            Player.xp = Player.xp + orb.value
            table.remove(self.orbs, i)
            if Player.xp >= Player.xpToNext then
                ctx.game:triggerLevelUp()
                break
            end
        end
    end
end

function Loot:draw()
    if #self.orbs == 0 then return end

    if not self.drawBatch then
        self.drawBatch = CircleBatch:newBatch(math.max(CircleBatch.initialCapacity, #self.orbs))
    end

    CircleBatch:prepare(self.drawBatch, #self.orbs)
    self.drawBatch:setColor(0.2, 1, 0.5, 1)

    local scaleFactor = 2 / CircleBatch.size
    local origin = CircleBatch.origin
    for _, orb in ipairs(self.orbs) do
        local scale = orb.radius * scaleFactor
        self.drawBatch:add(orb.x, orb.y, 0, scale, scale, origin, origin)
    end

    CircleBatch:draw(self.drawBatch)
end

return Loot