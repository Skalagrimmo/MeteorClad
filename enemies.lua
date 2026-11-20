-- enemies.lua
local Enemies = {
    list = {}
}

local ctx

function Enemies:bind(gameCtx)
    ctx = gameCtx
end

function Enemies:clear()
    self.list = {}
end

function Enemies:spawn(typeName, x, y, waveScale)
    local proto = ctx.config.enemyTypes[typeName]
    local hpScaled = math.floor(proto.hp * waveScale)
    table.insert(self.list, {
        type = typeName,
        color = proto.color,
        x = x,
        y = y,
        radius = proto.radius,
        speed = math.random(proto.speedMin, proto.speedMax),
        hp = hpScaled,
        maxHp = hpScaled,
        damage = proto.damage,
        xp = proto.xp,
        knockbackResist = proto.knockbackResist,
        behavior = proto.behavior,
        preferredDist = proto.preferredDist or 0,
        shootCooldown = proto.shootCooldown or 0,
        shootTimer = math.random() * 1.5,
        hitFlash = 0
    })
end

function Enemies:spawnWave(waveNum)
    local arena = ctx.config.arena
    local count = 4 + waveNum * 2
    local waveScale = 1 + (waveNum - 1) * 0.15

    for i = 1, count do
        local side = math.random(1, 4)
        local x, y
        if side == 1 then x, y = math.random(0, arena.width), -25
        elseif side == 2 then x, y = math.random(0, arena.width), arena.height + 25
        elseif side == 3 then x, y = -25, math.random(0, arena.height)
        else x, y = arena.width + 25, math.random(0, arena.height) end

        local roll = math.random(1, 100)
        local chosenType = "grunt"
        if waveNum >= 2 and roll > 60 then chosenType = "rusher" end
        if waveNum >= 2 and roll > 78 then chosenType = "shooter" end
        if waveNum >= 3 and roll > 90 then chosenType = "tank" end

        self:spawn(chosenType, x, y, waveScale)
    end
end

function Enemies:checkMeleeHit(px, py, range, attackAngle, attackArc, damage, baseKnockback)
    local Utils = ctx.utils
    for _, e in ipairs(self.list) do
        if e.hp > 0 and Utils.dist(px, py, e.x, e.y) <= range + e.radius then
            local angleToEnemy = math.atan2(e.y - py, e.x - px)
            if attackArc >= math.pi or math.abs(Utils.normalizeAngle(angleToEnemy - attackAngle)) <= attackArc then
                e.hp = e.hp - damage
                e.hitFlash = 0.1
                local pushAngle = (attackArc >= math.pi) and angleToEnemy or attackAngle
                local knockback = (baseKnockback or 32) * e.knockbackResist
                e.x = e.x + math.cos(pushAngle) * knockback
                e.y = e.y + math.sin(pushAngle) * knockback
            end
        end
    end
end

function Enemies:damageArea(cx, cy, radius, damage)
    local Utils = ctx.utils
    for _, e in ipairs(self.list) do
        if e.hp > 0 and Utils.dist(cx, cy, e.x, e.y) <= radius + e.radius then
            e.hp = e.hp - damage
            e.hitFlash = 0.12
        end
    end
end

function Enemies:kill(index)
    local e = self.list[index]
    if not e then return end

    local Player = ctx.player
    ctx.game.score = ctx.game.score + e.xp
    if Player.lifesteal > 0 then
        Player.hp = math.min(Player.maxHp, Player.hp + Player.lifesteal)
    end
    ctx.loot:spawnXP(e.x, e.y, e.xp)
    table.remove(self.list, index)
end

function Enemies:update(dt)
    local Player = ctx.player
    local Utils = ctx.utils

    for i = #self.list, 1, -1 do
        local e = self.list[i]

        if e.hp <= 0 then
            self:kill(i)
        else
            if e.hitFlash > 0 then e.hitFlash = e.hitFlash - dt end

            local angle = math.atan2(Player.y - e.y, Player.x - e.x)
            local d = Utils.dist(e.x, e.y, Player.x, Player.y)

            if e.behavior == "melee" then
                if d > Player.radius + e.radius - 4 then
                    e.x = e.x + math.cos(angle) * e.speed * dt
                    e.y = e.y + math.sin(angle) * e.speed * dt
                end
            elseif e.behavior == "ranged" then
                if d > e.preferredDist then
                    e.x = e.x + math.cos(angle) * e.speed * dt
                    e.y = e.y + math.sin(angle) * e.speed * dt
                elseif d < e.preferredDist - 60 then
                    e.x = e.x - math.cos(angle) * (e.speed * 0.7) * dt
                    e.y = e.y - math.sin(angle) * (e.speed * 0.7) * dt
                end

                e.shootTimer = e.shootTimer - dt
                if e.shootTimer <= 0 then
                    e.shootTimer = e.shootCooldown
                    ctx.projectiles:spawn(e.x, e.y, angle, 240, e.damage, "enemy")
                end
            end

            if d <= Player.radius + e.radius then
                Player:takeDamage(e.damage)
            end

            if e.hp <= 0 then
                self:kill(i)
            end
        end
    end
end

function Enemies:draw()
    local Utils = ctx.utils
    for _, e in ipairs(self.list) do
        if e.hitFlash > 0 then
            love.graphics.setColor(1, 1, 1)
        else
            love.graphics.setColor(e.color)
        end
        love.graphics.circle("fill", e.x, e.y, e.radius)

        -- Full-health enemies do not need a visible HP bar. Avoid drawing
        -- its background and foreground until the enemy has taken damage.
        if e.hp < e.maxHp then
            local barW = e.radius * 2
            love.graphics.setColor(0, 0, 0)
            love.graphics.rectangle("fill", e.x - e.radius, e.y - e.radius - 9, barW, 4)
            love.graphics.setColor(0.2, 0.9, 0.2)
            love.graphics.rectangle("fill", e.x - e.radius, e.y - e.radius - 9, barW * Utils.clamp(e.hp / e.maxHp, 0, 1), 4)
        end
    end
end

return Enemies