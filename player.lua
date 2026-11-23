-- player.lua
local Player = {}
local Style = require("visual_style")

local DASH_TRAIL_LIFETIME = 0.12
local DASH_TRAIL_MAX_SAMPLES = 5

local ctx

function Player:bind(gameCtx)
    ctx = gameCtx
end

function Player:init()
    local world = ctx.config.world
    self.x = world.width / 2
    self.y = world.height / 2
    self.radius = 18
    self.facingAngle = 0
    self.thrustVisual = 0
    self.speed = 220
    self.hp = 100
    self.maxHp = 100
    self.invulnTimer = 0

    -- RPG стати
    self.level = 1
    self.xp = 0
    self.xpToNext = 50
    self.pickupRadius = 100
    self.lifesteal = 0
    self.upgradeRanks = {}
    self.masteryRanks = {}

    -- Основна атака (ЛКМ)
    self.attackCooldown = 0.35
    self.attackTimer = 0
    self.isAttacking = false
    self.attackDuration = 0.15
    self.attackAnimTimer = 0
    self.attackRange = 75
    self.attackArc = 0.85
    self.attackAngle = 0
    self.damage = 25
    self.deflectMult = 2.0

    -- Спец-атака: Вихровий удар (ПКМ)
    self.whirlwindCooldown = 4.5
    self.whirlwindTimer = 0
    self.isWhirlwinding = false
    self.whirlwindDuration = 0.22
    self.whirlwindAnimTimer = 0
    self.whirlwindRange = 125
    self.whirlwindDamageMult = 1.4

    -- Ривок (Dash - Пробіл)
    self.isDashing = false
    self.dashSpeed = 680
    self.dashDuration = 0.16
    self.dashTimer = 0
    self.dashCooldown = 1.0
    self.dashCooldownTimer = 0
    self.dashDirX, self.dashDirY = 0, 0
    self.dashTrail = {}
end

function Player:scaleCooldown(fieldCooldown, fieldTimer, factor)
    local oldCd = self[fieldCooldown]
    local newCd = oldCd * factor
    self[fieldCooldown] = newCd
    if self[fieldTimer] > 0 and oldCd > 0 then
        self[fieldTimer] = self[fieldTimer] * (newCd / oldCd)
    end
end

function Player:takeDamage(amount)
    if self.isDashing or self.invulnTimer > 0 then return false end
    self.hp = self.hp - amount
    self.invulnTimer = 0.6
    if self.hp <= 0 then
        self.hp = 0
        ctx.game.state = "gameover"
    end
    return true
end

function Player:dash()
    if self.isDashing or self.dashCooldownTimer > 0 then return end
    local dx, dy = 0, 0
    if love.keyboard.isDown("w", "up") then dy = dy - 1 end
    if love.keyboard.isDown("s", "down") then dy = dy + 1 end
    if love.keyboard.isDown("a", "left") then dx = dx - 1 end
    if love.keyboard.isDown("d", "right") then dx = dx + 1 end

    if dx == 0 and dy == 0 then
        local mx, my = love.mouse.getPosition()
        mx, my = ctx.viewport:screenToViewport(mx, my)
        mx, my = ctx.viewport:clamp(mx, my)
        mx, my = ctx.camera:screenToWorld(mx, my)
        local angle = math.atan2(my - self.y, mx - self.x)
        dx, dy = math.cos(angle), math.sin(angle)
    else
        local len = math.sqrt(dx * dx + dy * dy)
        dx, dy = dx / len, dy / len
    end

    self.isDashing = true
    self.dashTimer = self.dashDuration
    self.dashCooldownTimer = self.dashCooldown
    self.dashDirX, self.dashDirY = dx, dy
    self.facingAngle = math.atan2(dy, dx)
    self.thrustVisual = 1
    self.dashTrail = {}
end

function Player:attack(targetX, targetY)
    if self.attackTimer > 0 then return end
    self.attackTimer = self.attackCooldown
    self.isAttacking = true
    self.attackAnimTimer = self.attackDuration
    self.attackAngle = math.atan2(targetY - self.y, targetX - self.x)
    self.facingAngle = self.attackAngle

    ctx.enemies:checkMeleeHit(self.x, self.y, self.attackRange, self.attackAngle, self.attackArc, self.damage, 32)
    ctx.projectiles:tryDeflect(self.x, self.y, self.attackRange + 15, self.attackAngle, self.attackArc, self.deflectMult)
end

function Player:whirlwind()
    if self.whirlwindTimer > 0 then return end
    self.whirlwindTimer = self.whirlwindCooldown
    self.isWhirlwinding = true
    self.whirlwindAnimTimer = self.whirlwindDuration

    local dmg = math.floor(self.damage * self.whirlwindDamageMult)
    ctx.enemies:checkMeleeHit(self.x, self.y, self.whirlwindRange, 0, math.pi, dmg, 60)
    ctx.projectiles:tryDeflect(self.x, self.y, self.whirlwindRange + 15, 0, math.pi, self.deflectMult)
