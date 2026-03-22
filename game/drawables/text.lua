local Object = require("modules.object")

local Text = Object:new()

function Text:__init__(params)
    self.string = params.string or ""
    self.font = params.font or love.graphics.getFont()
    self.centered = params.centered or false
end

function Text:drawAt(x, y)
    local font = self.font or love.graphics.getFont()
    love.graphics.setFont(font)

    -- Optional: center text around the position
    local width = font:getWidth(self.string)
    local height = font:getHeight()
    if self.centered then
        x = x - width / 2
        y = y - height / 2
    end

    love.graphics.print(self.string, x, y)
end

return Text