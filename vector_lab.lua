-- vector_lab.lua
-- Optional live and synthetic vector diagnostics. All extra work is opt-in.

local VectorLab = {
    active = false,
    radialOpen = false,
    maxTrailPoints = 10,
    maxDrawVectors = 180,
    maxRadialDrawVectors = 420,
    vectors = {},
    trails = {},
    radialVectors = {},
    radialStats = nil,
    runSequence = 0,
    stats = {
        count = 0,
        averageAngleError = 0,
        maxAngleError = 0,
        maxMagnitudeError = 0
    }
}

-- v3 compares the original PR #8 normalization against a scale-safe candidate.
-- Separate files preserve all v1/v2 measurements unchanged.
local SUMMARY_LOG = "vector_lab_summary_v3.csv"
local DATA_LOG = "vector_lab_vectors_v3.csv"

local SUMMARY_HEADER = table.concat({
    "time_local", "time_utc", "run_id", "test_id", "vector_count",
    "legacy_valid_vectors", "legacy_invalid_vectors", "legacy_overflow_vectors",
    "legacy_fallback_vectors", "legacy_average_angle_error_deg",
    "legacy_p95_angle_error_deg", "legacy_max_angle_error_deg",
    "legacy_average_component_error", "legacy_max_component_error",
    "legacy_average_magnitude_error", "legacy_max_magnitude_error",
    "safe_valid_vectors", "safe_invalid_vectors", "safe_fallback_vectors",
    "safe_average_angle_error_deg", "safe_p95_angle_error_deg",
    "safe_max_angle_error_deg", "safe_average_component_error",
    "safe_max_component_error", "safe_average_magnitude_error",
    "safe_max_magnitude_error", "min_input_magnitude", "max_input_magnitude"
}, ",")

local DATA_HEADER = table.concat({
    "time_local", "time_utc", "run_id", "test_id", "vector_index",
    "vector_case", "dx", "dy", "input_magnitude", "distance_squared",
    "legacy_status", "legacy_direction_valid", "legacy_x", "legacy_y",
    "legacy_angle_error_deg", "legacy_component_error",
    "legacy_magnitude_error", "legacy_used_fallback",
    "safe_status", "safe_direction_valid", "safe_x", "safe_y",
    "safe_angle_error_deg", "safe_component_error",
    "safe_magnitude_error", "safe_used_fallback",
    "reference_x", "reference_y"
}, ",")

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function number(value)
    if value == nil then return "" end
    if value == math.huge then return "inf" end
    if value == -math.huge then return "-inf" end
    if value ~= value then return "nan" end
    return string.format("%.17g", value)
end

local function csvEscape(value)
    local text = tostring(value == nil and "" or value)
    if text:find('[,"]') or text:find("[\r\n]") then
        return '"' .. text:gsub('"', '""') .. '"'
    end
    return text
end

local function csvRow(values)
    local row = {}
    for index, value in ipairs(values) do
        row[index] = csvEscape(value)
    end
    return table.concat(row, ",")
end