end

function Player:update(dt)
    local world = ctx.config.world
    local Utils = ctx.utils

    if self.invulnTimer > 0 then self.invulnTimer = math.max(0, self.invulnTimer - dt) end
    if self.attackTimer > 0 then self.attackTimer = math.max(0, self.attackTimer - dt) end
    if self.whirlwindTimer > 0 then self.whirlwindTimer = math.max(0, self.whirlwindTimer - dt) end
    if self.dashCooldownTimer > 0 then self.dashCooldownTimer = math.max(0, self.dashCooldownTimer - dt) end

    -- Let the short afterimages fade independently after the dash ends.
    for i = #self.dashTrail, 1, -1 do
        local sample = self.dashTrail[i]
        sample.life = sample.life - dt
        if sample.life <= 0 then
            table.remove(self.dashTrail, i)
        end
    end

    if self.isAttacking then
        self.attackAnimTimer = self.attackAnimTimer - dt
        if self.attackAnimTimer <= 0 then self.isAttacking = false end
    end

    if self.isWhirlwinding then
        self.whirlwindAnimTimer = self.whirlwindAnimTimer - dt
        if self.whirlwindAnimTimer <= 0 then self.isWhirlwinding = false end
    end

    if self.isDashing then
        self.thrustVisual = math.min(1, self.thrustVisual + dt * 9)
        self.dashTimer = self.dashTimer - dt
        self.x = self.x + self.dashDirX * self.dashSpeed * dt
        self.y = self.y + self.dashDirY * self.dashSpeed * dt

        table.insert(self.dashTrail, {
            x = self.x,
            y = self.y,
            life = DASH_TRAIL_LIFETIME,
            angle = self.facingAngle
        })
        if #self.dashTrail > DASH_TRAIL_MAX_SAMPLES then
            table.remove(self.dashTrail, 1)
        end

        if self.dashTimer <= 0 then self.isDashing = false end
    else
        local dx, dy = 0, 0
        if love.keyboard.isDown("w", "up") then dy = dy - 1 end
        if love.keyboard.isDown("s", "down") then dy = dy + 1 end
        if love.keyboard.isDown("a", "left") then dx = dx - 1 end
        if love.keyboard.isDown("d", "right") then dx = dx + 1 end

        if dx ~= 0 or dy ~= 0 then
            local len = math.sqrt(dx * dx + dy * dy)
            self.facingAngle = math.atan2(dy, dx)
            self.thrustVisual = math.min(1, self.thrustVisual + dt * 8)
            self.x = self.x + (dx / len) * self.speed * dt
            self.y = self.y + (dy / len) * self.speed * dt
        else
            self.thrustVisual = math.max(0, self.thrustVisual - dt * 5)
        end
    end

    self.x = Utils.clamp(self.x, self.radius, world.width - self.radius)
    self.y = Utils.clamp(self.y, self.radius, world.height - self.radius)
end

local function setStyleColor(color, alpha)
    love.graphics.setColor(color[1], color[2], color[3], alpha or 1)
end

