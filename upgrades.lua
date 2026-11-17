return {
    { id = "sharp_blade", name = "Гострий клинок", maxRank = 5, desc = "+30% до шкоди мечем", apply = function(p) p.damage = math.floor(p.damage * 1.3) end },
    { id = "battle_trance", name = "Бойовий транс", maxRank = 4, desc = "-20% інтервалу між атаками", apply = function(p) p:scaleCooldown("attackCooldown", "attackTimer", 0.8) end },
    { id = "wide_swing", name = "Широкий замах", maxRank = 4, desc = "+20% до дальності та дуги удару", apply = function(p) p.attackRange = p.attackRange * 1.2; p.attackArc = math.min(math.pi, p.attackArc * 1.2) end },
    { id = "shadow_step", name = "Тіньовий крок", maxRank = 3, desc = "-25% кулдаун ривка та +15% швидкість", apply = function(p) p:scaleCooldown("dashCooldown", "dashCooldownTimer", 0.75); p.speed = p.speed * 1.15 end },
    { id = "vampirism", name = "Вампіризм", maxRank = 4, desc = "+4 HP за кожного вбитого ворога", apply = function(p) p.lifesteal = p.lifesteal + 4 end },
    { id = "titan_heart", name = "Серце титана", maxRank = 5, desc = "+30 макс. HP та лікування", apply = function(p) p.maxHp = p.maxHp + 30; p.hp = math.min(p.maxHp, p.hp + 30) end },
    { id = "whirlwind_master", name = "Майстер вихору", maxRank = 3, desc = "-30% кулдаун Вихору (ПКМ) та +25% шкоди", apply = function(p) p:scaleCooldown("whirlwindCooldown", "whirlwindTimer", 0.7); p.whirlwindDamageMult = p.whirlwindDamageMult * 1.25 end },
    { id = "kinetic_deflect", name = "Кінетичне відбиття", maxRank = 3, desc = "Відбиті снаряди завдають у 1.5x більше шкоди", apply = function(p) p.deflectMult = p.deflectMult * 1.5 end }
}