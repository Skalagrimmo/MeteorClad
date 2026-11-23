-- enemies.lua
local CircleBatch = require("circle_batch")

local Enemies = {
    list = {}
}

local ctx

function Enemies:bind(gameCtx)
    ctx = gameCtx
end

function Enemies:clear()
    self.list = {}
    if ctx.vectorLab then
        ctx.vectorLab:reset()
    end
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
    local world = ctx.config.world
    local count = 4 + waveNum * 2
    local waveScale = 1 + (waveNum - 1) * 0.15

    for i = 1, count do
        local side = math.random(1, 4)
        local x, y
        if side == 1 then x, y = math.random(0, world.width), -25
        elseif side == 2 then x, y = math.random(0, world.width), world.height + 25
        elseif side == 3 then x, y = -25, math.random(0, world.height)
        else x, y = world.width + 25, math.random(0, world.height) end

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
    local vectorLab = ctx.vectorLab
    local vectorLabActive = vectorLab and vectorLab.active == true

    if vectorLabActive then
        vectorLab:beginFrame()
    end

    for i = #self.list, 1, -1 do
        local e = self.list[i]

        if e.hp <= 0 then
            self:kill(i)
        else
            if e.hitFlash > 0 then e.hitFlash = e.hitFlash - dt end

            local dx = Player.x - e.x
            local dy = Player.y - e.y
            local distanceSquared = dx * dx + dy * dy
            local movementSpeed = 0

            if e.behavior == "melee" then
                local stopDistance = Player.radius + e.radius - 4
                if stopDistance < 0 or distanceSquared > stopDistance * stopDistance then
                    movementSpeed = e.speed
                end
            elseif e.behavior == "ranged" then
                local preferredDistance = e.preferredDist
                if preferredDistance < 0 or distanceSquared > preferredDistance * preferredDistance then
                    movementSpeed = e.speed
                else
                    local retreatDistance = preferredDistance - 60
                    if retreatDistance > 0 and distanceSquared < retreatDistance * retreatDistance then
                        movementSpeed = -e.speed * 0.7
                    end
                end
            end

            if movementSpeed ~= 0 then
                local directionX
                local directionY
                local componentScale = math.max(math.abs(dx), math.abs(dy))

                if componentScale > 0 and componentScale < math.huge then
                    -- Scale before squaring: the components are now bounded
                    -- by 1, so length calculation cannot overflow or underflow
                    -- for finite, non-zero dx/dy values.
                    local scaledX = dx / componentScale
                    local scaledY = dy / componentScale
                    local scaledLength = math.sqrt(
                        scaledX * scaledX + scaledY * scaledY
                    )
                    directionX = scaledX / scaledLength
                    directionY = scaledY / scaledLength
                else
                    -- Preserve the previous atan2(0, 0) fallback for a true
                    -- zero vector. Non-finite inputs also stay on this legacy
                    -- fallback path rather than entering scale normalization.
                    local fallbackAngle = math.atan2(dy, dx)
                    directionX = math.cos(fallbackAngle)
                    directionY = math.sin(fallbackAngle)
                end

                e.x = e.x + directionX * movementSpeed * dt
                e.y = e.y + directionY * movementSpeed * dt

                if vectorLabActive then
                    vectorLab:record(
                        e, e.x, e.y, dx, dy,
                        directionX, directionY, movementSpeed
                    )
                end
            end

            -- Preserve the original update order: move first, then spawn the
            -- projectile at the shooter's updated position.
            if e.behavior == "ranged" then
                e.shootTimer = e.shootTimer - dt
                if e.shootTimer <= 0 then
                    e.shootTimer = e.shootCooldown
                    -- dx/dy still describe the pre-movement aim direction.
                    local shootAngle = math.atan2(dy, dx)
                    ctx.projectiles:spawn(e.x, e.y, shootAngle, 240, e.damage, "enemy")
                end
            end

            local contactDistance = Player.radius + e.radius
            if contactDistance >= 0 and distanceSquared <= contactDistance * contactDistance then
                Player:takeDamage(e.damage)
            end

            if e.hp <= 0 then
                self:kill(i)
            end
        end
    end

    if vectorLabActive then
        vectorLab:endFrame()
    end
end

function Enemies:draw()
    local Utils = ctx.utils
    local hasDamagedEnemy = false

    -- Keep the original per-enemy painter order whenever HP bars are needed.
    -- The fully healthy benchmark/gameplay case can safely batch body circles.
    for _, e in ipairs(self.list) do
        if e.hp < e.maxHp then
            hasDamagedEnemy = true
            break
        end
    end

    if not hasDamagedEnemy and #self.list > 0 then
        if not self.drawBatch then
            self.drawBatch = CircleBatch:newBatch(
                math.max(CircleBatch.initialCapacity, #self.list)
            )
        end

        CircleBatch:prepare(self.drawBatch)

        local scaleFactor = 2 / CircleBatch.size
        local origin = CircleBatch.origin

        for _, e in ipairs(self.list) do
            if e.hitFlash > 0 then
                self.drawBatch:setColor(1, 1, 1, 1)
            else
                self.drawBatch:setColor(e.color[1], e.color[2], e.color[3], 1)
            end

            local scale = e.radius * scaleFactor
            self.drawBatch:add(e.x, e.y, 0, scale, scale, origin, origin)
        end

        CircleBatch:draw(self.drawBatch)
        return
    end

    -- Fallback preserves the original body/HP-bar draw order for damaged
    -- enemies, avoiding changes to how overlapping bars and bodies compose.
    for _, e in ipairs(self.list) do
        if e.hitFlash > 0 then
            love.graphics.setColor(1, 1, 1)
        else
            love.graphics.setColor(e.color)
        end
        love.graphics.circle("fill", e.x, e.y, e.radius)

        -- Full-health enemies do not need a visible HP bar.
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