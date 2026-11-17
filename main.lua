-- main.lua (v0.5.1 - Стабілізація Етапу А: F-01, F-02, F-03, F-04, F-05, F-06, F-07, F-11)

local Config, EnemyTypes, Utils, Player, Projectiles, Enemies, Loot, UpgradePool, Game

-- ============================================================================
-- 1. КОНФІГУРАЦІЯ ТА БАЛАНС (майбутній config.lua)
-- ============================================================================
Config = {
    width = 800,
    height = 600,
    waveDelay = 2.0
}

EnemyTypes = {
    grunt = {
        color = {0.9, 0.25, 0.25},
        radius = 16,
        speedMin = 95, speedMax = 125,
        hp = 40, damage = 15, xp = 15,
        knockbackResist = 1.0,
        behavior = "melee"
    },
    rusher = {
        color = {1.0, 0.55, 0.1},
        radius = 12,
        speedMin = 175, speedMax = 210,
        hp = 22, damage = 10, xp = 12,
        knockbackResist = 1.3,
        behavior = "melee"
    },
    tank = {
        color = {0.55, 0.1, 0.15},
        radius = 25,
        speedMin = 55, speedMax = 70,
        hp = 130, damage = 25, xp = 40,
        knockbackResist = 0.25,
        behavior = "melee"
    },
    shooter = {
        color = {0.75, 0.2, 0.9},
        radius = 15,
        speedMin = 85, speedMax = 105,
        hp = 35, damage = 12, xp = 25,
        knockbackResist = 1.0,
        behavior = "ranged",
        preferredDist = 250,
        shootCooldown = 2.4
    }
}

-- ============================================================================
-- 2. УТИЛІТИ (майбутній utils.lua)
-- ============================================================================
Utils = {}

