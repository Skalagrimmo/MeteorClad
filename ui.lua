-- ui.lua
local UI = {}

local ctx

function UI:bind(gameCtx)
    ctx = gameCtx
end

function UI:draw()
    local Player = ctx.player
    local Game = ctx.game
    local Utils = ctx.utils
    local w = ctx.config.arena.width
    local h = ctx.config.arena.height

    -- HUD: HP
    local hpRatio = Utils.clamp(Player.hp / math.max(1, Player.maxHp), 0, 1)
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 15, 15, 200, 20)
    love.graphics.setColor(0.2, 0.8, 0.3)
    love.graphics.rectangle("fill", 15, 15, 200 * hpRatio, 20)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("HP: " .. Player.hp .. "/" .. Player.maxHp, 22, 18)

    -- HUD: XP
    local xpRatio = Utils.clamp(Player.xp / math.max(1, Player.xpToNext), 0, 1)
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 15, 40, 200, 12)
    love.graphics.setColor(0.6, 0.3, 1)
    love.graphics.rectangle("fill", 15, 40, 200 * xpRatio, 12)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Рівень " .. Player.level .. " (" .. Player.xp .. "/" .. Player.xpToNext .. ")", 222, 38)

    -- HUD: Dash (Space)
    local dashReady = Utils.clamp(1 - (Player.dashCooldownTimer / math.max(0.01, Player.dashCooldown)), 0, 1)
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 15, 58, 95, 8)
    love.graphics.setColor(0.3, 0.7, 1)
    love.graphics.rectangle("fill", 15, 58, 95 * dashReady, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Dash", 115, 55)

    -- HUD: Whirlwind (ПКМ)
    local whirlReady = Utils.clamp(1 - (Player.whirlwindTimer / math.max(0.01, Player.whirlwindCooldown)), 0, 1)
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 15, 72, 95, 8)
    love.graphics.setColor(0.2, 0.95, 0.95)
    love.graphics.rectangle("fill", 15, 72, 95 * whirlReady, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Вихор (ПКМ)", 115, 69)

    -- HUD: Статистика
    love.graphics.print("Хвиля: " .. Game.wave, w - 100, 15)
    love.graphics.print("Очки: " .. Game.score, w - 100, 35)
    love.graphics.print("Шкода: " .. Player.damage, w - 100, 55)

    if #ctx.enemies.list == 0 and Game.state == "playing" then
        love.graphics.printf("Наступна хвиля через " .. string.format("%.1f", ctx.config.arena.waveDelay - Game.waveTimer) .. " с...", 0, 90, w, "center")
    end

    -- Екран Level Up
    if Game.state == "levelup" then
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", 0, 0, w, h)
        love.graphics.setColor(1, 0.85, 0.2)
        love.graphics.printf("НОВИЙ РІВЕНЬ (" .. Player.level .. ")! ОБЕРІТЬ ПОКРАЩЕННЯ:", 0, 140, w, "center")

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
        love.graphics.rectangle("fill", 0, 0, w, h)
        love.graphics.setColor(1, 0.2, 0.2)
        love.graphics.printf("ВИ ЗАГИНУЛИ", 0, 240, w, "center")
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Рівень: " .. Player.level .. " | Хвиля: " .. Game.wave .. " | Очки: " .. Game.score, 0, 270, w, "center")
        love.graphics.printf("Натисніть [R] щоб почати знову", 0, 310, w, "center")
    end
end

return UI