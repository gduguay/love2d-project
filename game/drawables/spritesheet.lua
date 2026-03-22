-- SpriteSheet drawable: renders a single quad from a sprite sheet grid.
-- Compatible with the drawAt(x, y) interface used by RenderSystem.
local Object = require("modules.object")

local SpriteSheet = Object:new()

function SpriteSheet:__init__(params)
    self:__checkNotNil(params.image, "image")
    self:__checkNotNil(params.quadWidth, "quadWidth")
    self:__checkNotNil(params.quadHeight, "quadHeight")

    self.image = params.image
    self.quadWidth = params.quadWidth
    self.quadHeight = params.quadHeight

    local imgW, imgH = self.image:getDimensions()
    self.cols = math.floor(imgW / self.quadWidth)
    self.rows = math.floor(imgH / self.quadHeight)

    -- Build quad grid (row-major, 1-indexed)
    self.quads = {}
    for row = 0, self.rows - 1 do
        for col = 0, self.cols - 1 do
            table.insert(self.quads, love.graphics.newQuad(
                col * self.quadWidth,
                row * self.quadHeight,
                self.quadWidth,
                self.quadHeight,
                imgW, imgH
            ))
        end
    end

    self.currentQuad = 1
end

-- Set frame by 1-based linear index
function SpriteSheet:setFrame(index)
    self.currentQuad = math.max(1, math.min(index, #self.quads))
end

-- Set frame by col, row (both 1-based)
function SpriteSheet:setQuad(col, row)
    local index = (row - 1) * self.cols + col
    self:setFrame(index)
end

-- Draw centered at (x, y) — matches Sprite/Text drawable interface
function SpriteSheet:drawAt(x, y)
    local quad = self.quads[self.currentQuad]
    if not quad then return end
    local ox = self.quadWidth / 2
    local oy = self.quadHeight / 2
    love.graphics.draw(self.image, quad, x - ox, y - oy)
end

return SpriteSheet
