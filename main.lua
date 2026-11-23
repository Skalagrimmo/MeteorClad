-- main.lua (Модульна точка входу - Stage C3)

local Config = require("config")
local Utils = require("utils")
local UpgradePool = require("upgrades")
local MasteryPool = require("masteries")
local Loot = require("loot")
local Projectiles = require("projectiles")
local Enemies = require("enemies")
local Player = require("player")
local Game = require("game")
local UI = require("ui")
local Benchmark = require("benchmark")
local VectorLab = require("vector_lab")
local CircleBatch = require("circle_batch")
local Camera = require("camera")

local ctx = {
    config = Config,
    utils = Utils,
    upgrades = UpgradePool,
    masteries = MasteryPool,
    loot = Loot,
    projectiles = Projectiles,
    enemies = Enemies,
    player = Player,
    game = Game,
    ui = UI,
    benchmark = Benchmark,
    vectorLab = VectorLab,
    camera = Camera
}

Loot:bind(ctx)
Projectiles:bind(ctx)
Enemies:bind(ctx)
Player:bind(ctx)
Game:bind(ctx)
UI:bind(ctx)
Benchmark:bind(ctx)
VectorLab:bind(ctx)
Camera:bind(ctx)

local function loadInterfaceFont()
    local fontPath = "fonts/NotoSans-Regular.ttf"

    if not love.filesystem.getInfo(fontPath, "file") then
        print("[MeteorClad] Ukrainian font is missing: " .. fontPath)
        print("[MeteorClad] Download Noto Sans Regular and place it at the path above.")
        return
    end

    local ok, fontOrError = pcall(love.graphics.newFont, fontPath, 12)
    if not ok then
        print("[MeteorClad] Could not load Noto Sans: " .. tostring(fontOrError))
        print("[MeteorClad] Falling back to the LÖVE default font.")
        return
    end

    love.graphics.setFont(fontOrError)
    print("[MeteorClad] Loaded bundled Noto Sans UI font.")
end

function love.load()
    love.window.setTitle("MeteorClad - Hack'n'Slash RPG (Modular v0.6)")
    love.window.setMode(Config.viewport.width, Config.viewport.height)
    CircleBatch:init()
    loadInterfaceFont()
    math.randomseed(os.time())
    Game:reset()
end

function love.update(dt)
    if Benchmark.open then
        Benchmark:update(dt)
    elseif VectorLab.radialOpen then
        -- The controlled radial test is stationary; pause the game simulation.
        return
    else
        Game:update(dt)
        Camera:update(dt)
    end
end

function love.keypressed(key)
    -- F6 always closes VectorLab modes before opening the benchmark panel.
    if key == "f6" then
        if VectorLab.radialOpen then
            VectorLab:closeRadial()
        end
        if VectorLab.active then
            VectorLab:setActive(false)
        end
    end

    if Benchmark:keypressed(key) then return end
    if VectorLab:keypressed(key) then return end
    Game:keypressed(key)
end

function love.mousepressed(x, y, button, istouch)
    if Benchmark.open or VectorLab.radialOpen then return end
    if istouch and Benchmark:isMobileLauncherHit(x, y) then return end
    if Game.state == "playing" then
        x, y = Camera:screenToWorld(x, y)
    end
    Game:mousepressed(x, y, button)
end

function love.touchpressed(id, x, y, dx, dy, pressure)
    if VectorLab.radialOpen then return end
    if Benchmark:touchpressed(x, y) then
        -- The Android TEST launcher can open F6 without a keyboard event.
        if Benchmark.open and VectorLab.active then
            VectorLab:setActive(false)
        end
        return
    end
end

local function drawProfiled(sectionName, system, profiling)
    local startedAt = profiling and love.timer.getTime() or nil

    system:draw()

    if profiling then
        Benchmark:recordProfile(sectionName, love.timer.getTime() - startedAt)
    end
end

function love.draw()
    if VectorLab.radialOpen then
        VectorLab:draw()
        return
    end

    local profiling = Benchmark:isCollectingProfile()
    local startedAt = profiling and love.timer.getTime() or nil

    -- World-space entities share one camera transform.
    love.graphics.push("all")
    Camera:apply()
    drawProfiled("loot_draw_cpu", Loot, profiling)
    drawProfiled("player_draw_cpu", Player, profiling)
    drawProfiled("enemies_draw_cpu", Enemies, profiling)
    drawProfiled("projectiles_draw_cpu", Projectiles, profiling)
    love.graphics.pop()

    -- HUD, modal screens and benchmark UI remain in viewport coordinates.
    drawProfiled("ui_draw_cpu", UI, profiling)
    drawProfiled("benchmark_draw_cpu", Benchmark, profiling)

    if profiling then
        Benchmark:recordProfile("draw_total_cpu", love.timer.getTime() - startedAt)
    end

    -- F7 arrows and trails follow the world; its statistics panel stays fixed.
    love.graphics.push("all")
    Camera:apply()
    VectorLab:drawWorld()
    love.graphics.pop()
    VectorLab:draw()

    if Benchmark:isAndroid() and not Benchmark.open then
        local viewport = Config.viewport
        love.graphics.push("all")
        love.graphics.setColor(0.12, 0.19, 0.29, 0.9)
        love.graphics.rectangle("fill", viewport.width - 112, viewport.height - 54, 100, 44, 7, 7)
        love.graphics.setColor(0.45, 0.72, 1, 1)
        love.graphics.rectangle("line", viewport.width - 112, viewport.height - 54, 100, 44, 7, 7)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("TEST", viewport.width - 108, viewport.height - 40, 92, "center")
        love.graphics.pop()
    end
end
