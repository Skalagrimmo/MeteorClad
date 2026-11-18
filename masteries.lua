-- masteries.lua
-- Repeatable veteran bonuses unlocked after all regular perks reach maxRank.
return {
    {
        id = "mastery_sharp_steel",
        category = "mastery",
        name = "Гостріша сталь",
        desc = "+2 до базової шкоди мечем",
        apply = function(p)
            p.damage = p.damage + 2
        end
    },
    {
        id = "mastery_second_wind",
        category = "mastery",
        name = "Друге дихання",
        desc = "+10 до максимального HP та лікування до 10 HP",
        apply = function(p)
            p.maxHp = p.maxHp + 10
            p.hp = math.min(p.maxHp, p.hp + 10)
        end
    },
    {
        id = "mastery_light_step",
        category = "mastery",
        name = "Легкий крок",
        desc = "+8 до швидкості пересування",
        apply = function(p)
            p.speed = p.speed + 8
        end
    }
}
