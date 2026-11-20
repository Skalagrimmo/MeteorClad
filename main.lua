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
    vectorLab = VectorLab
}

Loot:bind(ctx)
Projectiles:bind(ctx)
Enemies:bind(ctx)
Player:bind(ctx)
Game:bind(ctx)
UI:bind(ctx)
Benchmark:bind(ctx)
VectorLab:bind(ctx)

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
    love.window.setMode(Config.arena.width, Config.arena.height)
    CircleBatch:init()
    loadInterfaceFont()
    math.randomseed(os.time())
    Game:reset()
end

function love.update(dt)
    if Benchmark.open then
        Benchmark:update(dt)
    else
        Game:update(dt)
    end
end

function love.keypressed(key)
    -- Disable vector diagnostics before a benchmark so its reference math
    -- cannot contaminate Stage F/G measurements.
    if key == "f6" and VectorLab.active then
        VectorLab:setActive(false)
    end

    if Benchmark:keypressed(key) then return end
    if VectorLab:keypressed(key) then return end
    Game:keypressed(key)
end

function love.mousepressed(x, y, button, istouch)
    if Benchmark.open then return end
    if istouch and Benchmark:isMobileLauncherHit(x, y) then return end
    Game:mousepressed(x, y, button)
end

function love.touchpressed(id, x, y, dx, dy, pressure)
    if Benchmark:touchpressed(x, y) then return end
end

local function drawProfiled(sectionName, system, profiling)
    local startedAt = profiling and love.timer.getTime() or nil

    system:draw()

    if profiling then
        Benchmark:recordProfile(sectionName, love.timer.getTime() - startedAt)
    end
end

function love.draw()
    local profiling = Benchmark:isCollectingProfile()
    local startedAt = profiling and love.timer.getTime() or nil

    drawProfiled("loot_draw_cpu", Loot, profiling)
    drawProfiled("player_draw_cpu", Player, profiling)
    drawProfiled("enemies_draw_cpu", Enemies, profiling)
    drawProfiled("projectiles_draw_cpu", Projectiles, profiling)
    drawProfiled("ui_draw_cpu", UI, profiling)
    drawProfiled("benchmark_draw_cpu", Benchmark, profiling)
    VectorLab:draw()

    if profiling then
        Benchmark:recordProfile("draw_total_cpu", love.timer.getTime() - startedAt)
    end

    if Benchmark:isAndroid() and not Benchmark.open then
        love.graphics.push("all")
        love.graphics.setColor(0.12, 0.19, 0.29, 0.9)
        love.graphics.rectangle("fill", Config.arena.width - 112, Config.arena.height - 54, 100, 44, 7, 7)
        love.graphics.setColor(0.45, 0.72, 1, 1)
        love.graphics.rectangle("line", Config.arena.width - 112, Config.arena.height - 54, 100, 44, 7, 7)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("TEST", Config.arena.width - 108, Config.arena.height - 40, 92, "center")
        love.graphics.pop()
    end
end
