-- enemies.lua
local CircleBatch = require("circle_batch")
local Style = require("visual_style")

local HIT_PULSE_LIFETIME = 0.14

local Enemies = {
    list = {}
}

local ctx

local function setStyleColor(color, alpha)
    love.graphics.setColor(color[1], color[2], color[3], alpha or 1)
end

local function drawEnemyGlyph(enemy)
    local palette = Style.enemy[enemy.type] or Style.enemy.grunt
    local r = enemy.radius
    local angle = enemy.facingAngle or 0

    love.graphics.push()
    love.graphics.translate(enemy.x, enemy.y)
    love.graphics.rotate(angle)
    love.graphics.setLineWidth(math.max(1, r * 0.075))

    setStyleColor(palette.edge, enemy.hitFlash > 0 and 0.95 or 0.88)
    love.graphics.circle("line", 0, 0, r * 0.84)

    if enemy.type == "grunt" then
        -- A broad, jagged mask with two forward-facing sensory cuts.
        love.graphics.polygon("line",
            r * 0.83, 0, r * 0.20, -r * 0.56,
            -r * 0.52, -r * 0.48, -r * 0.70, 0,
            -r * 0.52, r * 0.48, r * 0.20, r * 0.56
        )
        setStyleColor(palette.accent, 0.95)
        love.graphics.line(-r * 0.34, -r * 0.22, r * 0.30, -r * 0.22)
        love.graphics.line(-r * 0.34, r * 0.22, r * 0.30, r * 0.22)
        setStyleColor(palette.core, 1)
        love.graphics.circle("fill", r * 0.18, 0, math.max(1.6, r * 0.13))

    elseif enemy.type == "rusher" then
        -- A narrow directional blade communicates its higher movement speed.
        love.graphics.polygon("line",
            r * 0.96, 0, r * 0.16, -r * 0.50,
            -r * 0.24, -r * 0.20, -r * 0.62, -r * 0.33,
            -r * 0.39, 0, -r * 0.62, r * 0.33,
            -r * 0.24, r * 0.20, r * 0.16, r * 0.50
        )
        setStyleColor(palette.accent, 0.96)
        love.graphics.line(-r * 0.44, -r * 0.12, r * 0.55, 0)
        love.graphics.line(-r * 0.44, r * 0.12, r * 0.55, 0)
        setStyleColor(palette.core, 1)
        love.graphics.circle("fill", r * 0.36, 0, math.max(1.3, r * 0.10))

    elseif enemy.type == "tank" then
        -- Layered octagonal armor and four heavy radial seams.
        love.graphics.polygon("line",
            r * 0.58, -r * 0.48, -r * 0.12, -r * 0.74,
            -r * 0.62, -r * 0.43, -r * 0.76, r * 0.12,
            -r * 0.42, r * 0.66, r * 0.20, r * 0.72,
            r * 0.70, r * 0.36, r * 0.82, -r * 0.12
        )
        setStyleColor(palette.accent, 0.95)
        love.graphics.circle("line", 0, 0, r * 0.46)
        love.graphics.line(-r * 0.58, 0, r * 0.58, 0)
        love.graphics.line(0, -r * 0.58, 0, r * 0.58)
        setStyleColor(palette.core, 1)
        love.graphics.polygon("fill",
            r * 0.22, 0, 0, -r * 0.20, -r * 0.22, 0, 0, r * 0.20
        )

    elseif enemy.type == "shooter" then
        -- A floating reticle and eye distinguish the ranged archetype.
        love.graphics.polygon("line",
            r * 0.78, 0, 0, -r * 0.72, -r * 0.78, 0, 0, r * 0.72
        )
        setStyleColor(palette.accent, 0.96)
        love.graphics.circle("line", 0, 0, r * 0.43)
        love.graphics.line(-r * 0.62, 0, r * 0.62, 0)
        love.graphics.line(0, -r * 0.62, 0, r * 0.62)
        setStyleColor(palette.core, 1)
        love.graphics.circle("fill", r * 0.08, 0, math.max(1.6, r * 0.14))
    end

    love.graphics.pop()
end

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
        color = Style.enemy[typeName].body,
        facingAngle = math.atan2(ctx.player.y - y, ctx.player.x - x),
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
        hitFlash = 0,
        hitPulse = 0
    })
end

