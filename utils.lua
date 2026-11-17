local Utils = {}

function Utils.dist(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

function Utils.normalizeAngle(a)
    while a > math.pi do a = a - 2 * math.pi end
    while a < -math.pi do a = a + 2 * math.pi end
    return a
end

function Utils.clamp(val, minVal, maxVal)
    return math.min(maxVal, math.max(minVal, val))
end

return Utils