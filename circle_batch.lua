-- circle_batch.lua
-- Shared antialiased circle texture and SpriteBatch helpers for small round
-- gameplay objects. The texture is generated once, then reused by both
-- projectiles and XP loot.

local CircleBatch = {
    image = nil,
    size = 64,
    origin = 32,
    initialCapacity = 256
}

function CircleBatch:init()
    if self.image then return end

    local size = self.size
    local center = size / 2
    local radius = center - 0.25
    local samplesPerAxis = 4
    local totalSamples = samplesPerAxis * samplesPerAxis
    local imageData = love.image.newImageData(size, size)

    -- Supersample the circle edge so small sprites remain visually smooth
    -- when scaled down to their in-game radius.
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local covered = 0

            for sampleY = 0, samplesPerAxis - 1 do
                local py = y + (sampleY + 0.5) / samplesPerAxis - center

                for sampleX = 0, samplesPerAxis - 1 do
                    local px = x + (sampleX + 0.5) / samplesPerAxis - center
                    if px * px + py * py <= radius * radius then
                        covered = covered + 1
                    end
                end
            end

            imageData:setPixel(x, y, 1, 1, 1, covered / totalSamples)
        end
    end

    self.image = love.graphics.newImage(imageData)
    self.image:setFilter("linear", "linear")
    imageData:release()
end

function CircleBatch:newBatch(capacity)
    if not self.image then
        error("CircleBatch:init() must be called before creating a batch.")
    end

    return love.graphics.newSpriteBatch(
        self.image,
        math.max(1, capacity or self.initialCapacity),
        "stream"
    )
end

function CircleBatch:prepare(batch, requiredSprites)
    batch:clear()

    local capacity = batch:getBufferSize()
    if requiredSprites > capacity then
        batch:setBufferSize(math.max(requiredSprites, capacity * 2))
    end
end

function CircleBatch:draw(batch)
    if batch:getCount() == 0 then return end

    -- Per-sprite SpriteBatch colors are multiplied by the global draw color.
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(batch)
end

return CircleBatch
