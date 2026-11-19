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
    benchmark = Benchmark
}

Loot:bind(ctx)
Projectiles:bind(ctx)
Enemies:bind(ctx)
Player:bind(ctx)
Game:bind(ctx)
UI:bind(ctx)
Benchmark:bind(ctx)

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
    if Benchmark:keypressed(key) then return end
    Game:keypressed(key)
end

function love.mousepressed(x, y, button)
    if Benchmark.open then return end
    Game:mousepressed(x, y, button)
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

    if profiling then
        Benchmark:recordProfile("draw_total_cpu", love.timer.getTime() - startedAt)
    end
end
