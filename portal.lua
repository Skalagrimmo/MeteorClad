-- portal.lua
-- Rare, unstable portals hidden in the mist. Touching one sends the player
-- to a distant, randomly selected point with a short landing grace period.

local Portals = {
    elapsed = 0,
    seed = 1,
    spawnTimer = 0,
    active = nil,
    effects = {}
}

local ctx

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function randomRange(self, minimum, maximum)
    return minimum + self:nextRandom() * (maximum - minimum)
end

local function drawArc(x, y, radius, startAngle, span, segments)
    local points = {}
    for i = 0, segments do
        local angle = startAngle + span * (i / segments)
        points[#points + 1] = x + math.cos(angle) * radius
        points[#points + 1] = y + math.sin(angle) * radius
    end
    love.graphics.line(points)
end

function Portals:bind(gameCtx)
    ctx = gameCtx
end

function Portals:nextRandom()
    -- A private generator keeps portal placement independent of combat RNG.
    self.seed = (self.seed * 48271) % 2147483647
    return (self.seed - 1) / 2147483646
end

function Portals:reset()
    local settings = ctx.config.portals or {}
    self.elapsed = 0
    self.active = nil
    self.effects = {}

    -- Vary the portal sequence between runs without consuming math.random().
    local timeSeed = os.time() % 2147483646
    self.seed = (timeSeed * 48271 + 104729) % 2147483647
    if self.seed < 1 then self.seed = 1 end

    self.spawnTimer = randomRange(
        self,
        settings.firstSpawnMin or 5,
        settings.firstSpawnMax or 9
    )
end

local function enemyClearance(x, y, player)
    local nearest = math.huge
    for _, enemy in ipairs(ctx.enemies.list) do
        local gap = distance(x, y, enemy.x, enemy.y)
            - enemy.radius - player.radius
        if gap < nearest then nearest = gap end
    end
    return nearest
end

function Portals:spawn()
    local settings = ctx.config.portals or {}
    local world = ctx.config.world
    local viewport = ctx.config.viewport
    local player = ctx.player
    local camera = ctx.camera

    if camera then camera:reset() end

    local edge = 54
    local left = math.max(edge, camera and camera.x + edge or edge)
    local top = math.max(edge, camera and camera.y + edge or edge)
    local right = math.min(
        world.width - edge,
        (camera and camera.x or 0) + viewport.width - edge
    )
    local bottom = math.min(
        world.height - edge,
        (camera and camera.y or 0) + viewport.height - edge
    )

    local minDistance = settings.spawnDistanceMin or 220
    local maxDistance = settings.spawnDistanceMax or 320
    local bestX, bestY, bestScore
    local attempts = 72

    for _ = 1, attempts do
        local angle = self:nextRandom() * math.pi * 2
        local radius = randomRange(self, minDistance, maxDistance)
        local x = player.x + math.cos(angle) * radius
        local y = player.y + math.sin(angle) * radius

        if x >= left and x <= right and y >= top and y <= bottom then
            local actualDistance = distance(player.x, player.y, x, y)
            if actualDistance >= minDistance * 0.72 then
                local clearance = enemyClearance(x, y, player)
                local score = clearance + self:nextRandom() * 18
                if bestScore == nil or score > bestScore then
                    bestX, bestY, bestScore = x, y, score
                end
                if clearance >= 105 then break end
            end
        end
    end

    if not bestX then
        -- A conservative visible fallback for very small custom viewports.
        bestX = clamp(player.x + minDistance, left, right)
        bestY = clamp(player.y, top, bottom)
        if distance(player.x, player.y, bestX, bestY) < 120 then
            bestX = clamp(player.x - minDistance, left, right)
        end
    end

    self.active = {
        x = bestX,
        y = bestY,
        age = 0,
        life = settings.activeLifetime or 32,
        phase = self:nextRandom() * math.pi * 2,
        rotation = self:nextRandom() * math.pi * 2,
        radius = settings.radius or 32
    }

    print(string.format(
        "[MeteorClad] An unstable portal has opened at %.0f, %.0f.",
        bestX,
        bestY
    ))
end

function Portals:chooseDestination(sourceX, sourceY)
    local settings = ctx.config.portals or {}
    local world = ctx.config.world
    local player = ctx.player
    local margin = math.max(110, player.radius + 72)
    local minimumTravel = settings.minTeleportDistance or 700
    local requiredClearance = settings.enemyClearance or 260
    local attempts = settings.destinationAttempts or 64

    local bestX, bestY, bestClearance
    for _ = 1, attempts do
        local x = randomRange(self, margin, world.width - margin)
        local y = randomRange(self, margin, world.height - margin)
        local travelDistance = distance(sourceX, sourceY, x, y)

        if travelDistance >= minimumTravel then
            local clearance = enemyClearance(x, y, player)
            if clearance >= requiredClearance then
                return x, y
            end
            if bestClearance == nil or clearance > bestClearance then
                bestX, bestY, bestClearance = x, y, clearance
            end
        end
    end

    -- If enemies occupy most candidate points, choose the safest distant point.
    -- A brief invulnerability window below prevents an unfair landing hit.
    if bestX then return bestX, bestY end

    -- Extremely small custom worlds may not fit the requested travel distance.
    return clamp(world.width - sourceX, margin, world.width - margin),
        clamp(world.height - sourceY, margin, world.height - margin)
end

function Portals:teleport()
    local portal = self.active
    if not portal then return false end

    local player = ctx.player
    local settings = ctx.config.portals or {}
    local sourceX, sourceY = portal.x, portal.y
    local targetX, targetY = self:chooseDestination(sourceX, sourceY)

    self.effects[#self.effects + 1] = {
        x = sourceX, y = sourceY, life = 0.58, duration = 0.58, arrival = false
    }
    self.effects[#self.effects + 1] = {
        x = targetX, y = targetY, life = 0.72, duration = 0.72, arrival = true
    }

    player.x = targetX
    player.y = targetY
    player.isDashing = false
    player.dashTimer = 0
    player.dashTrail = {}
    player.invulnTimer = math.max(
        player.invulnTimer,
        settings.landingInvulnerability or 0.9
    )

    self.active = nil
    self.spawnTimer = randomRange(
        self,
        settings.spawnDelayMin or 14,
        settings.spawnDelayMax or 22
    )

    print(string.format(
        "[MeteorClad] Portal transit: %.0f, %.0f -> %.0f, %.0f.",
        sourceX, sourceY, targetX, targetY
    ))
    return true
end

function Portals:update(dt)
    local settings = ctx.config.portals or {}
    self.elapsed = self.elapsed + dt

    for i = #self.effects, 1, -1 do
        local effect = self.effects[i]
        effect.life = effect.life - dt
        if effect.life <= 0 then
            table.remove(self.effects, i)
        end
    end

    if settings.enabled == false then return end

    if self.active then
        local portal = self.active
        portal.age = portal.age + dt
        portal.life = portal.life - dt
        portal.rotation = portal.rotation + dt * 0.42

        if portal.life <= 0 then
            self.active = nil
            self.spawnTimer = randomRange(
                self,
                settings.expireDelayMin or 8,
                settings.expireDelayMax or 14
            )
            print("[MeteorClad] The unstable portal faded.")
            return
        end

        local player = ctx.player
        local openingTime = settings.openingTime or 0.72
        local triggerRadius = player.radius + portal.radius * 0.82
        local dx = player.x - portal.x
        local dy = player.y - portal.y

        if portal.age >= openingTime
            and dx * dx + dy * dy <= triggerRadius * triggerRadius then
            self:teleport()
        end
    else
        self.spawnTimer = self.spawnTimer - dt
        if self.spawnTimer <= 0 then
            self:spawn()
        end
    end
end

function Portals:draw()
    if not self.active and #self.effects == 0 then return end

    love.graphics.push("all")

    for _, effect in ipairs(self.effects) do
        local progress = 1 - effect.life / effect.duration
        local radius = 14 + progress * (effect.arrival and 62 or 48)
        local alpha = (1 - progress) * (effect.arrival and 0.58 or 0.42)
        if effect.arrival then
            love.graphics.setColor(0.28, 0.82, 1, alpha)
        else
            love.graphics.setColor(0.72, 0.34, 1, alpha)
        end
        love.graphics.circle("line", effect.x, effect.y, radius)
        love.graphics.setColor(0.38, 0.68, 1, alpha * 0.55)
        love.graphics.circle("line", effect.x, effect.y, radius * 0.68)
    end

    local portal = self.active
    if portal then
        local openingTime = (ctx.config.portals or {}).openingTime or 0.72
        local opening = clamp(portal.age / openingTime, 0, 1)
        local fade = math.min(1, portal.life / 2.5)
        local pulse = 0.92 + 0.08 * math.sin(self.elapsed * 2.1 + portal.phase)
        local radius = portal.radius * (0.88 + opening * 0.12) * pulse
        local alpha = opening * fade

        -- A narrow dark tear sits inside two broken, rotating rings.
        love.graphics.setColor(0.25, 0.04, 0.42, 0.20 * alpha)
        love.graphics.ellipse("fill", portal.x, portal.y, radius * 1.45, radius * 1.8)
        love.graphics.setColor(0.008, 0.012, 0.028, 0.92 * alpha)
        love.graphics.ellipse("fill", portal.x, portal.y, radius * 0.58, radius * 1.02)

        love.graphics.setLineWidth(2.1)
        love.graphics.setColor(0.55, 0.30, 0.96, 0.82 * alpha)
        drawArc(
            portal.x, portal.y, radius * 1.04,
            portal.rotation, math.pi * 0.76, 22
        )
        drawArc(
            portal.x, portal.y, radius * 1.04,
            portal.rotation + math.pi * 1.13, math.pi * 0.52, 16
        )

        love.graphics.setLineWidth(1.2)
        love.graphics.setColor(0.28, 0.82, 1, 0.66 * alpha)
        drawArc(
            portal.x, portal.y, radius * 0.83,
            -portal.rotation * 0.72 + portal.phase, math.pi * 0.92, 24
        )
        drawArc(
            portal.x, portal.y, radius * 0.83,
            -portal.rotation * 0.72 + portal.phase + math.pi * 1.42,
            math.pi * 0.34, 10
        )

        -- Two faint spirals make the opening look like a depth, not a ring marker.
        for strand = 1, 2 do
            local points = {}
            for i = 0, 24 do
                local t = i / 24
                local angle = portal.rotation * (strand == 1 and 1 or -1)
                    + portal.phase + strand * math.pi + t * math.pi * 2.1
                local spiralRadius = radius * (0.08 + t * 0.54)
                points[#points + 1] = portal.x + math.cos(angle) * spiralRadius
                points[#points + 1] = portal.y + math.sin(angle) * spiralRadius * 1.55
            end
            love.graphics.setColor(0.45, 0.70, 1, 0.28 * alpha)
            love.graphics.line(points)
        end

        for i = 1, 4 do
            local angle = portal.rotation * 1.4 + i * math.pi * 0.5
            local orbit = radius * 1.22
            love.graphics.setColor(0.58, 0.78, 1, 0.72 * alpha)
            love.graphics.circle(
                "fill",
                portal.x + math.cos(angle) * orbit,
                portal.y + math.sin(angle) * orbit * 1.35,
                1.6 + 0.6 * math.sin(self.elapsed * 2 + i)
            )
        end

        love.graphics.setColor(0.76, 0.62, 1, 0.48 * (1 - opening))
        love.graphics.circle("line", portal.x, portal.y, radius * (0.72 + opening * 0.5))
    end

    love.graphics.pop()
end

return Portals
