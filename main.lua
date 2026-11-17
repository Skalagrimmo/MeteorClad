-- main.lua (Фінальна модульна точка входу - Stage C3)

local Config = require("config")
local Utils = require("utils")
local UpgradePool = require("upgrades")
local Loot = require("loot")
local Projectiles = require("projectiles")
local Enemies = require("enemies")
local Player = require("player")
local Game = require("game")
local UI = require("ui")

local ctx = {
    config = Config,
    utils = Utils,
    upgrades = UpgradePool,
    loot = Loot,
    projectiles = Projectiles,
    enemies = Enemies,
    player = Player,
    game = Game,
    ui = UI
}

Loot:bind(ctx)
Projectiles:bind(ctx)
Enemies:bind(ctx)
Player:bind(ctx)
Game:bind(ctx)
UI:bind(ctx)

function love.load()
    love.window.setTitle("MeteorClad - Hack'n'Slash RPG (Modular v0.6)")
    love.window.setMode(Config.arena.width, Config.arena.height)
    math.randomseed(os.time())
    Game:reset()
end

function love.update(dt)
    Game:update(dt)
end

function love.keypressed(key)
    Game:keypressed(key)
end

function love.mousepressed(x, y, button)
    Game:mousepressed(x, y, button)
end

function love.draw()
    Loot:draw()
    Player:draw()
    Enemies:draw()
    Projectiles:draw()
    UI:draw()
end