-- loot.lua
local Style = require("visual_style")

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
        radius = value >= 30 and 7 or 5,
        age = 0,
        phase = (x * 0.017 + y * 0.013 + value * 0.19) % (math.pi * 2)
    })
end

function Loot:update(dt)
    local Player = ctx.player
    local Utils = ctx.utils

    for i = #self.orbs, 1, -1 do
        local orb = self.orbs[i]
        orb.age = orb.age + dt
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
    love.graphics.push("all")

    if not self.drawBatch then
        self.drawBatch = CircleBatch:newBatch(math.max(CircleBatch.initialCapacity, #self.orbs))
    end

    CircleBatch:prepare(self.drawBatch)
    self.drawBatch:setColor(
        Style.loot.glow[1], Style.loot.glow[2], Style.loot.glow[3], 0.92
    )

    local scaleFactor = 2 / CircleBatch.size
    local origin = CircleBatch.origin
    for _, orb in ipairs(self.orbs) do
        local scale = orb.radius * scaleFactor
        self.drawBatch:add(orb.x, orb.y, 0, scale, scale, origin, origin)
    end

    CircleBatch:draw(self.drawBatch)

    love.graphics.push("all")
    love.graphics.setLineWidth(1.25)
    for _, orb in ipairs(self.orbs) do
        local pulse = 0.82 + 0.18 * math.sin(orb.age * 3.2 + orb.phase)
        love.graphics.push()
        love.graphics.translate(orb.x, orb.y)
        love.graphics.rotate(orb.phase + orb.age * 0.72)

        love.graphics.setColor(
            Style.loot.edge[1], Style.loot.edge[2], Style.loot.edge[3], 0.94 * pulse
        )
        love.graphics.polygon("line",
            0, -orb.radius * 1.55,
            orb.radius * 0.78, 0,
            0, orb.radius * 1.55,
            -orb.radius * 0.78, 0
        )
        love.graphics.setColor(
            Style.loot.core[1], Style.loot.core[2], Style.loot.core[3], 0.96 * pulse
        )
        love.graphics.polygon("fill",
            0, -orb.radius * 0.84,
            orb.radius * 0.38, 0,
            0, orb.radius * 0.84,
            -orb.radius * 0.38, 0
        )
        love.graphics.pop()
    end
    love.graphics.pop()
    love.graphics.pop()
end


return Loot