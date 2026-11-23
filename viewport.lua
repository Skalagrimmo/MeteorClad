-- viewport.lua
-- Fits the fixed logical game viewport into any window size without stretching.
local Viewport = {
    width = 800,
    height = 600,
    windowWidth = 800,
    windowHeight = 600,
    scale = 1,
    offsetX = 0,
    offsetY = 0
}

local ctx

function Viewport:bind(gameCtx)
    ctx = gameCtx
    self.width = ctx.config.viewport.width
    self.height = ctx.config.viewport.height
end

function Viewport:update(callbackWidth, callbackHeight)
    -- love.resize supplies the new DPI-scaled dimensions in LÖVE 11.x.
    local windowWidth, windowHeight = callbackWidth, callbackHeight
    if not windowWidth or not windowHeight or windowWidth <= 0 or windowHeight <= 0 then
        windowWidth, windowHeight = love.graphics.getDimensions()
    end
    if windowWidth <= 0 or windowHeight <= 0 then
        windowWidth = self.width
        windowHeight = self.height
    end

    self.windowWidth = windowWidth
    self.windowHeight = windowHeight

    local scaleX = windowWidth / self.width
    local scaleY = windowHeight / self.height
    self.scale = math.min(scaleX, scaleY)

    if self.scale <= 0 then
        self.scale = 1
    end

    self.offsetX = math.floor((windowWidth - self.width * self.scale) * 0.5 + 0.5)
    self.offsetY = math.floor((windowHeight - self.height * self.scale) * 0.5 + 0.5)
end

function Viewport:apply()
    -- Scissor coordinates are in window space, so set them before transforms.
    local left = math.floor(self.offsetX)
    local top = math.floor(self.offsetY)
    local right = math.ceil(self.offsetX + self.width * self.scale)
    local bottom = math.ceil(self.offsetY + self.height * self.scale)
    love.graphics.setScissor(left, top, right - left, bottom - top)
    love.graphics.translate(self.offsetX, self.offsetY)
    love.graphics.scale(self.scale, self.scale)
end

function Viewport:screenToViewport(screenX, screenY)
    local right = self.offsetX + self.width * self.scale
    local bottom = self.offsetY + self.height * self.scale
    local inside = screenX >= self.offsetX and screenX < right
        and screenY >= self.offsetY and screenY < bottom

    return
        (screenX - self.offsetX) / self.scale,
        (screenY - self.offsetY) / self.scale,
        inside
end

function Viewport:clamp(x, y)
    return
        math.max(0, math.min(self.width, x)),
        math.max(0, math.min(self.height, y))
end

function Viewport:viewportToScreen(viewportX, viewportY)
    return
        self.offsetX + viewportX * self.scale,
        self.offsetY + viewportY * self.scale
end

return Viewport
