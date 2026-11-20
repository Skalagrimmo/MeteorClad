-- vector_lab.lua
-- Optional live diagnostic overlay for comparing enemy movement vectors.
-- Enable with F7. This module intentionally adds work only while active.

local VectorLab = {
    active = false,
    maxTrailPoints = 10,
    maxDrawVectors = 180,
    vectors = {},
    trails = {},
    stats = {
        count = 0,
        averageAngleError = 0,
        maxAngleError = 0,
        maxMagnitudeError = 0
    }
}

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

function VectorLab:bind(gameCtx)
    self.ctx = gameCtx
end

function VectorLab:reset()
    self.vectors = {}
    self.trails = {}
    self.frameStats = nil
    self.stats = {
        count = 0,
        averageAngleError = 0,
        maxAngleError = 0,
        maxMagnitudeError = 0
    }
end

function VectorLab:setActive(active)
    active = active == true
    if self.active == active then return end

    self.active = active
    self:reset()

    if self.active then
        print("[MeteorClad VectorLab] ACTIVE — press F7 to disable.")
        print("[MeteorClad VectorLab] Cyan = atan2/cos/sin reference; orange = normalized vector.")
    else
        print("[MeteorClad VectorLab] Disabled.")
    end
end

function VectorLab:keypressed(key)
    if key == "f7" then
        self:setActive(not self.active)
        return true
    end

    return false
end

function VectorLab:beginFrame()
    if not self.active then return end

    self.vectors = {}
    self.seenThisFrame = {}
    self.frameStats = {
        count = 0,
        angleErrorTotal = 0,
        averageAngleError = 0,
        maxAngleError = 0,
        maxMagnitudeError = 0
    }
end