function Utils.dist(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

function Utils.normalizeAngle(a)
    while a > math.pi do a = a - 2 * math.pi end
    while a < -math.pi do a = a + 2 * math.pi end
    return a
end

function Utils.clamp(val, minVal, maxVal)
    return math.min(maxVal, math.max(minVal, val))
end

-- ============================================================================
-- 3. МЕНЕДЖЕР ГРАВЦЯ (майбутній player.lua)
-- ============================================================================
Player = {}

function Player:init()
    self.x = Config.width / 2
    self.y = Config.height / 2
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
    self.upgradeRanks = {} -- облік рангів обраних перків (F-05)

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

-- F-11: Пропорційне масштабування активного таймера при зміні базового кулдауну
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
        Game.state = "gameover"
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

    Enemies:checkMeleeHit(self.x, self.y, self.attackRange, self.attackAngle, self.attackArc, self.damage, 32)
    Projectiles:tryDeflect(self.x, self.y, self.attackRange + 15, self.attackAngle, self.attackArc, self.deflectMult)
end

function Player:whirlwind()
    if self.whirlwindTimer > 0 then return end
    self.whirlwindTimer = self.whirlwindCooldown
    self.isWhirlwinding = true
    self.whirlwindAnimTimer = self.whirlwindDuration

    local dmg = math.floor(self.damage * self.whirlwindDamageMult)
    Enemies:checkMeleeHit(self.x, self.y, self.whirlwindRange, 0, math.pi, dmg, 60)
    Projectiles:tryDeflect(self.x, self.y, self.whirlwindRange + 15, 0, math.pi, self.deflectMult)
end

function Player:update(dt)
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

    self.x = Utils.clamp(self.x, self.radius, Config.width - self.radius)
    self.y = Utils.clamp(self.y, self.radius, Config.height - self.radius)
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

-- ============================================================================
-- 4. СНАРЯДИ ТА ВІДБИТТЯ (майбутній projectiles.lua)
-- ============================================================================
Projectiles = { list = {} }

function Projectiles:clear()
    self.list = {}
end

function Projectiles:spawn(x, y, angle, speed, damage, owner)
    table.insert(self.list, {
        x = x, y = y,
        vx = math.cos(angle) * speed,
        vy = math.sin(angle) * speed,
        speed = speed,
        radius = 6,
        damage = damage,
        owner = owner or "enemy"
    })
end

function Projectiles:tryDeflect(px, py, range, attackAngle, attackArc, damageMult)
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

        if hit or p.x < -50 or p.x > Config.width + 50 or p.y < -50 or p.y > Config.height + 50 then
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

-- ============================================================================
-- 5. МЕНЕДЖЕР ВОРОГІВ (майбутній enemies.lua)
-- ============================================================================
Enemies = { list = {} }

function Enemies:clear()
    self.list = {}
end

function Enemies:spawn(typeName, x, y, waveScale)
    local proto = EnemyTypes[typeName]
    local hpScaled = math.floor(proto.hp * waveScale)
    table.insert(self.list, {
        type = typeName,
        color = proto.color,
        x = x, y = y,
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
    local count = 4 + waveNum * 2
    local waveScale = 1 + (waveNum - 1) * 0.15

    for i = 1, count do
        local side = math.random(1, 4)
        local x, y
        if side == 1 then x, y = math.random(0, Config.width), -25
        elseif side == 2 then x, y = math.random(0, Config.width), Config.height + 25
        elseif side == 3 then x, y = -25, math.random(0, Config.height)
        else x, y = Config.width + 25, math.random(0, Config.height) end

        local roll = math.random(1, 100)
        local chosenType = "grunt"
        if waveNum >= 2 and roll > 60 then chosenType = "rusher" end
        if waveNum >= 2 and roll > 78 then chosenType = "shooter" end
        if waveNum >= 3 and roll > 90 then chosenType = "tank" end

        self:spawn(chosenType, x, y, waveScale)
    end
end

function Enemies:checkMeleeHit(px, py, range, attackAngle, attackArc, damage, baseKnockback)
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
    for _, e in ipairs(self.list) do
        if e.hp > 0 and Utils.dist(cx, cy, e.x, e.y) <= radius + e.radius then
            e.hp = e.hp - damage
            e.hitFlash = 0.12
        end
    end
end

-- F-02: Єдина функція обробки смерті ворога (одна видача XP/очок)
function Enemies:kill(index)
    local e = self.list[index]
    if not e then return end
    Game.score = Game.score + e.xp
    if Player.lifesteal > 0 then
        Player.hp = math.min(Player.maxHp, Player.hp + Player.lifesteal)
    end
    Loot:spawnXP(e.x, e.y, e.xp)
    table.remove(self.list, index)
end

function Enemies:update(dt)
    for i = #self.list, 1, -1 do
        local e = self.list[i]

        -- F-02: Мертвий ворог видаляється ДО виконання AI або контактної атаки
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
                    Projectiles:spawn(e.x, e.y, angle, 240, e.damage, "enemy")
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
    for _, e in ipairs(self.list) do
        if e.hitFlash > 0 then
            love.graphics.setColor(1, 1, 1)
        else
            love.graphics.setColor(e.color)
        end
        love.graphics.circle("fill", e.x, e.y, e.radius)

        local barW = e.radius * 2
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("fill", e.x - e.radius, e.y - e.radius - 9, barW, 4)
        love.graphics.setColor(0.2, 0.9, 0.2)
        love.graphics.rectangle("fill", e.x - e.radius, e.y - e.radius - 9, barW * Utils.clamp(e.hp / e.maxHp, 0, 1), 4)
    end
end

-- ============================================================================
-- 6. ЛУТ ТА ПРОГРЕСІЯ (майбутній loot.lua & upgrades.lua)
-- ============================================================================
Loot = { orbs = {} }

-- F-05, F-06, F-11: Узгоджені описи, ранги (maxRank) та пропорційне зменшення кулдаунів
UpgradePool = {
    { id = "sharp_blade", name = "Гострий клинок", maxRank = 5, desc = "+30% до шкоди мечем", apply = function(p) p.damage = math.floor(p.damage * 1.3) end },
    { id = "battle_trance", name = "Бойовий транс", maxRank = 4, desc = "-20% інтервалу між атаками", apply = function(p) p:scaleCooldown("attackCooldown", "attackTimer", 0.8) end },
    { id = "wide_swing", name = "Широкий замах", maxRank = 4, desc = "+20% до дальності та дуги удару", apply = function(p) p.attackRange = p.attackRange * 1.2; p.attackArc = math.min(math.pi, p.attackArc * 1.2) end },
    { id = "shadow_step", name = "Тіньовий крок", maxRank = 3, desc = "-25% кулдаун ривка та +15% швидкість", apply = function(p) p:scaleCooldown("dashCooldown", "dashCooldownTimer", 0.75); p.speed = p.speed * 1.15 end },
    { id = "vampirism", name = "Вампіризм", maxRank = 4, desc = "+4 HP за кожного вбитого ворога", apply = function(p) p.lifesteal = p.lifesteal + 4 end },
    { id = "titan_heart", name = "Серце титана", maxRank = 5, desc = "+30 макс. HP та лікування", apply = function(p) p.maxHp = p.maxHp + 30; p.hp = math.min(p.maxHp, p.hp + 30) end },
    { id = "whirlwind_master", name = "Майстер вихору", maxRank = 3, desc = "-30% кулдаун Вихору (ПКМ) та +25% шкоди", apply = function(p) p:scaleCooldown("whirlwindCooldown", "whirlwindTimer", 0.7); p.whirlwindDamageMult = p.whirlwindDamageMult * 1.25 end },
    { id = "kinetic_deflect", name = "Кінетичне відбиття", maxRank = 3, desc = "Відбиті снаряди завдають у 1.5x більше шкоди", apply = function(p) p.deflectMult = p.deflectMult * 1.5 end }
}

function Loot:clear()
    self.orbs = {}
end

function Loot:spawnXP(x, y, value)
    table.insert(self.orbs, { x = x, y = y, value = value, radius = value >= 30 and 7 or 5 })
end

function Loot:update(dt)
    for i = #self.orbs, 1, -1 do
        local orb = self.orbs[i]
        local d = Utils.dist(Player.x, Player.y, orb.x, orb.y)

        if d <= Player.pickupRadius then
            local angle = math.atan2(Player.y - orb.y, Player.x - orb.x)
            orb.x = orb.x + math.cos(angle) * 400 * dt
            orb.y = orb.y + math.sin(angle) * 400 * dt
            -- F-07: Перераховуємо дистанцію після зсуву сфери в поточному кадрі
            d = Utils.dist(Player.x, Player.y, orb.x, orb.y)
        end

        if d <= Player.radius + orb.radius then
            Player.xp = Player.xp + orb.value
            table.remove(self.orbs, i)
            if Player.xp >= Player.xpToNext then
                Game:triggerLevelUp()
                break
            end
        end
    end
end

function Loot:draw()
    for _, orb in ipairs(self.orbs) do
        love.graphics.setColor(0.2, 1, 0.5)
        love.graphics.circle("fill", orb.x, orb.y, orb.radius)
    end
end

-- ============================================================================
-- 7. ЯДРО ГРИ ТА UI (main.lua / ui.lua)
-- ============================================================================
Game = {
    state = "playing",
    wave = 1,
    waveTimer = 0,
    score = 0,
    choices = {}
}

function Game:reset()
    self.state = "playing"
    self.wave = 1
    self.waveTimer = 0
    self.score = 0
    self.choices = {}

    Player:init()
    Enemies:clear()
    Projectiles:clear()
    Loot:clear()
    Enemies:spawnWave(self.wave)
end

function Game:triggerLevelUp()
    self.state = "levelup"
    Player.level = Player.level + 1
    Player.xp = Player.xp - Player.xpToNext
    Player.xpToNext = math.floor(Player.xpToNext * 1.35)

    -- F-05: Обираємо лише перки, які не досягли свого maxRank
    local available = {}
    for _, upg in ipairs(UpgradePool) do
        local currentRank = Player.upgradeRanks[upg.id] or 0
        if currentRank < upg.maxRank then
            table.insert(available, upg)
        end
    end

    self.choices = {}
    for i = 1, 3 do
        if #available > 0 then
            local idx = math.random(1, #available)
            table.insert(self.choices, available[idx])
            table.remove(available, idx)
        end
    end

    -- Якщо всі перки прокачано до максимуму — повертаємося у бій
    if #self.choices == 0 then
        self.state = "playing"
    end
end

function Game:selectUpgrade(index)
    local choice = self.choices[index]
    if choice then
        choice.apply(Player)
        Player.upgradeRanks[choice.id] = (Player.upgradeRanks[choice.id] or 0) + 1

        -- F-01: Якщо надлишку XP вистачає на наступний рівень — відкриваємо новий вибір одразу
        if Player.xp >= Player.xpToNext then
            self:triggerLevelUp()
        else
            self.state = "playing"
        end
    end
end

function love.load()
    love.window.setTitle("MeteorClad - Hack'n'Slash RPG v0.5.1")
    love.window.setMode(Config.width, Config.height)
    math.randomseed(os.time())
    Game:reset()
end

function love.update(dt)
    if Game.state ~= "playing" then return end

    Player:update(dt)
    Enemies:update(dt)
    Projectiles:update(dt)
    Loot:update(dt)

    if #Enemies.list == 0 and Game.state == "playing" then
        Game.waveTimer = Game.waveTimer + dt
        if Game.waveTimer >= Config.waveDelay then
            Game.wave = Game.wave + 1
            Game.waveTimer = 0
            Enemies:spawnWave(Game.wave)
        end
    end
end

function love.keypressed(key)
    if key == "r" and Game.state == "gameover" then
        Game:reset()
    elseif Game.state == "levelup" then
        if key == "1" then Game:selectUpgrade(1)
        elseif key == "2" then Game:selectUpgrade(2)
        elseif key == "3" then Game:selectUpgrade(3) end
    elseif key == "space" and Game.state == "playing" then
        Player:dash()
    end
end

function love.mousepressed(x, y, button)
    if Game.state == "levelup" and button == 1 then
        for i = 1, #Game.choices do
            local cardX = 110 + (i - 1) * 200
            if x >= cardX and x <= cardX + 180 and y >= 200 and y <= 420 then
                Game:selectUpgrade(i)
                return
            end
        end
    elseif Game.state == "playing" then
        if button == 1 then
            Player:attack(x, y)
        elseif button == 2 then
            Player:whirlwind()
        end
    end
end

function love.draw()
    Loot:draw()
    Player:draw()
    Enemies:draw()
    Projectiles:draw()

    -- HUD: HP
    local hpRatio = Utils.clamp(Player.hp / math.max(1, Player.maxHp), 0, 1)
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 15, 15, 200, 20)
    love.graphics.setColor(0.2, 0.8, 0.3)
    love.graphics.rectangle("fill", 15, 15, 200 * hpRatio, 20)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("HP: " .. Player.hp .. "/" .. Player.maxHp, 22, 18)

    -- HUD: XP (F-04: затиснуто в [0, 1])
    local xpRatio = Utils.clamp(Player.xp / math.max(1, Player.xpToNext), 0, 1)
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 15, 40, 200, 12)
    love.graphics.setColor(0.6, 0.3, 1)
    love.graphics.rectangle("fill", 15, 40, 200 * xpRatio, 12)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Рівень " .. Player.level .. " (" .. Player.xp .. "/" .. Player.xpToNext .. ")", 222, 38)

    -- HUD: Dash (Space) (F-03: затиснуто в [0, 1])
    local dashReady = Utils.clamp(1 - (Player.dashCooldownTimer / math.max(0.01, Player.dashCooldown)), 0, 1)
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 15, 58, 95, 8)
    love.graphics.setColor(0.3, 0.7, 1)
    love.graphics.rectangle("fill", 15, 58, 95 * dashReady, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Dash", 115, 55)

    -- HUD: Whirlwind (ПКМ) (F-03: затиснуто в [0, 1])
    local whirlReady = Utils.clamp(1 - (Player.whirlwindTimer / math.max(0.01, Player.whirlwindCooldown)), 0, 1)
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 15, 72, 95, 8)
    love.graphics.setColor(0.2, 0.95, 0.95)
    love.graphics.rectangle("fill", 15, 72, 95 * whirlReady, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Вихор (ПКМ)", 115, 69)

    -- HUD: Статистика
    love.graphics.print("Хвиля: " .. Game.wave, 700, 15)
    love.graphics.print("Очки: " .. Game.score, 700, 35)
    love.graphics.print("Шкода: " .. Player.damage, 700, 55)

    if #Enemies.list == 0 and Game.state == "playing" then
        love.graphics.printf("Наступна хвиля через " .. string.format("%.1f", Config.waveDelay - Game.waveTimer) .. " с...", 0, 90, Config.width, "center")
    end

    -- Екран Level Up
    if Game.state == "levelup" then
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", 0, 0, Config.width, Config.height)
        love.graphics.setColor(1, 0.85, 0.2)
        love.graphics.printf("НОВИЙ РІВЕНЬ (" .. Player.level .. ")! ОБЕРІТЬ ПОКРАЩЕННЯ:", 0, 140, Config.width, "center")

        for i, choice in ipairs(Game.choices) do
            local cardX = 110 + (i - 1) * 200
            local nextRank = (Player.upgradeRanks[choice.id] or 0) + 1

            love.graphics.setColor(0.15, 0.18, 0.25)
            love.graphics.rectangle("fill", cardX, 200, 180, 220, 8, 8)
            love.graphics.setColor(0.4, 0.6, 1)
            love.graphics.rectangle("line", cardX, 200, 180, 220, 8, 8)

            love.graphics.setColor(1, 0.85, 0.2)
            love.graphics.printf("[" .. i .. "] " .. choice.name .. " (" .. nextRank .. "/" .. choice.maxRank .. ")", cardX + 10, 220, 160, "center")
            love.graphics.setColor(0.9, 0.9, 0.9)
            love.graphics.printf(choice.desc, cardX + 15, 280, 150, "center")
        end
    end

    -- Екран Game Over
    if Game.state == "gameover" then
        love.graphics.setColor(0, 0, 0, 0.75)
        love.graphics.rectangle("fill", 0, 0, Config.width, Config.height)
        love.graphics.setColor(1, 0.2, 0.2)
        love.graphics.printf("ВИ ЗАГИНУЛИ", 0, 240, Config.width, "center")
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Рівень: " .. Player.level .. " | Хвиля: " .. Game.wave .. " | Очки: " .. Game.score, 0, 270, Config.width, "center")
        love.graphics.printf("Натисніть [R] щоб почати знову", 0, 310, Config.width, "center")
    end
end
-- END OF FILE v0.5.1