local Object = require("modules.object")

local Blink = Object:new()

function Blink:__init__(params)
    self.drawable = params.drawable or nil
    self.speed = params.speed or 1
end

function Blink:drawAt(x, y)
    local time = love.timer.getTime()
    if math.floor(time * self.speed) % 2 == 0 then
        self.drawable:drawAt(x, y)
    end
end

return Blink