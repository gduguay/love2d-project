-- TimerSystem: drives the Timers component on entities.
-- Iterates all entities with a Timers component and calls update(dt).
local Object = require("modules.object")

local TimerSystem = Object:new()

function TimerSystem:update(world, dt)
    world:with({"Timers"}, function(entity)
        local timers = entity.Timers
        -- Update each named timer; collect finished ones
        local finished = {}
        for name, timer in pairs(timers.timers) do
            local done = timer:update(dt)
            if done then
                table.insert(finished, name)
            end
        end
        -- Clean up finished (non-looping) timers
        for _, name in ipairs(finished) do
            timers.timers[name] = nil
        end
    end)
end

return TimerSystem