local function drawPlayerGlyph(x, y, radius, angle, alpha, thrust)
    local palette = Style.player
    local material = Style.material
    local r = radius
    alpha = alpha or 1
    thrust = math.max(0, math.min(1, thrust or 0))

    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(angle or 0)

    -- Twin vector engines and swept stabilizer wings sit behind the exosuit.
    for side = -1, 1, 2 do
        local sy = side * r * 0.34
        setStyleColor(material.shadow, alpha)
        love.graphics.polygon("fill",
            -r * 0.88, sy - r * 0.17,
            -r * 0.26, sy - r * 0.23,
            r * 0.20, sy - r * 0.12,
            r * 0.16, sy + r * 0.20,
            -r * 0.62, sy + r * 0.22
        )
        setStyleColor(palette.armor, alpha)
        love.graphics.polygon("fill",
            -r * 0.72, sy - r * 0.13,
            -r * 0.20, sy - r * 0.16,
            r * 0.16, sy - r * 0.06,
            r * 0.02, sy + r * 0.14,
            -r * 0.64, sy + r * 0.15
        )
        setStyleColor(palette.armorEdge, alpha * 0.9)
        love.graphics.polygon("line",
            -r * 0.72, sy - r * 0.13,
            -r * 0.20, sy - r * 0.16,
            r * 0.16, sy - r * 0.06,
            r * 0.02, sy + r * 0.14,
            -r * 0.64, sy + r * 0.15
        )

        setStyleColor(material.hull, alpha)
        love.graphics.circle("fill", -r * 0.76, sy, r * 0.16)
        setStyleColor(material.seam, alpha * 0.85)
        love.graphics.circle("line", -r * 0.76, sy, r * 0.16)
        setStyleColor(palette.engine, alpha * (0.55 + thrust * 0.35))
        love.graphics.circle("fill", -r * 0.80, sy, r * 0.075)
        setStyleColor(material.engineCore, alpha * (0.52 + thrust * 0.48))
        love.graphics.circle("fill", -r * 0.82, sy, r * 0.034)

        if thrust > 0.04 then
            local flameLength = r * (0.20 + thrust * 0.56)
            setStyleColor(palette.engine, alpha * 0.50 * thrust)
            love.graphics.polygon("fill",
                -r * 0.88, sy - r * 0.07,
                -r * 0.88 - flameLength, sy,
                -r * 0.88, sy + r * 0.07
            )
            setStyleColor(material.engineCore, alpha * 0.64 * thrust)
            love.graphics.line(
                -r * 0.91, sy,
                -r * 0.91 - flameLength * 0.66, sy
            )
        end
    end

    -- Broad shoulder wings provide an unmistakable aerial silhouette.
    setStyleColor(material.hull, alpha)
    love.graphics.polygon("fill",
        -r * 0.48, -r * 0.40,
        -r * 0.10, -r * 0.92,
        r * 0.44, -r * 0.66,
        r * 0.36, -r * 0.30,
        -r * 0.18, -r * 0.16
    )
    love.graphics.polygon("fill",
        -r * 0.48, r * 0.40,
        -r * 0.10, r * 0.92,
        r * 0.44, r * 0.66,
        r * 0.36, r * 0.30,
        -r * 0.18, r * 0.16
    )
    setStyleColor(palette.armorEdge, alpha)
    love.graphics.polygon("line",
        -r * 0.48, -r * 0.40,
        -r * 0.10, -r * 0.92,
        r * 0.44, -r * 0.66,
        r * 0.36, -r * 0.30
    )
    love.graphics.polygon("line",
        -r * 0.48, r * 0.40,
        -r * 0.10, r * 0.92,
        r * 0.44, r * 0.66,
        r * 0.36, r * 0.30
    )

    -- Forearm weapon hardpoints: two short, forward-facing emitters.
    for side = -1, 1, 2 do
        local sy = side * r * 0.48
        setStyleColor(material.shadow, alpha)
        love.graphics.polygon("fill",
            r * 0.12, sy - r * 0.105,
            r * 0.63, sy - r * 0.075,
            r * 0.80, sy,
            r * 0.63, sy + r * 0.075,
            r * 0.12, sy + r * 0.105
        )
        setStyleColor(palette.edge, alpha * 0.95)
        love.graphics.line(r * 0.22, sy, r * 0.73, sy)
        setStyleColor(palette.core, alpha)
        love.graphics.circle("fill", r * 0.70, sy, r * 0.055)
    end

    -- Main armored fuselage.
    setStyleColor(palette.shell, alpha)
    love.graphics.polygon("fill",
        r * 1.12, 0,
        r * 0.54, -r * 0.34,
        r * 0.12, -r * 0.48,
        -r * 0.60, -r * 0.39,
        -r * 0.94, -r * 0.18,
        -r * 0.94, r * 0.18,
        -r * 0.60, r * 0.39,
        r * 0.12, r * 0.48,
        r * 0.54, r * 0.34
    )
    setStyleColor(palette.edge, alpha * 0.92)
    love.graphics.polygon("line",
        r * 1.12, 0,
        r * 0.54, -r * 0.34,
        r * 0.12, -r * 0.48,
        -r * 0.60, -r * 0.39,
        -r * 0.94, -r * 0.18,
        -r * 0.94, r * 0.18,
        -r * 0.60, r * 0.39,
        r * 0.12, r * 0.48,
        r * 0.54, r * 0.34
    )

    -- Segmented chest plate, spine, cockpit visor and exposed reactor.
    setStyleColor(palette.armor, alpha)
    love.graphics.polygon("fill",
        r * 0.62, 0,
        r * 0.22, -r * 0.25,
        -r * 0.46, -r * 0.22,
        -r * 0.62, 0,
        -r * 0.46, r * 0.22,
        r * 0.22, r * 0.25
    )
    setStyleColor(palette.armorEdge, alpha * 0.9)
    love.graphics.polygon("line",
        r * 0.62, 0,
        r * 0.22, -r * 0.25,
        -r * 0.46, -r * 0.22,
        -r * 0.62, 0,
        -r * 0.46, r * 0.22,
        r * 0.22, r * 0.25
    )

    setStyleColor(material.seam, alpha * 0.9)
    love.graphics.line(-r * 0.55, 0, r * 0.42, 0)
    love.graphics.line(-r * 0.28, -r * 0.18, -r * 0.28, r * 0.18)
    setStyleColor(palette.visor, alpha)
    love.graphics.polygon("fill",
        r * 0.82, -r * 0.10,
        r * 0.98, 0,
        r * 0.82, r * 0.10,
        r * 0.57, r * 0.13,
        r * 0.57, -r * 0.13
    )
    setStyleColor(palette.core, alpha)
    love.graphics.circle("fill", -r * 0.08, 0, r * 0.15)
    setStyleColor(palette.bright, alpha)
    love.graphics.circle("line", -r * 0.08, 0, r * 0.22)

    -- Small panel seams and wing identification lights.
    setStyleColor(palette.edge, alpha * 0.8)
    love.graphics.line(-r * 0.32, -r * 0.30, r * 0.08, -r * 0.34)
    love.graphics.line(-r * 0.32, r * 0.30, r * 0.08, r * 0.34)
    setStyleColor(palette.core, alpha * 0.92)
    love.graphics.circle("fill", -r * 0.13, -r * 0.72, r * 0.045)
    love.graphics.circle("fill", -r * 0.13, r * 0.72, r * 0.045)

    love.graphics.pop()
