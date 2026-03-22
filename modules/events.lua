local Object = require('modules.object')

local EventBus = Object:new()

function EventBus:__init__()
    self.listeners = {}
end

function EventBus:subscribe(event, listener)
    if not self.listeners[event] then
        self.listeners[event] = {}
    end

    table.insert(self.listeners[event], listener)

    return function()
        self:unsubscribe(event, listener)
    end
end

function EventBus:unsubscribe(event, listener)
    if not self.listeners[event] then
        return
    end

    for i, registeredListener in ipairs(self.listeners[event]) do
        if registeredListener == listener then
            table.remove(self.listeners[event], i)
            return
        end
    end
end

function EventBus:emit(event, ...)
    if not self.listeners[event] then
        return
    end

    for _, listener in ipairs(self.listeners[event]) do
        listener(...)
    end
end

return EventBus
