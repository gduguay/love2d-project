-- RenderSystem: draws all entities with Drawable + Position.
-- Sorts by ZOrder (ascending), then by Position.cy (depth sorting).
local Object = require("modules.object")

local RenderSystem = Object:new()

function RenderSystem:draw(world)
    -- Collect drawable entities
    local drawList = {}
    world:with({"Drawable", "Position"}, function(entity)
        table.insert(drawList, entity)
    end)

    -- Sort: by ZOrder first, then by cy for depth
    table.sort(drawList, function(a, b)
        local za = a.ZOrder or 0
        local zb = b.ZOrder or 0
        if za ~= zb then return za < zb end
        return a.Position.cy < b.Position.cy
    end)

    -- Draw each entity
    love.graphics.setColor(1, 1, 1, 1)
    for _, entity in ipairs(drawList) do
        entity.Drawable:drawAt(entity.Position.cx, entity.Position.cy)
    end
end

return RenderSystem
