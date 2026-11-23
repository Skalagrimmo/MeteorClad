-- fog.lua
-- Procedural, world-space mist for the expanded dark arena.
-- Textures are generated once; a lightweight shader animates their internal flow when supported.

local Fog = {
    enabled = true,
    elapsed = 0,
    textures = {},
    flowShader = nil,
    patches = {},
    motes = {},
    seed = 91357
}

local TEXTURE_WIDTH = 176
local TEXTURE_HEIGHT = 112
local TEXTURE_COUNT = 2

-- GLSL 1.x-compatible so the effect can run on older OpenGL ES devices too.
-- The noise field moves through texture space and gently bends the cloud edges.
local FOG_FLOW_SHADER = [[
extern number u_time;
extern number u_phase;
extern vec2 u_flow;
extern number u_warp;

number fogHash(vec2 p)
{
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

number fogNoise(vec2 p)
{
    vec2 cell = floor(p);
    vec2 local = fract(p);
    local = local * local * (3.0 - 2.0 * local);

    number top = mix(fogHash(cell), fogHash(cell + vec2(1.0, 0.0)), local.x);
    number bottom = mix(
        fogHash(cell + vec2(0.0, 1.0)),
        fogHash(cell + vec2(1.0, 1.0)),
        local.x
    );
    return mix(top, bottom, local.y);
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    vec2 uv = texture_coords;
    vec2 broadMotion = vec2(
        u_time * 0.065 * u_flow.x,
        u_time * 0.052 * u_flow.y
    );
    vec2 fineMotion = vec2(
        -u_time * 0.087 * u_flow.y,
        u_time * 0.076 * u_flow.x
    );

    number broad = fogNoise(
        uv * vec2(3.8, 2.7) + broadMotion + vec2(u_phase * 0.13, u_phase * 0.07)
    );
    number fine = fogNoise(
        uv * vec2(8.4, 5.6) + fineMotion + vec2(u_phase * 0.19, -u_phase * 0.11)
    );

    vec2 bend = vec2(
        (broad - 0.5) * u_warp,
        (fine - 0.5) * u_warp * 0.8
    );
    bend.x += sin(uv.y * 7.0 + fine * 2.5 + u_time * 0.17 + u_phase) * 0.007;
    bend.y += sin(uv.x * 5.5 + broad * 2.2 - u_time * 0.14 + u_phase) * 0.006;

    vec4 pixel = Texel(texture, uv + bend);
    number wispDensity = smoothstep(0.2, 0.78, fine);
    pixel.a *= mix(0.82, 1.0, wispDensity);
    return pixel * color;
}
]]

local ctx

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function smoothstep(edge0, edge1, value)
    local t = clamp((value - edge0) / (edge1 - edge0), 0, 1)
    return t * t * (3 - 2 * t)
end

local function hashNoise(x, y, seed)
    local value = math.sin(x * 127.1 + y * 311.7 + seed * 74.7) * 43758.5453
    return value - math.floor(value)
end

local function valueNoise(x, y, scale, seed)
    local sampleX = x * scale
    local sampleY = y * scale
    local x0 = math.floor(sampleX)
    local y0 = math.floor(sampleY)
    local x1 = x0 + 1
    local y1 = y0 + 1
    local tx = smoothstep(0, 1, sampleX - x0)
    local ty = smoothstep(0, 1, sampleY - y0)

    local topLeft = hashNoise(x0, y0, seed)
    local topRight = hashNoise(x1, y0, seed)
    local bottomLeft = hashNoise(x0, y1, seed)
    local bottomRight = hashNoise(x1, y1, seed)

    local top = topLeft + (topRight - topLeft) * tx
    local bottom = bottomLeft + (bottomRight - bottomLeft) * tx
    return top + (bottom - top) * ty
end

local function createFogTexture(seed)
    local imageData = love.image.newImageData(TEXTURE_WIDTH, TEXTURE_HEIGHT)

    for y = 0, TEXTURE_HEIGHT - 1 do
        local v = (y + 0.5) / TEXTURE_HEIGHT

        for x = 0, TEXTURE_WIDTH - 1 do
            local u = (x + 0.5) / TEXTURE_WIDTH

            -- Warp the noise domain so the fog edge looks torn and irregular.
            local warpX = (valueNoise(u, v, 3, seed + 1) - 0.5) * 0.28
            local warpY = (valueNoise(u, v, 3, seed + 2) - 0.5) * 0.18
            local sampleX = u + warpX
            local sampleY = v + warpY

            local broad = valueNoise(sampleX, sampleY, 4, seed + 3)
            local middle = valueNoise(sampleX, sampleY, 9, seed + 4)
            local fine = valueNoise(sampleX, sampleY, 18, seed + 5)
            local cloudNoise = broad * 0.54 + middle * 0.32 + fine * 0.14

            -- An elongated envelope keeps each cloud sheet-like rather than circular.
            local edgeVariation = (valueNoise(u, v, 4, seed + 6) - 0.5) * 0.16
            local radiusX = (u - 0.5) * 2.25
            local radiusY = (v - 0.5) * 2.55
            local radius = math.sqrt(radiusX * radiusX + radiusY * radiusY)
            local edge = 1 - smoothstep(
                0.58 + edgeVariation,
                1.02 + edgeVariation,
                radius
            )

            local density = smoothstep(0.27, 0.62, cloudNoise)
            local strands = 0.82 + 0.18 * math.sin(
                (u * 4.7 + v * 1.8 + cloudNoise * 1.4) * math.pi
            )
            local alpha = (density * edge) ^ 1.1 * 0.86 * strands
            imageData:setPixel(x, y, 1, 1, 1, clamp(alpha, 0, 0.72))
        end
    end

    local texture = love.graphics.newImage(imageData)
    texture:setFilter("linear", "linear")
    return texture
end

function Fog:bind(gameCtx)
    ctx = gameCtx
end

function Fog:nextRandom()
    -- A private Park-Miller generator keeps fog setup independent of gameplay RNG.
    self.seed = (self.seed * 48271) % 2147483647
    return (self.seed - 1) / 2147483646
end

function Fog:init()
    local settings = ctx.config.ambientFog or {}
    local world = ctx.config.world

    self.enabled = settings.enabled ~= false
    self.elapsed = 0
    self.textures = {}
    self.flowShader = nil
    self.patches = {}
    self.motes = {}
    self.seed = 91357

    for i = 1, TEXTURE_COUNT do
        local ok, textureOrError = pcall(createFogTexture, 1700 + i * 97)
        if not ok then
            print("[MeteorClad] Could not generate procedural fog: " .. tostring(textureOrError))
            self.textures = {}
            self.enabled = false
            return false
        end
        self.textures[#self.textures + 1] = textureOrError
    end

    local shaderOk, shaderOrError = pcall(love.graphics.newShader, FOG_FLOW_SHADER)
    if shaderOk then
        self.flowShader = shaderOrError
        print("[MeteorClad] Dynamic fog flow shader enabled.")
    else
        print("[MeteorClad] Dynamic fog shader unavailable; using static fog textures: "
            .. tostring(shaderOrError))
    end

    local patchCount = math.max(0, math.min(64, math.floor(settings.patchCount or 30)))
    local gridColumns = 6
    local gridRows = math.max(1, math.ceil(patchCount / gridColumns))
    local cellWidth = world.width / gridColumns
    local cellHeight = world.height / gridRows

    for i = 1, patchCount do
        local random = self:nextRandom()
        local farLayer = random < 0.42
        local width
        local height
        local opacity
        local driftSpeed

        if farLayer then
            width = 520 + self:nextRandom() * 380
            height = 190 + self:nextRandom() * 170
            opacity = 0.20 + self:nextRandom() * 0.11
            driftSpeed = 1.5 + self:nextRandom() * 3.0
        else
            width = 340 + self:nextRandom() * 340
            height = 130 + self:nextRandom() * 160
            opacity = 0.24 + self:nextRandom() * 0.13
            driftSpeed = 3.5 + self:nextRandom() * 5.5
        end

        local direction = self:nextRandom() < 0.5 and -1 or 1
        local variation = self:nextRandom()
        local column = (i - 1) % gridColumns
        local row = math.floor((i - 1) / gridColumns)
        local x = (column + 0.5 + (self:nextRandom() - 0.5) * 0.56) * cellWidth
        local y = (row + 0.5 + (self:nextRandom() - 0.5) * 0.50) * cellHeight

        self.patches[#self.patches + 1] = {
            x = x,
            y = y,
            width = width,
            height = height,
            textureIndex = math.floor(self:nextRandom() * #self.textures) + 1,
            rotation = (self:nextRandom() - 0.5) * 0.18,
            vx = direction * driftSpeed,
            vy = (self:nextRandom() - 0.5) * driftSpeed * 0.28,
            phase = self:nextRandom() * math.pi * 2,
            flowX = direction * (0.55 + self:nextRandom() * 0.55),
            flowY = (self:nextRandom() - 0.5) * 0.75,
            warp = 0.052 + self:nextRandom() * 0.022,
            pulseSpeed = 0.12 + self:nextRandom() * 0.18,
            opacity = opacity,
            color = {
                0.39 + variation * 0.07,
                0.46 + variation * 0.08,
                0.54 + variation * 0.09
            }
        }
    end

    local moteCount = math.max(0, math.min(80, math.floor(settings.moteCount or 24)))
    for i = 1, moteCount do
        self.motes[#self.motes + 1] = {
            x = self:nextRandom() * world.width,
            y = self:nextRandom() * world.height,
            vx = (self:nextRandom() - 0.5) * 2.6,
            vy = (self:nextRandom() - 0.5) * 1.8,
            radius = 0.65 + self:nextRandom() * 0.75,
            alpha = 0.08 + self:nextRandom() * 0.07,
            phase = self:nextRandom() * math.pi * 2
        }
    end

    print(string.format(
        "[MeteorClad] Procedural fog ready: %d sheets, %d dust motes.",
        #self.patches,
        #self.motes
    ))
    return true
end

function Fog:toggle()
    self.enabled = not self.enabled
    print("[MeteorClad] Ambient fog " .. (self.enabled and "enabled." or "disabled."))
    return self.enabled
end

function Fog:update(dt)
    if not self.enabled then return end

    local world = ctx.config.world
    self.elapsed = self.elapsed + dt

    for _, patch in ipairs(self.patches) do
        local wave = math.sin(self.elapsed * patch.pulseSpeed + patch.phase)
        patch.x = patch.x + (patch.vx + wave * 0.9) * dt
        patch.y = patch.y + (patch.vy + math.cos(self.elapsed * 0.11 + patch.phase) * 0.45) * dt

        local halfWidth = patch.width * 0.5
        local halfHeight = patch.height * 0.5

        if patch.x < -halfWidth then
            patch.x = world.width + halfWidth
        elseif patch.x > world.width + halfWidth then
            patch.x = -halfWidth
        end

        if patch.y < -halfHeight then
            patch.y = world.height + halfHeight
        elseif patch.y > world.height + halfHeight then
            patch.y = -halfHeight
        end
    end

    for _, mote in ipairs(self.motes) do
        mote.x = mote.x + mote.vx * dt
        mote.y = mote.y + mote.vy * dt

        if mote.x < 0 then mote.x = world.width
        elseif mote.x > world.width then mote.x = 0 end

        if mote.y < 0 then mote.y = world.height
        elseif mote.y > world.height then mote.y = 0 end
    end
end

function Fog:draw()
    if not self.enabled or #self.textures == 0 then return end

    local settings = ctx.config.ambientFog or {}
    local globalOpacity = clamp(settings.opacity or 1, 0, 1)
    local moteOpacity = clamp(settings.moteOpacity or 0.75, 0, 1)

    local flowShader = self.flowShader
    if flowShader then
        love.graphics.setShader(flowShader)
        flowShader:send("u_time", self.elapsed % 4096)
    end

    for _, patch in ipairs(self.patches) do
        if flowShader then
            flowShader:send("u_phase", patch.phase)
            flowShader:send("u_flow", {patch.flowX, patch.flowY})
            flowShader:send("u_warp", patch.warp)
        end

        local pulse = 0.94 + 0.06 * math.sin(
            self.elapsed * patch.pulseSpeed + patch.phase
        )
        love.graphics.setColor(
            patch.color[1],
            patch.color[2],
            patch.color[3],
            patch.opacity * globalOpacity * pulse
        )

        local texture = self.textures[patch.textureIndex]
        love.graphics.draw(
            texture,
            patch.x,
            patch.y,
            patch.rotation,
            patch.width / TEXTURE_WIDTH,
            patch.height / TEXTURE_HEIGHT,
            TEXTURE_WIDTH * 0.5,
            TEXTURE_HEIGHT * 0.5
        )
    end

    if flowShader then
        love.graphics.setShader()
    end

    -- Small dim motes suggest dust suspended in the mist, not a star field.
    for _, mote in ipairs(self.motes) do
        local shimmer = 0.78 + 0.22 * math.sin(self.elapsed * 0.7 + mote.phase)
        love.graphics.setColor(0.52, 0.59, 0.65, mote.alpha * moteOpacity * shimmer)
        love.graphics.circle("fill", mote.x, mote.y, mote.radius)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return Fog