local function percentile(sortedValues, fraction)
    if #sortedValues == 0 then return 0 end
    local index = math.max(1, math.ceil(#sortedValues * fraction))
    return sortedValues[index]
end

local function measureDirection(referenceX, referenceY, directionX, directionY)
    local magnitude = math.sqrt(directionX * directionX + directionY * directionY)
    local directionValid = magnitude > 0 and magnitude < math.huge
        and magnitude == magnitude

    local angleError
    if directionValid then
        local dot = clamp(
            directionX * referenceX + directionY * referenceY,
            -1, 1
        )
        local cross = directionX * referenceY - directionY * referenceX
        angleError = math.deg(math.atan2(math.abs(cross), dot))
    end

    return {
        x = directionX,
        y = directionY,
        directionValid = directionValid,
        angleError = angleError,
        componentError = math.max(
            math.abs(directionX - referenceX),
            math.abs(directionY - referenceY)
        ),
        magnitudeError = math.abs(magnitude - 1)
    }
end

local function compareVector(dx, dy)
    -- Trigonometric reference (the previous movement implementation).
    local referenceAngle = math.atan2(dy, dx)
    local referenceX = math.cos(referenceAngle)
    local referenceY = math.sin(referenceAngle)

    -- Candidate A: current PR #8 algorithm, kept exactly for comparison.
    local distanceSquared = dx * dx + dy * dy
    local legacyX
    local legacyY
    local legacyFallback = distanceSquared <= 0
    local legacyOverflow = distanceSquared == math.huge
    local legacyStatus

    if legacyOverflow then
        local inverseDistance = 1 / math.sqrt(distanceSquared)
        legacyX = dx * inverseDistance
        legacyY = dy * inverseDistance
        legacyStatus = "distance_squared_overflow"
    elseif legacyFallback then
        legacyX = referenceX
        legacyY = referenceY
        legacyStatus = (dx == 0 and dy == 0)
            and "zero_length_fallback"
            or "underflow_fallback"
    else
        local inverseDistance = 1 / math.sqrt(distanceSquared)
        legacyX = dx * inverseDistance
        legacyY = dy * inverseDistance
        legacyStatus = "normalized"
    end

    local legacy = measureDirection(
        referenceX, referenceY, legacyX, legacyY
    )
    legacy.status = legacyStatus
    legacy.usedFallback = legacyFallback
    legacy.overflowedDistance = legacyOverflow

    -- Candidate B: scale-safe normalization.
    -- Divide by the largest absolute component first. Both scaled components
    -- are within [-1, 1], so their squared sum cannot overflow; for any
    -- representable nonzero input, the largest scaled component is +/-1,
    -- preventing the squared length from underflowing to zero.
    local componentScale = math.max(math.abs(dx), math.abs(dy))
    local safeX
    local safeY
    local safeFallback = componentScale == 0
    local safeStatus

    if safeFallback then
        -- A true zero vector has no mathematical direction; preserve the
        -- platform's former atan2(0, 0) fallback for behavior compatibility.
        safeX = referenceX
        safeY = referenceY
        safeStatus = "zero_length_fallback"
    elseif componentScale == math.huge or componentScale ~= componentScale then
        safeX = 0
        safeY = 0
        safeStatus = "non_finite_input"
    else
        local scaledX = dx / componentScale
        local scaledY = dy / componentScale
        local scaledLength = math.sqrt(scaledX * scaledX + scaledY * scaledY)
        safeX = scaledX / scaledLength
        safeY = scaledY / scaledLength
        safeStatus = "scale_safe_normalized"
    end

    local safe = measureDirection(
        referenceX, referenceY, safeX, safeY
    )
    safe.status = safeStatus
    safe.usedFallback = safeFallback
    safe.overflowedDistance = false

    return {
        dx = dx,
        dy = dy,
        distanceSquared = distanceSquared,
        referenceX = referenceX,
        referenceY = referenceY,
        legacy = legacy,
        safe = safe,
        legacyOverflow = legacyOverflow
    }
end
local function appendCsv(path, header, rows)
    local info = love.filesystem.getInfo(path, "file")
    if not info or not info.size or info.size == 0 then
        local writeOk, writeError = love.filesystem.write(path, header .. "\n")
        if not writeOk then
            return false, tostring(writeError or "could not write CSV header")
        end
    end

    if #rows > 0 then
        local appendOk, appendError = love.filesystem.append(
            path, table.concat(rows, "\n") .. "\n"
        )
        if not appendOk then
            return false, tostring(appendError or "could not append CSV rows")
        end
    end

    local verified = love.filesystem.getInfo(path, "file")
    if not verified then
        return false, "CSV append completed but file verification failed"
    end

    return true, verified.size or 0
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
        print("[MeteorClad VectorLab] LIVE mode active — press F7 to disable.")
        print("[MeteorClad VectorLab] Cyan = trig reference; orange = normalized vector.")
    else
        print("[MeteorClad VectorLab] Live mode disabled.")
    end
end

function VectorLab:openRadial()
    if self.active then
        self:setActive(false)
    end

    self.radialOpen = true
    self.radialVectors = {}
    self.radialStats = nil
    self.radialStatus = "Choose 1, 2 or 3 to run a radial test."
    print("[MeteorClad VectorLab] Radial stress mode opened.")
end

function VectorLab:closeRadial()
    self.radialOpen = false
    self.radialVectors = {}
    self.radialStats = nil
    self.radialStatus = nil
    print("[MeteorClad VectorLab] Radial stress mode closed.")
end

function VectorLab:keypressed(key)
    if self.radialOpen then
        if key == "escape" or key == "f8" then
            self:closeRadial()
            return true
        elseif key == "1" then
            self:runRadialTest(100)
            return true
        elseif key == "2" then
            self:runRadialTest(500)
            return true
        elseif key == "3" then
            self:runRadialTest(1000)
            return true
        end

        -- Keep gameplay and level-up inputs from leaking through the lab screen.
        return true
    end

    if key == "f8" then
        self:openRadial()
        return true
    elseif key == "f7" then
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
    local movementSign = movementSpeed < 0 and -1 or 1
    local actualX = directionX * movementSign
    local actualY = directionY * movementSign

    local referenceAngle = math.atan2(dy, dx)
    local referenceX = math.cos(referenceAngle) * movementSign
    local referenceY = math.sin(referenceAngle) * movementSign

    local dot = clamp(actualX * referenceX + actualY * referenceY, -1, 1)
    local cross = actualX * referenceY - actualY * referenceX
    local angleError = math.deg(math.atan2(math.abs(cross), dot))

    local actualMagnitude = math.sqrt(directionX * directionX + directionY * directionY)
    local magnitudeError = math.abs(actualMagnitude - 1)

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

    self.vectors[#self.vectors + 1] = {
        x = x,
        y = y,
        actualX = actualX,
        actualY = actualY,
        referenceX = referenceX,
        referenceY = referenceY,
        trail = trail
    }

    local stats = self.frameStats
    stats.count = stats.count + 1
    stats.angleErrorTotal = stats.angleErrorTotal + angleError
    stats.maxAngleError = math.max(stats.maxAngleError, angleError)
    stats.maxMagnitudeError = math.max(stats.maxMagnitudeError, magnitudeError)
end

function VectorLab:endFrame()
    if not self.active then return end

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

function VectorLab:runRadialTest(vectorCount)
    if not self.radialOpen then return false end

    local scales = {
        0, 1e-200, 1e-12, 1e-9, 1e-6, 1e-3,
        0.1, 1, 16, 250, 1e6, 1e12, 1e100,
        1e154, 1.34e154, 1.5e154, 1e155, 1e200, 1e308
    }
    local arena = self.ctx.config.arena
    local centerX = arena.width * 0.5
    local centerY = arena.height * 0.57
    local displayRadius = math.min(arena.width, arena.height) * 0.39

    local vectors = {}
    local legacyAngleErrors = {}
    local safeAngleErrors = {}
    local legacy = {
        valid = 0, invalid = 0, overflow = 0, fallback = 0,
        angleTotal = 0, maxAngle = 0,
        componentTotal = 0, maxComponent = 0,
        magnitudeTotal = 0, maxMagnitude = 0
    }
    local safe = {
        valid = 0, invalid = 0, fallback = 0,
        angleTotal = 0, maxAngle = 0,
        componentTotal = 0, maxComponent = 0,
        magnitudeTotal = 0, maxMagnitude = 0
    }
    local minScale = math.huge
    local maxScale = 0

    self.runSequence = self.runSequence + 1
    local timeLocal = os.date("%Y-%m-%d %H:%M:%S")
    local timeUtc = os.date("!%Y-%m-%dT%H:%M:%SZ")
    local runId = os.date("%Y%m%d_%H%M%S") .. "_" .. tostring(self.runSequence)
    local testId = "radial_" .. tostring(vectorCount)

    for index = 1, vectorCount do
        local fraction = (index - 0.5) / vectorCount
        -- Golden-angle sampling fills the disk without concentric-ring clumping.
        local angle = (index - 1) * (math.pi * (3 - math.sqrt(5)))
        local visualRadius = displayRadius * math.sqrt(fraction)
        local scale = scales[((index - 1) % #scales) + 1]

        local dx, dy
        if scale == 0 then
            dx, dy = 0, 0
        else
            -- Vectors point inward toward the field's center.
            dx = -math.cos(angle) * scale
            dy = -math.sin(angle) * scale
        end

        local comparison = compareVector(dx, dy)
        local x = centerX + math.cos(angle) * visualRadius
        local y = centerY + math.sin(angle) * visualRadius
        local caseName = "radial"
        if scale == 0 then
            caseName = "zero_length"
        elseif comparison.legacy.status == "underflow_fallback" then
            caseName = "underflow_boundary"
        elseif comparison.legacyOverflow then
            caseName = "overflow_boundary"
        end

        vectors[#vectors + 1] = {
            index = index,
            x = x,
            y = y,
            dx = dx,
            dy = dy,
            scale = scale,
            caseName = caseName,
            referenceX = comparison.referenceX,
            referenceY = comparison.referenceY,
            legacy = comparison.legacy,
            safe = comparison.safe
        }

        local legacyResult = comparison.legacy
        if legacyResult.directionValid then
            legacy.valid = legacy.valid + 1
            legacyAngleErrors[#legacyAngleErrors + 1] = legacyResult.angleError
            legacy.angleTotal = legacy.angleTotal + legacyResult.angleError
            legacy.maxAngle = math.max(legacy.maxAngle, legacyResult.angleError)
        else
            legacy.invalid = legacy.invalid + 1
        end
        if legacyResult.overflowedDistance then legacy.overflow = legacy.overflow + 1 end
        if legacyResult.usedFallback then legacy.fallback = legacy.fallback + 1 end
        legacy.componentTotal = legacy.componentTotal + legacyResult.componentError
        legacy.maxComponent = math.max(legacy.maxComponent, legacyResult.componentError)
        legacy.magnitudeTotal = legacy.magnitudeTotal + legacyResult.magnitudeError
        legacy.maxMagnitude = math.max(legacy.maxMagnitude, legacyResult.magnitudeError)

        local safeResult = comparison.safe
        if safeResult.directionValid then
            safe.valid = safe.valid + 1
            safeAngleErrors[#safeAngleErrors + 1] = safeResult.angleError
            safe.angleTotal = safe.angleTotal + safeResult.angleError
            safe.maxAngle = math.max(safe.maxAngle, safeResult.angleError)
        else
            safe.invalid = safe.invalid + 1
        end
        if safeResult.usedFallback then safe.fallback = safe.fallback + 1 end
        safe.componentTotal = safe.componentTotal + safeResult.componentError
        safe.maxComponent = math.max(safe.maxComponent, safeResult.componentError)
        safe.magnitudeTotal = safe.magnitudeTotal + safeResult.magnitudeError
        safe.maxMagnitude = math.max(safe.maxMagnitude, safeResult.magnitudeError)

        minScale = math.min(minScale, scale)
        maxScale = math.max(maxScale, scale)
    end

    table.sort(legacyAngleErrors)
    table.sort(safeAngleErrors)
    local count = #vectors
    local stats = {
        count = count,
        legacy = {
            valid = legacy.valid, invalid = legacy.invalid, overflow = legacy.overflow,
            fallback = legacy.fallback,
            averageAngle = legacy.angleTotal / math.max(1, legacy.valid),
            p95Angle = percentile(legacyAngleErrors, 0.95),
            maxAngle = legacy.maxAngle,
            averageComponent = legacy.componentTotal / math.max(1, count),
            maxComponent = legacy.maxComponent,
            averageMagnitude = legacy.magnitudeTotal / math.max(1, count),
            maxMagnitude = legacy.maxMagnitude
        },
        safe = {
            valid = safe.valid, invalid = safe.invalid, fallback = safe.fallback,
            averageAngle = safe.angleTotal / math.max(1, safe.valid),
            p95Angle = percentile(safeAngleErrors, 0.95),
            maxAngle = safe.maxAngle,
            averageComponent = safe.componentTotal / math.max(1, count),
            maxComponent = safe.maxComponent,
            averageMagnitude = safe.magnitudeTotal / math.max(1, count),
            maxMagnitude = safe.maxMagnitude
        },
        minScale = minScale,
        maxScale = maxScale,
        runId = runId,
        testId = testId,
        timeLocal = timeLocal,
        timeUtc = timeUtc
    }

    local dataRows = {}
    for index, vector in ipairs(vectors) do
        local old = vector.legacy
        local candidate = vector.safe
        dataRows[#dataRows + 1] = csvRow({
            timeLocal, timeUtc, runId, testId, index, vector.caseName,
            number(vector.dx), number(vector.dy), number(vector.scale),
            number((vector.dx * vector.dx) + (vector.dy * vector.dy)),
            old.status, tostring(old.directionValid),
            number(old.x), number(old.y), number(old.angleError),
            number(old.componentError), number(old.magnitudeError),
            tostring(old.usedFallback),
            candidate.status, tostring(candidate.directionValid),
            number(candidate.x), number(candidate.y), number(candidate.angleError),
            number(candidate.componentError), number(candidate.magnitudeError),
            tostring(candidate.usedFallback),
            number(vector.referenceX), number(vector.referenceY)
        })
    end

    local summaryRow = csvRow({
        timeLocal, timeUtc, runId, testId, count,
        stats.legacy.valid, stats.legacy.invalid, stats.legacy.overflow,
        stats.legacy.fallback, number(stats.legacy.averageAngle),
        number(stats.legacy.p95Angle), number(stats.legacy.maxAngle),
        number(stats.legacy.averageComponent), number(stats.legacy.maxComponent),
        number(stats.legacy.averageMagnitude), number(stats.legacy.maxMagnitude),
        stats.safe.valid, stats.safe.invalid, stats.safe.fallback,
        number(stats.safe.averageAngle), number(stats.safe.p95Angle),
        number(stats.safe.maxAngle), number(stats.safe.averageComponent),
        number(stats.safe.maxComponent), number(stats.safe.averageMagnitude),
        number(stats.safe.maxMagnitude), number(minScale), number(maxScale)
    })

    local dataOk, dataResult = appendCsv(DATA_LOG, DATA_HEADER, dataRows)
    local summaryOk, summaryResult = appendCsv(SUMMARY_LOG, SUMMARY_HEADER, {summaryRow})
    local saveDirectory = love.filesystem.getSaveDirectory()
    self.radialVectors = vectors
    self.radialStats = stats

    if dataOk and summaryOk then
        self.radialStatus = string.format(
            "Saved v3 CSV logs (%s bytes data / %s bytes summary)",
            tostring(dataResult), tostring(summaryResult)
        )
        self.radialDataPath = saveDirectory .. "/" .. DATA_LOG
        self.radialSummaryPath = saveDirectory .. "/" .. SUMMARY_LOG
        print("[MeteorClad VectorLab] SUMMARY_CSV=" .. self.radialSummaryPath)
        print("[MeteorClad VectorLab] DATA_CSV=" .. self.radialDataPath)
        print(string.format(
            "[MeteorClad VectorLab] %s legacy invalid=%d overflow=%d | safe invalid=%d fallback=%d | safe max angle=%.12g° max norm error=%.12g",
            testId, stats.legacy.invalid, stats.legacy.overflow,
            stats.safe.invalid, stats.safe.fallback,
            stats.safe.maxAngle, stats.safe.maxMagnitude
        ))
    else
        self.radialStatus = "CSV error — data: " .. tostring(dataOk and "OK" or dataResult)
            .. " | summary: " .. tostring(summaryOk and "OK" or summaryResult)
        print("[MeteorClad VectorLab] ERROR: " .. self.radialStatus)
        print("[MeteorClad VectorLab] SAVE_DIR=" .. saveDirectory)
    end

    return true
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

function VectorLab:drawRadial()
    local w = self.ctx.config.arena.width
    local h = self.ctx.config.arena.height

    love.graphics.setColor(0.012, 0.02, 0.038, 0.97)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(0.24, 0.42, 0.58, 0.85)
    love.graphics.printf("VECTOR STRESS LAB — RADIAL FIELD", 0, 18, w, "center")

    love.graphics.setColor(0.12, 0.78, 1, 1)
    love.graphics.print("CYAN: trig reference", 18, 48)
    love.graphics.setColor(1, 0.58, 0.12, 1)
    love.graphics.print("ORANGE: normalized vector", 205, 48)
    love.graphics.setColor(0.82, 0.88, 0.96, 1)
    love.graphics.print("[1] 100 vectors   [2] 500 vectors   [3] 1000 vectors", 18, 72)

    if #self.radialVectors > 0 then
        local centerX = w * 0.5
        local centerY = h * 0.57
        local radius = math.min(w, h) * 0.39
        love.graphics.setColor(0.18, 0.32, 0.44, 0.55)
        love.graphics.circle("line", centerX, centerY, radius)

        local stride = math.max(1, math.ceil(#self.radialVectors / self.maxRadialDrawVectors))
        for index = 1, #self.radialVectors, stride do
            local vector = self.radialVectors[index]
            local perpendicularX = -vector.normalizedY
            local perpendicularY = vector.normalizedX

            love.graphics.setLineWidth(1)
            love.graphics.setColor(0.12, 0.78, 1, 0.9)
            drawArrow(
                vector.x + perpendicularX * 1.2,
                vector.y + perpendicularY * 1.2,
                vector.referenceX, vector.referenceY, 17
            )

            love.graphics.setColor(1, 0.58, 0.12, 0.98)
            drawArrow(
                vector.x - perpendicularX * 1.2,
                vector.y - perpendicularY * 1.2,
                vector.normalizedX, vector.normalizedY, 17
            )
        end
    else
        love.graphics.setColor(0.72, 0.8, 0.9, 0.85)
        love.graphics.printf(
            "This mode pauses gameplay. Choose a radial test to generate the vector field.",
            70, h * 0.46, w - 140, "center"
        )
    end

    if self.radialStats then
        local stats = self.radialStats
        love.graphics.setColor(0.015, 0.025, 0.045, 0.94)
        love.graphics.rectangle("fill", 10, h - 132, w - 20, 122, 5, 5)
        love.graphics.setColor(0.25, 0.62, 0.82, 0.95)
        love.graphics.rectangle("line", 10, h - 132, w - 20, 122, 5, 5)
        love.graphics.setColor(0.94, 0.97, 1, 1)
        love.graphics.print(string.format(
            "%s | mean Δangle %.10g° | P95 %.10g° | max %.10g°",
            stats.testId, stats.averageAngleError,
            stats.p95AngleError, stats.maxAngleError
        ), 20, h - 123)
        love.graphics.print(string.format(
            "component max %.3e | norm max %.3e",
            stats.maxComponentError, stats.maxMagnitudeError
        ), 20, h - 101)
        love.graphics.print(string.format(
            "fallbacks %d | invalid directions %d | squared-distance overflow %d",
            stats.fallbackCount, stats.invalidDirectionCount, stats.overflowCount
        ), 20, h - 79)
        love.graphics.print(self.radialStatus or "CSV status unavailable", 20, h - 57)
        love.graphics.print(
            "CSV v2 files are in the LÖVE save directory. F6 = benchmark; Esc/F8 = close.",
            20, h - 35
        )
    else
        love.graphics.setColor(0.78, 0.85, 0.94, 0.9)
        love.graphics.printf(
            "Scales span zero, underflow, normal, large and overflow boundaries. Esc/F8 closes.",
            20, h - 48, w - 40, "center"
        )
    end
end

function VectorLab:draw()
    if self.radialOpen then
        love.graphics.push("all")
        self:drawRadial()
        love.graphics.pop()
        return
    end

    if not self.active then return end

    love.graphics.push("all")

    local vectors = self.vectors
    local stride = math.max(1, math.ceil(#vectors / self.maxDrawVectors))

    for index = 1, #vectors, stride do
        local vector = vectors[index]
        local perpendicularX = -vector.actualY
        local perpendicularY = vector.actualX
        local offset = 1.5

        local trail = vector.trail
        if trail and #trail > 1 then
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
            vector.referenceX, vector.referenceY, 22
        )

        love.graphics.setColor(1, 0.58, 0.12, 0.98)
        drawArrow(
            vector.x - perpendicularX * offset,
            vector.y - perpendicularY * offset,
            vector.actualX, vector.actualY, 22
        )
    end

    local stats = self.stats
    local panelX, panelY = 230, 8
    local panelWidth, panelHeight = 430, 94
    love.graphics.setColor(0.015, 0.025, 0.045, 0.88)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 5, 5)
    love.graphics.setColor(0.25, 0.62, 0.82, 0.95)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 5, 5)

    love.graphics.setColor(0.95, 0.97, 1, 1)
    love.graphics.print("VECTOR LAB  |  ACTIVE — F7: OFF", panelX + 10, panelY + 7)
    love.graphics.setColor(0.12, 0.78, 1, 1)
    love.graphics.print("CYAN: trig reference", panelX + 10, panelY + 27)
    love.graphics.setColor(1, 0.58, 0.12, 1)
    love.graphics.print("ORANGE: normalized vector", panelX + 167, panelY + 27)
    love.graphics.setColor(0.9, 0.94, 1, 1)
    love.graphics.print(string.format(
        "n=%d  mean Δangle=%.8f°  max Δangle=%.8f°",
        stats.count, stats.averageAngleError, stats.maxAngleError
    ), panelX + 10, panelY + 47)
    love.graphics.print(string.format(
        "max |norm - 1|=%.3e  |  F6 = benchmark / auto-off",
        stats.maxMagnitudeError
    ), panelX + 10, panelY + 66)

    love.graphics.pop()
end

return VectorLab
