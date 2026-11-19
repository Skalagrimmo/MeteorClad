-- benchmark.lua
-- Optional Stage F benchmark panel. Open with F6; tests run for 2 s warm-up
-- and 10 s of sampling. This module is inactive during normal gameplay.

local Benchmark = {
    open = false,
    running = false,
    elapsed = 0,
    warmup = 2,
    sampleDuration = 10,
    samples = {},
    scenario = nil,
    result = nil,
    projectileTarget = 0,
    projectileSpawnIndex = 0
}

local ctx

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function percentile(sortedValues, fraction)
    if #sortedValues == 0 then return 0 end
    local index = math.max(1, math.ceil(#sortedValues * fraction))
    return sortedValues[index]
end

local LOG_FILE = "stage_f_benchmark_results.csv"
local CSV_HEADER = table.concat({
    "time_local", "time_utc", "run_id", "scenario_id", "scenario_name",
    "vsync_during_sampling", "vsync_before_sampling", "metric_source", "love_version", "os", "window_width",
    "window_height", "fullscreen", "processor_count", "renderer_name",
    "renderer_version", "renderer_vendor", "renderer_device", "samples",
    "average_fps", "average_frame_ms", "p50_ms", "p95_ms", "p99_ms",
    "min_frame_ms", "max_frame_ms", "sampled_seconds", "enemies_end",
    "projectiles_end", "xp_orbs_end", "manual_hardware_notes"
}, ",")

local function csvEscape(value)
    local text = tostring(value == nil and "" or value)
    if text:find('[,"]') or text:find("[\r\n]") then
        return '"' .. text:gsub('"', '""') .. '"'
    end
    return text
end

local function safeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d
end

function Benchmark:getEnvironment()
    local width, height, flags = safeCall(love.window.getMode)
    flags = type(flags) == "table" and flags or {}

    local major, minor, revision = safeCall(love.getVersion)
    local osName = safeCall(love.system.getOS)
    local processorCount = safeCall(love.system.getProcessorCount)
    local rendererName, rendererVersion, rendererVendor, rendererDevice =
        safeCall(love.graphics.getRendererInfo)

    return {
        loveVersion = major and string.format("%d.%d.%d", major, minor or 0, revision or 0) or "unknown",
        os = osName or "unknown",
        width = width or 0,
        height = height or 0,
        fullscreen = flags.fullscreen == true,
        processorCount = processorCount or "",
        rendererName = rendererName or "",
        rendererVersion = rendererVersion or "",
        rendererVendor = rendererVendor or "",
        rendererDevice = rendererDevice or ""
    }
end

function Benchmark:appendLog(result)
    local saveDirectory = love.filesystem.getSaveDirectory()
    local savePath = saveDirectory .. "/" .. LOG_FILE
    local existingFile = io.open(savePath, "rb")
    local shouldWriteHeader = true

    if existingFile then
        local existingSize = existingFile:seek("end") or 0
        existingFile:close()
        shouldWriteHeader = existingSize == 0
    end

    if shouldWriteHeader then
        local headerOk, headerError = love.filesystem.write(LOG_FILE, CSV_HEADER .. "\n")
        if not headerOk then
            self.logStatus = "Log write failed: " .. tostring(headerError)
            print("[MeteorClad Benchmark] ERROR: " .. self.logStatus)
            return false
        end
    end

    local env = self.environment or {}
    local values = {
        self.runTimeLocal or os.date("%Y-%m-%d %H:%M:%S"),
        self.runTimeUTC or os.date("!%Y-%m-%dT%H:%M:%SZ"),
        self.runId or "",
        self.scenario and self.scenario.id or "",
        result.name,
        result.vsyncMode,
        self.originalVsyncMode or "unknown",
        "love.update dt",
        env.loveVersion,
        env.os,
        env.width,
        env.height,
        env.fullscreen,
        env.processorCount,
        env.rendererName,
        env.rendererVersion,
        env.rendererVendor,
        env.rendererDevice,
        result.samples,
        string.format("%.3f", result.averageFps),
        string.format("%.6f", result.averageMs),
        string.format("%.6f", result.p50Ms),
        string.format("%.6f", result.p95Ms),
        string.format("%.6f", result.p99Ms),
        string.format("%.6f", result.minMs),
        string.format("%.6f", result.maxMs),
        string.format("%.3f", result.sampledSeconds),
        result.enemies,
        result.projectiles,
        result.orbs,
        ""
    }

    local row = {}
    for i, value in ipairs(values) do
        row[i] = csvEscape(value)
    end

    local appendOk, appendError = love.filesystem.append(LOG_FILE, table.concat(row, ",") .. "\n")
    if not appendOk then
        self.logStatus = "Log write failed: " .. tostring(appendError)
        print("[MeteorClad Benchmark] ERROR: " .. self.logStatus)
        return false
    end

    self.logPath = savePath
    self.logStatus = "CSV saved: " .. LOG_FILE

    print("[MeteorClad Benchmark] CSV_LOG=" .. self.logPath)
    print(string.format(
        "[MeteorClad Benchmark] ENV love=%s os=%s cpu_threads=%s window=%dx%d fullscreen=%s renderer=%s vendor=%s device=%s",
        tostring(env.loveVersion), tostring(env.os), tostring(env.processorCount),
        tonumber(env.width) or 0, tonumber(env.height) or 0,
        tostring(env.fullscreen), tostring(env.rendererName),
        tostring(env.rendererVendor), tostring(env.rendererDevice)
    ))
    print("[MeteorClad Benchmark] CSV row appended successfully.")
    return true
end

function Benchmark:bind(gameCtx)
    ctx = gameCtx
end

function Benchmark:enableUncappedSampling()
    self.originalVsync = nil
    self.originalVsyncMode = "unknown"
    self.vsyncMode = "unchanged"

    if not love.window.getMode or not love.window.setVSync then
        print("[MeteorClad Benchmark] WARNING: cannot toggle VSync at runtime; results may be refresh-rate capped.")
        return
    end

    local ok, _, _, flags = pcall(love.window.getMode)
    if not ok or type(flags) ~= "table" or flags.vsync == nil then
        print("[MeteorClad Benchmark] WARNING: could not read current VSync mode; leaving it unchanged.")
        return
    end

    self.originalVsync = flags.vsync
    self.originalVsyncMode = tostring(flags.vsync)
    local setOk, setError = pcall(love.window.setVSync, 0)
    if setOk then
        self.vsyncMode = "disabled"
        print("[MeteorClad Benchmark] VSync disabled for sampling.")
    else
        self.originalVsync = nil
        print("[MeteorClad Benchmark] WARNING: could not disable VSync: " .. tostring(setError))
    end
end

function Benchmark:restoreVsync()
    if self.originalVsync ~= nil and love.window.setVSync then
        local restoreValue = self.originalVsync
        if restoreValue == true then restoreValue = 1 end
        if restoreValue == false then restoreValue = 0 end

        local ok, restoreError = pcall(love.window.setVSync, restoreValue)
        if not ok then
            print("[MeteorClad Benchmark] WARNING: could not restore VSync: " .. tostring(restoreError))
        else
            print("[MeteorClad Benchmark] Original VSync mode restored.")
        end
    end

    self.originalVsync = nil
end

function Benchmark:addInertEnemy()
    ctx.enemies:spawn("grunt", 24, 24, 1)
    local enemy = ctx.enemies.list[#ctx.enemies.list]
    enemy.behavior = "idle"
    enemy.speed = 0
    enemy.radius = 0.1
    enemy.hp = 999999
    enemy.maxHp = 999999
    enemy.color = {0, 0, 0, 0}
end

function Benchmark:prepareWorld()
    ctx.game:reset()
    ctx.enemies:clear()
    ctx.projectiles:clear()
    ctx.loot:clear()

    local player = ctx.player
    local arena = ctx.config.arena
    player.x = arena.width / 2
    player.y = arena.height / 2
    player.invulnTimer = 999999

    self.projectileTarget = 0
    self.projectileSpawnIndex = 0
end

function Benchmark:spawnMixedEnemies(count)
    local arena = ctx.config.arena
    local columns = math.max(1, math.ceil(math.sqrt(count * arena.width / arena.height)))
    local rows = math.ceil(count / columns)

    for i = 1, count do
        local index = i - 1
        local column = index % columns
        local row = math.floor(index / columns)
        local x = 20 + column * (arena.width - 40) / math.max(1, columns - 1)
        local y = 88 + row * (arena.height - 108) / math.max(1, rows - 1)

        -- Deterministic wave-3-like distribution: 60% Grunt, 18% Rusher,
        -- 12% Shooter and 10% Tank.
        local roll = ((i * 37) % 100) + 1
        local enemyType = "grunt"
        if roll > 90 then
            enemyType = "tank"
        elseif roll > 78 then
            enemyType = "shooter"
        elseif roll > 60 then
            enemyType = "rusher"
        end

        ctx.enemies:spawn(enemyType, x, y, 1)
        local enemy = ctx.enemies.list[#ctx.enemies.list]
        local prototype = ctx.config.enemyTypes[enemyType]
        enemy.speed = (prototype.speedMin + prototype.speedMax) / 2
        enemy.shootTimer = 0.5 + (i % 10) * 0.08
    end
end

function Benchmark:spawnOneProjectile()
    local arena = ctx.config.arena
    local index = self.projectileSpawnIndex
    self.projectileSpawnIndex = index + 1

    local side = index % 4
    local offset
    local x, y

    if side == 0 then
        offset = (index * 73) % arena.height
        x, y = 0, offset
    elseif side == 1 then
        offset = (index * 73) % arena.height
        x, y = arena.width, offset
    elseif side == 2 then
        offset = (index * 73) % arena.width
        x, y = offset, 0
    else
        offset = (index * 73) % arena.width
        x, y = offset, arena.height
    end

    local angle = math.atan2(arena.height / 2 - y, arena.width / 2 - x)
    local speed = 160 + (index % 4) * 25
    ctx.projectiles:spawn(x, y, angle, speed, 8, "enemy")
end

function Benchmark:topUpProjectiles()
    while #ctx.projectiles.list < self.projectileTarget do
        self:spawnOneProjectile()
    end
end

function Benchmark:spawnXPOrbs(count)
    local arena = ctx.config.arena
    local centerX = arena.width / 2
    local centerY = arena.height / 2
    local goldenAngle = 2.399963229728653

    for i = 1, count do
        local angle = i * goldenAngle
        local radius = 170 + (i % 9) * 18
        local x = clamp(centerX + math.cos(angle) * radius, 8, arena.width - 8)
        local y = clamp(centerY + math.sin(angle) * radius, 8, arena.height - 8)
        ctx.loot:spawnXP(x, y, 15)
    end
end

function Benchmark:startScenario(index)
    local definitions = {
        [1] = {id = 1, name = "Mixed enemies — 50", kind = "enemies", count = 50},
        [2] = {id = 2, name = "Mixed enemies — 200", kind = "enemies", count = 200},
        [3] = {id = 3, name = "Mixed enemies — 500", kind = "enemies", count = 500},
        [4] = {id = 4, name = "Mixed enemies — 1000", kind = "enemies", count = 1000},
        [5] = {id = 5, name = "Hostile projectiles — 250 active", kind = "projectiles", count = 250},
        [6] = {id = 6, name = "XP orbs — 500", kind = "loot", count = 500}
    }

    local scenario = definitions[index]
    if not scenario then return end

    self:prepareWorld()
    self:enableUncappedSampling()
    ctx.game.wave = 3

    if scenario.kind == "enemies" then
        self:spawnMixedEnemies(scenario.count)
    elseif scenario.kind == "projectiles" then
        self:addInertEnemy()
        self.projectileTarget = scenario.count
        self:topUpProjectiles()
    elseif scenario.kind == "loot" then
        self:addInertEnemy()
        self:spawnXPOrbs(scenario.count)
    end

    self.scenario = scenario
    self.elapsed = 0
    self.samples = {}
    self.result = nil
    self.runId = os.date("%Y%m%d_%H%M%S")
    self.runTimeLocal = os.date("%Y-%m-%d %H:%M:%S")
    self.runTimeUTC = os.date("!%Y-%m-%dT%H:%M:%SZ")
    self.environment = self:getEnvironment()
    self.running = true

    print("[MeteorClad Benchmark] Started: " .. scenario.name)
end

function Benchmark:finishScenario()
    local sorted = {}
    local total = 0

    for i, frameTime in ipairs(self.samples) do
        sorted[i] = frameTime
        total = total + frameTime
    end

    table.sort(sorted)

    local count = #sorted
    local averageFrameTime = count > 0 and (total / count) or 0
    local averageFps = averageFrameTime > 0 and (1 / averageFrameTime) or 0
    local minFrameTime = count > 0 and sorted[1] or 0
    local maxFrameTime = count > 0 and sorted[#sorted] or 0
    local sampledSeconds = 0

    for _, frameTime in ipairs(self.samples) do
        sampledSeconds = sampledSeconds + frameTime
    end

    self.result = {
        name = self.scenario.name,
        enemies = #ctx.enemies.list,
        projectiles = #ctx.projectiles.list,
        orbs = #ctx.loot.orbs,
        samples = count,
        averageFps = averageFps,
        averageMs = averageFrameTime * 1000,
        p50Ms = percentile(sorted, 0.50) * 1000,
        p95Ms = percentile(sorted, 0.95) * 1000,
        p99Ms = percentile(sorted, 0.99) * 1000,
        minMs = minFrameTime * 1000,
        maxMs = maxFrameTime * 1000,
        sampledSeconds = sampledSeconds,
        vsyncMode = self.vsyncMode or "unknown"
    }

    self.running = false
    self:restoreVsync()
    self:appendLog(self.result)

    local r = self.result
    print(string.format(
        "[MeteorClad Benchmark] RESULT case=%s vsync=%s enemies=%d projectiles=%d orbs=%d samples=%d avg_fps=%.2f avg_ms=%.3f p50_ms=%.3f p95_ms=%.3f p99_ms=%.3f min_ms=%.3f max_ms=%.3f sampled_s=%.3f",
        r.name, r.vsyncMode, r.enemies, r.projectiles, r.orbs, r.samples,
        r.averageFps, r.averageMs, r.p50Ms, r.p95Ms, r.p99Ms, r.minMs, r.maxMs, r.sampledSeconds
    ))
end

function Benchmark:update(dt)
    if not self.open or not self.running then return end

    -- Keep the player alive without altering enemy/projectile update work.
    ctx.player.invulnTimer = 999999

    if self.scenario and self.scenario.kind == "projectiles" then
        self:topUpProjectiles()
    end

    ctx.game:update(dt)
    self.elapsed = self.elapsed + dt

    if self.elapsed >= self.warmup then
        table.insert(self.samples, dt)
    end

    if self.elapsed >= self.warmup + self.sampleDuration then
        self:finishScenario()
    end
end

function Benchmark:close()
    self:restoreVsync()
    if self.running or self.result then
        ctx.game:reset()
    end

    self.open = false
    self.running = false
    self.scenario = nil
    self.result = nil
    self.samples = {}
end

function Benchmark:keypressed(key)
    if key == "f6" then
        if self.open then
            self:close()
        else
            self.open = true
            self.result = nil
        end
        return true
    end

    if not self.open then return false end

    if key == "escape" then
        self:close()
        return true
    end

    if not self.running then
        local index = tonumber(key)
        if index and index >= 1 and index <= 6 then
            self:startScenario(index)
        end
    end

    -- While the panel is open, prevent normal gameplay inputs.
    return true
end

function Benchmark:draw()
    if not self.open then return end

    local w = ctx.config.arena.width
    local panelX, panelY = 90, 92
    local panelW, panelH = w - 180, 452

    love.graphics.push("all")
    love.graphics.setColor(0.025, 0.035, 0.055, 0.96)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 8, 8)
    love.graphics.setColor(0.35, 0.65, 0.95, 1)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 8, 8)

    love.graphics.setColor(1, 0.86, 0.25, 1)
    love.graphics.print("STAGE F — PERFORMANCE BENCHMARK", panelX + 22, panelY + 18)
    love.graphics.setColor(0.9, 0.93, 1, 1)

    local lines = {}
    if self.running then
        local remaining = math.max(0, self.warmup + self.sampleDuration - self.elapsed)
        local phase = self.elapsed < self.warmup and "Warm-up" or "Sampling"
        table.insert(lines, "Test: " .. self.scenario.name)
        table.insert(lines, string.format("%s | %.1f s remaining | live FPS: %d",
            phase, remaining, love.timer.getFPS()))
        table.insert(lines, "Keep the window focused; do not move the player.")
        table.insert(lines, "VSync during sampling: " .. (self.vsyncMode or "unknown"))
        table.insert(lines, "The result will appear here and in the LÖVE console.")
    elseif self.result then
        local r = self.result
        table.insert(lines, "Completed: " .. r.name)
        table.insert(lines, string.format("Average FPS: %.2f | Average frame: %.3f ms", r.averageFps, r.averageMs))
        table.insert(lines, string.format("P50: %.3f ms | P95: %.3f ms | P99: %.3f ms", r.p50Ms, r.p95Ms, r.p99Ms))
        table.insert(lines, string.format("Min: %.3f ms | Max: %.3f ms | Samples: %d", r.minMs, r.maxMs, r.samples))
        table.insert(lines, "VSync during sampling: " .. r.vsyncMode)
        table.insert(lines, string.format("Objects: %d enemies | %d projectiles | %d XP orbs",
            r.enemies, r.projectiles, r.orbs))
        table.insert(lines, self.logStatus or "CSV log status: unknown")
        table.insert(lines, "CSV is in the LÖVE save directory; exact path is in the console.")
        table.insert(lines, "Press 1–6 to run another test, or Esc to reset and close.")
    else
        table.insert(lines, "[1] Mixed enemies — 50")
        table.insert(lines, "[2] Mixed enemies — 200")
        table.insert(lines, "[3] Mixed enemies — 500")
        table.insert(lines, "[4] Mixed enemies — 1000")
        table.insert(lines, "[5] Hostile projectiles — 250 active")
        table.insert(lines, "[6] XP orbs — 500")
        table.insert(lines, "Each test: 2 s warm-up + 10 s measured sampling.")
        table.insert(lines, "Each result is appended to " .. LOG_FILE .. ".")
        table.insert(lines, "Press a number to start, or Esc/F6 to return to the game.")
    end

    love.graphics.setColor(0.9, 0.93, 1, 1)
    for i, line in ipairs(lines) do
        love.graphics.print(line, panelX + 22, panelY + 58 + (i - 1) * 31)
    end

    love.graphics.pop()
end

return Benchmark
