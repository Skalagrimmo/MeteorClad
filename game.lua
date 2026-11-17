-- game.lua
local Game = {
    state = "playing",
    wave = 1,
    waveTimer = 0,
    score = 0,
    choices = {}
}

local ctx

function Game:bind(gameCtx)
    ctx = gameCtx
end

function Game:reset()
    self.state = "playing"
    self.wave = 1
    self.waveTimer = 0
    self.score = 0
    self.choices = {}

    ctx.player:init()
    ctx.enemies:clear()
    ctx.projectiles:clear()
    ctx.loot:clear()
    ctx.enemies:spawnWave(self.wave)
end

function Game:triggerLevelUp()
    self.state = "levelup"
    local Player = ctx.player
    Player.level = Player.level + 1
    Player.xp = Player.xp - Player.xpToNext
    Player.xpToNext = math.floor(Player.xpToNext * 1.35)

    local available = {}
    for _, upg in ipairs(ctx.upgrades) do
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

    if #self.choices == 0 then
        self.state = "playing"
    end
end

function Game:selectUpgrade(index)
    local choice = self.choices[index]
    if choice then
        local Player = ctx.player
        choice.apply(Player)
        Player.upgradeRanks[choice.id] = (Player.upgradeRanks[choice.id] or 0) + 1

        if Player.xp >= Player.xpToNext then
            self:triggerLevelUp()
        else
            self.state = "playing"
        end
    end
end

function Game:update(dt)
    if self.state ~= "playing" then return end

    ctx.player:update(dt)
    ctx.enemies:update(dt)
    ctx.projectiles:update(dt)
    ctx.loot:update(dt)

    if #ctx.enemies.list == 0 and self.state == "playing" then
        self.waveTimer = self.waveTimer + dt
        if self.waveTimer >= ctx.config.arena.waveDelay then
            self.wave = self.wave + 1
            self.waveTimer = 0
            ctx.enemies:spawnWave(self.wave)
        end
    end
end

function Game:keypressed(key)
    if key == "r" and self.state == "gameover" then
        self:reset()
    elseif self.state == "levelup" then
        if key == "1" then self:selectUpgrade(1)
        elseif key == "2" then self:selectUpgrade(2)
        elseif key == "3" then self:selectUpgrade(3) end
    elseif key == "space" and self.state == "playing" then
        ctx.player:dash()
    end
end

function Game:mousepressed(x, y, button)
    if self.state == "levelup" and button == 1 then
        for i = 1, #self.choices do
            local cardX = 110 + (i - 1) * 200
            if x >= cardX and x <= cardX + 180 and y >= 200 and y <= 420 then
                self:selectUpgrade(i)
                return
            end
        end
    elseif self.state == "playing" then
        if button == 1 then
            ctx.player:attack(x, y)
        elseif button == 2 then
            ctx.player:whirlwind()
        end
    end
end

return Game