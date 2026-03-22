local Object = require("modules.object")

local WorldScene = Object:new()

function WorldScene:update(dt)
    if self.world then
        self.world:update(dt)
    end
end

function WorldScene:draw()
    if self.world then
        self.world:draw()
    end
end

function WorldScene:handleEvent(event, ...)
    if self.world then
        self.world:emit("love:" .. event, ...)
    end
end


return WorldScene