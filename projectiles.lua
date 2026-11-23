-- projectiles.lua
local Style = require("visual_style")

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
    local world = ctx.config.world

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

        if hit or p.x < -50 or p.x > world.width + 50 or p.y < -50 or p.y > world.height + 50 then
            table.remove(self.list, i)
        end
    end
end

local function setStyleColor(color, alpha)
    love.graphics.setColor(color[1], color[2], color[3], alpha or 1)
end

function Projectiles:draw()
    love.graphics.push("all")
    for _, projectile in ipairs(self.list) do
        local palette = projectile.owner == "player"
            and Style.projectile.player
            or Style.projectile.enemy
        local angle = math.atan2(projectile.vy, projectile.vx)
        local r = projectile.radius

        love.graphics.push()
        love.graphics.translate(projectile.x, projectile.y)
        love.graphics.rotate(angle)

        setStyleColor(palette.glow, 0.22)
        love.graphics.circle("fill", 0, 0, r * 1.75)

        setStyleColor(palette.body, 1)
        love.graphics.polygon("fill",
            r * 1.42, 0, 0, -r * 0.68,
            -r * 1.02, 0, 0, r * 0.68
        )
        setStyleColor(palette.edge, 0.96)
        love.graphics.setLineWidth(1.2)
        love.graphics.polygon("line",
            r * 1.42, 0, 0, -r * 0.68,
            -r * 1.02, 0, 0, r * 0.68
        )

        setStyleColor(palette.trail, 0.76)
        love.graphics.line(-r * 0.62, 0, -r * 1.48, 0)
        setStyleColor(palette.core, 1)
        love.graphics.circle("fill", r * 0.18, 0, math.max(1.4, r * 0.28))

        love.graphics.pop()
    end
    love.graphics.pop()
end


return Projectiles