function VectorLab:record(enemy, x, y, dx, dy, directionX, directionY, movementSpeed)
    if not self.active then return end

    -- movementSpeed may be negative for ranged enemies retreating from the player.
    -- Compare the final movement direction, not merely the direction toward the player.
    local movementSign = movementSpeed < 0 and -1 or 1
    local actualX = directionX * movementSign
    local actualY = directionY * movementSign

    -- Rebuild the previous trigonometric implementation as a reference.
    -- This extra work exists only while the diagnostic overlay is enabled.
    local referenceAngle = math.atan2(dy, dx)
    local referenceX = math.cos(referenceAngle) * movementSign
    local referenceY = math.sin(referenceAngle) * movementSign

    local dot = clamp(actualX * referenceX + actualY * referenceY, -1, 1)
    local cross = actualX * referenceY - actualY * referenceX
    local angleError = math.deg(math.atan2(math.abs(cross), dot))

    local actualMagnitude = math.sqrt(directionX * directionX + directionY * directionY)
    local magnitudeError = math.abs(actualMagnitude - 1)

    self.vectors[#self.vectors + 1] = {
        x = x,
        y = y,
        actualX = actualX,
        actualY = actualY,
        referenceX = referenceX,
        referenceY = referenceY,
        angleError = angleError
    }

    self.seenThisFrame[enemy] = true

    local trail = self.trails[enemy]
    if not trail then
        trail = {}
        self.trails[enemy] = trail
    end

    trail[#trail + 1] = {x = x, y = y}
    if #trail > self.maxTrailPoints then
        table.remove(trail, 1)
    end

    local stats = self.frameStats
    stats.count = stats.count + 1
    stats.angleErrorTotal = stats.angleErrorTotal + angleError
    stats.maxAngleError = math.max(stats.maxAngleError, angleError)
    stats.maxMagnitudeError = math.max(stats.maxMagnitudeError, magnitudeError)
end

function VectorLab:endFrame()
    if not self.active then return end

    -- Drop traces for enemies that stopped moving or were removed this frame.
    for enemy in pairs(self.trails) do
        if not self.seenThisFrame[enemy] then
            self.trails[enemy] = nil
        end
    end

    local stats = self.frameStats
    if stats.count > 0 then
        stats.averageAngleError = stats.angleErrorTotal / stats.count
    end
    self.stats = stats
end

local function drawArrow(x, y, directionX, directionY, length)
    local endX = x + directionX * length
    local endY = y + directionY * length
    local headLength = 5
    local headSpread = 0.48
    local backX = endX - directionX * headLength
    local backY = endY - directionY * headLength
    local perpendicularX = -directionY
    local perpendicularY = directionX

    love.graphics.line(x, y, endX, endY)
    love.graphics.line(
        endX, endY,
        backX + perpendicularX * headLength * headSpread,
        backY + perpendicularY * headLength * headSpread
    )
    love.graphics.line(
        endX, endY,
        backX - perpendicularX * headLength * headSpread,
        backY - perpendicularY * headLength * headSpread
    )
end

function VectorLab:draw()
    if not self.active then return end

    love.graphics.push("all")

    local vectors = self.vectors
    local stride = math.max(1, math.ceil(#vectors / self.maxDrawVectors))

    for index = 1, #vectors, stride do
        local vector = vectors[index]
        local perpendicularX = -vector.actualY
        local perpendicularY = vector.actualX
        local offset = 1.5

        -- Short movement history helps expose visible path kinks.
        local trail = nil
        -- The current vector list intentionally stays compact; trails are keyed
        -- by enemy and rendered from the same sampled set.
        for enemy, points in pairs(self.trails) do
            if points and #points > 1 then
                -- Find the trace whose newest point is closest to this vector.
                -- The small draw limit keeps this diagnostic-only search bounded.
                local last = points[#points]
                if math.abs(last.x - vector.x) < 0.001
                    and math.abs(last.y - vector.y) < 0.001 then
                    trail = points
                    break
                end
            end
        end

        if trail then
            love.graphics.setColor(0.65, 0.72, 0.82, 0.42)
            love.graphics.setLineWidth(1)
            for pointIndex = 2, #trail do
                local previous = trail[pointIndex - 1]
                local current = trail[pointIndex]
                love.graphics.line(previous.x, previous.y, current.x, current.y)
            end
        end

        love.graphics.setLineWidth(1.35)
        love.graphics.setColor(0.12, 0.78, 1, 0.92)
        drawArrow(
            vector.x + perpendicularX * offset,
            vector.y + perpendicularY * offset,
            vector.referenceX,
            vector.referenceY,
            22
        )

        love.graphics.setColor(1, 0.58, 0.12, 0.98)
        drawArrow(
            vector.x - perpendicularX * offset,
            vector.y - perpendicularY * offset,
            vector.actualX,
            vector.actualY,
            22
        )
    end

    local stats = self.stats
    local panelWidth = 430
    local panelHeight = 76
    love.graphics.setColor(0.015, 0.025, 0.045, 0.88)
    love.graphics.rectangle("fill", 8, 8, panelWidth, panelHeight, 5, 5)
    love.graphics.setColor(0.25, 0.62, 0.82, 0.95)
    love.graphics.rectangle("line", 8, 8, panelWidth, panelHeight, 5, 5)

    love.graphics.setColor(0.95, 0.97, 1, 1)
    love.graphics.print("VECTOR LAB  |  ACTIVE — F7: OFF", 18, 15)
    love.graphics.setColor(0.12, 0.78, 1, 1)
    love.graphics.print("CYAN: trig reference", 18, 35)
    love.graphics.setColor(1, 0.58, 0.12, 1)
    love.graphics.print("ORANGE: normalized vector", 175, 35)
    love.graphics.setColor(0.9, 0.94, 1, 1)
    love.graphics.print(string.format(
        "n=%d  mean Δangle=%.8f°  max Δangle=%.8f°",
        stats.count, stats.averageAngleError, stats.maxAngleError
    ), 18, 55)
    love.graphics.print(string.format(
        "max |norm−1|=%.3e  |  F6 turns VectorLab off before benchmarking",
        stats.maxMagnitudeError
    ), 250, 55)

    love.graphics.pop()
end

return VectorLab
