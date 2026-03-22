local Object = require("modules.object")

local Sprite = Object:new()

function Sprite:__init__(params)
    self.image = params.image or nil
end

function Sprite:drawAt(x, y)
    local imgW, imgH = self.image:getDimensions()
    local cx, cy = imgW / 2, imgH / 2
    love.graphics.draw(self.image, x - cx, y - cy)
end

return Sprite