end

function Player:draw()
    love.graphics.push("all")

    for _, sample in ipairs(self.dashTrail) do
        local fade = math.max(0, math.min(1, sample.life / DASH_TRAIL_LIFETIME))
        drawPlayerGlyph(
            sample.x, sample.y,
            self.radius * (0.84 + 0.10 * fade),
            sample.angle or self.facingAngle,
            0.10 + 0.20 * fade,
            0
        )
    end

    if self.isWhirlwinding then
        local progress = 1 - (self.whirlwindAnimTimer / self.whirlwindDuration)
        local alpha = 0.82 * (1 - progress)
        local ringRadius = self.whirlwindRange * (0.58 + 0.38 * progress)
        setStyleColor(Style.player.slash, alpha * 0.18)
        love.graphics.circle("fill", self.x, self.y, ringRadius * 0.90)
        setStyleColor(Style.player.bright, alpha)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", self.x, self.y, ringRadius)
        love.graphics.circle("line", self.x, self.y, ringRadius * 0.84)
        for i = 0, 3 do
            local strikeAngle = progress * 1.8 + i * math.pi * 0.5
            love.graphics.line(
                self.x + math.cos(strikeAngle) * ringRadius * 0.78,
                self.y + math.sin(strikeAngle) * ringRadius * 0.78,
                self.x + math.cos(strikeAngle) * ringRadius,
                self.y + math.sin(strikeAngle) * ringRadius
            )
        end
    end

    local haloAlpha = self.isDashing and 0.25 or 0.11
    setStyleColor(Style.player.glow, haloAlpha)
    love.graphics.circle("fill", self.x, self.y, self.radius + (self.isDashing and 8 or 5))
    setStyleColor(Style.player.bright, self.isDashing and 0.72 or 0.32)
    love.graphics.setLineWidth(1.6)
    love.graphics.circle("line", self.x, self.y, self.radius + (self.isDashing and 4 or 2))

    local bodyAlpha = 1
    if self.invulnTimer > 0 and math.floor(self.invulnTimer * 20) % 2 == 0 then
        bodyAlpha = 0.72
        setStyleColor(Style.player.core, 0.42)
        love.graphics.circle("line", self.x, self.y, self.radius + 5)
    end
    if self.isDashing then bodyAlpha = 0.94 end
    drawPlayerGlyph(
        self.x, self.y, self.radius, self.facingAngle,
        bodyAlpha, self.thrustVisual
    )

    if self.isAttacking then
        local startAngle = self.attackAngle - self.attackArc
        local endAngle = self.attackAngle + self.attackArc
        setStyleColor(Style.player.slash, 0.16)
        love.graphics.arc("line", self.x, self.y, self.attackRange * 0.78, startAngle, endAngle)
        setStyleColor(Style.player.core, 0.92)
        love.graphics.setLineWidth(2.1)
        love.graphics.arc("line", self.x, self.y, self.attackRange, startAngle, endAngle)
        for offset = -1, 1 do
            local strikeAngle = self.attackAngle + offset * self.attackArc * 0.72
            love.graphics.line(
                self.x + math.cos(strikeAngle) * self.attackRange * 0.60,
                self.y + math.sin(strikeAngle) * self.attackRange * 0.60,
                self.x + math.cos(strikeAngle) * self.attackRange,
                self.y + math.sin(strikeAngle) * self.attackRange
            )
        end
    end

    love.graphics.pop()
end


return Player