function Enemies:spawnWave(waveNum)
    local world = ctx.config.world
    local viewport = ctx.config.viewport
    local player = ctx.player
    local camera = ctx.camera
    local spawnMargin = ctx.config.game.enemySpawnMargin or 80
    local edgePadding = 32

    -- Use the player's current camera bounds, including movement earlier in this frame.
    if camera then camera:reset() end

    local viewLeft = camera and camera.x
        or math.max(0, math.min(world.width - viewport.width, player.x - viewport.width * 0.5))
    local viewTop = camera and camera.y
        or math.max(0, math.min(world.height - viewport.height, player.y - viewport.height * 0.5))
    local viewRight = viewLeft + viewport.width
    local viewBottom = viewTop + viewport.height

    local function randomOnViewSpan(minimum, maximum, worldMaximum)
        local low = math.max(edgePadding, math.ceil(minimum))
        local high = math.min(worldMaximum - edgePadding, math.floor(maximum))

        if low > high then
            return math.max(edgePadding, math.min(worldMaximum - edgePadding, (minimum + maximum) * 0.5))
        end

        return math.random(low, high)
    end

    -- Only use sides where the spawn margin still fits inside the world.
    -- This prevents enemies from appearing inside the viewport near world edges.
    local spawnSides = {}
    if viewTop - spawnMargin >= edgePadding then
        table.insert(spawnSides, { side = "top", fixed = viewTop - spawnMargin })
    end
    if viewBottom + spawnMargin <= world.height - edgePadding then
        table.insert(spawnSides, { side = "bottom", fixed = viewBottom + spawnMargin })
    end
    if viewLeft - spawnMargin >= edgePadding then
        table.insert(spawnSides, { side = "left", fixed = viewLeft - spawnMargin })
    end
    if viewRight + spawnMargin <= world.width - edgePadding then
        table.insert(spawnSides, { side = "right", fixed = viewRight + spawnMargin })
    end

    local function chooseSpawnPosition()
        if #spawnSides == 0 then
            -- Degenerate fallback for worlds too small to fit an off-screen margin.
            local side = math.random(1, 4)
            if side == 1 then
                return randomOnViewSpan(0, world.width, world.width), edgePadding
            elseif side == 2 then
                return randomOnViewSpan(0, world.width, world.width), world.height - edgePadding
            elseif side == 3 then
                return edgePadding, randomOnViewSpan(0, world.height, world.height)
            end
            return world.width - edgePadding, randomOnViewSpan(0, world.height, world.height)
        end

        local spawnSide = spawnSides[math.random(1, #spawnSides)]
        if spawnSide.side == "top" then
            return randomOnViewSpan(viewLeft, viewRight, world.width), spawnSide.fixed
        elseif spawnSide.side == "bottom" then
            return randomOnViewSpan(viewLeft, viewRight, world.width), spawnSide.fixed
        elseif spawnSide.side == "left" then
            return spawnSide.fixed, randomOnViewSpan(viewTop, viewBottom, world.height)
        end
        return spawnSide.fixed, randomOnViewSpan(viewTop, viewBottom, world.height)
    end

    local count = 4 + waveNum * 2
    local waveScale = 1 + (waveNum - 1) * 0.15

    for i = 1, count do
        local x, y = chooseSpawnPosition()

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
                e.hitPulse = HIT_PULSE_LIFETIME
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
            e.hitPulse = HIT_PULSE_LIFETIME
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
            if e.hitPulse > 0 then
                e.hitPulse = math.max(0, e.hitPulse - dt)
            end

            local dx = Player.x - e.x
            local dy = Player.y - e.y
            if dx ~= 0 or dy ~= 0 then e.facingAngle = math.atan2(dy, dx) end
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
    love.graphics.push("all")
    local Utils = ctx.utils
    local hasDamagedEnemy = false

    for _, enemy in ipairs(self.list) do
        if enemy.hp < enemy.maxHp then
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

        for _, enemy in ipairs(self.list) do
            if enemy.hitFlash > 0 then
                self.drawBatch:setColor(1, 1, 1, 1)
            else
                self.drawBatch:setColor(
                    enemy.color[1], enemy.color[2], enemy.color[3], 1
                )
            end

            local scale = enemy.radius * scaleFactor
            self.drawBatch:add(enemy.x, enemy.y, 0, scale, scale, origin, origin)
        end

        CircleBatch:draw(self.drawBatch)
        for _, enemy in ipairs(self.list) do
            drawEnemyGlyph(enemy)
        end
        love.graphics.pop()
        return
    end

    -- Damaged enemies keep the existing body/HP painter order.
    for _, enemy in ipairs(self.list) do
        if enemy.hitPulse > 0 then
            local progress = 1 - enemy.hitPulse / HIT_PULSE_LIFETIME
            local alpha = 0.52 * (1 - progress)
            setStyleColor(Style.impact, alpha)
            love.graphics.circle(
                "line", enemy.x, enemy.y,
                enemy.radius + 3 + progress * 12
            )
        end

        if enemy.hitFlash > 0 then
            love.graphics.setColor(1, 1, 1, 1)
        else
            setStyleColor(enemy.color, 1)
        end
        love.graphics.circle("fill", enemy.x, enemy.y, enemy.radius)
        drawEnemyGlyph(enemy)

        if enemy.hp < enemy.maxHp then
            local barW = enemy.radius * 2
            setStyleColor(Style.ui.track, 0.96)
            love.graphics.rectangle(
                "fill", enemy.x - enemy.radius,
                enemy.y - enemy.radius - 9, barW, 4
            )
            setStyleColor(Style.ui.enemyHealth, 1)
            love.graphics.rectangle(
                "fill", enemy.x - enemy.radius,
                enemy.y - enemy.radius - 9,
                barW * Utils.clamp(enemy.hp / enemy.maxHp, 0, 1), 4
            )
        end
    end
    love.graphics.pop()
end


return Enemies