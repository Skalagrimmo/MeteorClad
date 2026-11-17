-- projectiles.lua
local Projectiles = {
    list = {}
}

local ctx

function Projectiles:bind(gameCtx)
    ctx = gameCtx
end

function Projectiles:clear()
    self.list = {}
end

function Projectiles:spawn(x, y, angle, speed, damage, owner)
    table.insert(self.list, {
        x = x,
        y = y,
        vx = math.cos(angle) * speed,
        vy = math.sin(angle) * speed,
        speed = speed,
        radius = 6,
        damage = damage,
        owner = owner or "enemy"
    })
end

function Projectiles:tryDeflect(px, py, range, attackAngle, attackArc, damageMult)
    local Utils = ctx.utils
    local Player = ctx.player

    for _, p in ipairs(self.list) do
        if p.owner == "enemy" then
            if Utils.dist(px, py, p.x, p.y) <= range + p.radius then
                local angleToProj = math.atan2(p.y - py, p.x - px)
                if attackArc >= math.pi or math.abs(Utils.normalizeAngle(angleToProj - attackAngle)) <= attackArc then
                    p.owner = "player"
                    p.damage = math.floor(p.damage * damageMult + Player.damage * 0.5)
                    p.speed = p.speed * 1.65
                    p.radius = 8

                    local newAngle = (attackArc >= math.pi) and angleToProj or attackAngle
                    p.vx = math.cos(newAngle) * p.speed
                    p.vy = math.sin(newAngle) * p.speed
                end
            end
        end
    end
end

function Projectiles:update(dt)
    local Utils = ctx.utils
    local Player = ctx.player
    local Enemies = ctx.enemies
    local arena = ctx.config.arena

    for i = #self.list, 1, -1 do
        local p = self.list[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt

        local hit = false

        if p.owner == "enemy" then
            if Utils.dist(p.x, p.y, Player.x, Player.y) <= p.radius + Player.radius then
                if Player:takeDamage(p.damage) then
                    hit = true
                end
            end
        elseif p.owner == "player" then
            for _, e in ipairs(Enemies.list) do
                if e.hp > 0 and Utils.dist(p.x, p.y, e.x, e.y) <= p.radius + e.radius then
                    Enemies:damageArea(p.x, p.y, 45, p.damage)
                    hit = true
                    break
                end
            end
        end

        if hit or p.x < -50 or p.x > arena.width + 50 or p.y < -50 or p.y > arena.height + 50 then
            table.remove(self.list, i)
        end
    end
end

function Projectiles:draw()
    for _, p in ipairs(self.list) do
        if p.owner == "enemy" then
            love.graphics.setColor(0.95, 0.3, 1.0)
            love.graphics.circle("fill", p.x, p.y, p.radius)
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("fill", p.x, p.y, p.radius * 0.4)
        else
            love.graphics.setColor(0.2, 0.9, 1.0)
            love.graphics.circle("fill", p.x, p.y, p.radius)
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("fill", p.x, p.y, p.radius * 0.5)
        end
    end
end

return Projectiles