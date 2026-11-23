-- player.lua
local Player = {}

local ctx

function Player:bind(gameCtx)
    ctx = gameCtx
end

function Player:init()
    local arena = ctx.config.world
    self.x = world.width / 2
    self.y = world.height / 2
    self.radius = 18
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
end

function Player:attack(targetX, targetY)
    if self.attackTimer > 0 then return end
    self.attackTimer = self.attackCooldown
    self.isAttacking = true
    self.attackAnimTimer = self.attackDuration
    self.attackAngle = math.atan2(targetY - self.y, targetX - self.x)

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
    local arena = ctx.config.world
    local Utils = ctx.utils

    if self.invulnTimer > 0 then self.invulnTimer = math.max(0, self.invulnTimer - dt) end
    if self.attackTimer > 0 then self.attackTimer = math.max(0, self.attackTimer - dt) end
    if self.whirlwindTimer > 0 then self.whirlwindTimer = math.max(0, self.whirlwindTimer - dt) end
    if self.dashCooldownTimer > 0 then self.dashCooldownTimer = math.max(0, self.dashCooldownTimer - dt) end

    if self.isAttacking then
        self.attackAnimTimer = self.attackAnimTimer - dt
        if self.attackAnimTimer <= 0 then self.isAttacking = false end
    end

    if self.isWhirlwinding then
        self.whirlwindAnimTimer = self.whirlwindAnimTimer - dt
        if self.whirlwindAnimTimer <= 0 then self.isWhirlwinding = false end
    end

    if self.isDashing then
        self.dashTimer = self.dashTimer - dt
        self.x = self.x + self.dashDirX * self.dashSpeed * dt
        self.y = self.y + self.dashDirY * self.dashSpeed * dt
        if self.dashTimer <= 0 then self.isDashing = false end
    else
        local dx, dy = 0, 0
        if love.keyboard.isDown("w", "up") then dy = dy - 1 end
        if love.keyboard.isDown("s", "down") then dy = dy + 1 end
        if love.keyboard.isDown("a", "left") then dx = dx - 1 end
        if love.keyboard.isDown("d", "right") then dx = dx + 1 end

        if dx ~= 0 or dy ~= 0 then
            local len = math.sqrt(dx * dx + dy * dy)
            self.x = self.x + (dx / len) * self.speed * dt
            self.y = self.y + (dy / len) * self.speed * dt
        end
    end

    self.x = Utils.clamp(self.x, self.radius, world.width - self.radius)
    self.y = Utils.clamp(self.y, self.radius, world.height - self.radius)
end

function Player:draw()
    if self.isWhirlwinding then
        local progress = 1 - (self.whirlwindAnimTimer / self.whirlwindDuration)
        love.graphics.setColor(0.3, 0.85, 1, 0.35 * (1 - progress))
        love.graphics.circle("fill", self.x, self.y, self.whirlwindRange)
        love.graphics.setColor(0.6, 0.95, 1, 0.9)
        love.graphics.circle("line", self.x, self.y, self.whirlwindRange * (0.6 + 0.4 * progress))
    end

    if self.isDashing then
        love.graphics.setColor(0.4, 0.8, 1, 0.5)
    elseif self.invulnTimer > 0 and math.floor(self.invulnTimer * 20) % 2 == 0 then
        love.graphics.setColor(1, 0.3, 0.3, 0.7)
    else
        love.graphics.setColor(0.2, 0.6, 1)
    end
    love.graphics.circle("fill", self.x, self.y, self.radius)

    if self.isAttacking then
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.arc("fill", self.x, self.y, self.attackRange, self.attackAngle - self.attackArc, self.attackAngle + self.attackArc)
    end
end

return Player