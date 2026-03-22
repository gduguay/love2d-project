local Object = require('modules.object')

local Timers = Object:new()
local Timer = Object:new()

function Timer:__init__(props)
    self.duration = props.duration
    self.onBegin = props.onBegin
    self.onEnd = props.onEnd
    self.onCancel = props.onCancel
    self.tween = props.tween
    self.running = false
    self.paused = false
    self.loop = props.loop
    self.time = 0
end

function Timer:update(dt)

    if self.paused then
        return false
    end

    if self.running then
        self.time = self.time + dt
        if self.time >= self.duration then
            self.running = false
            if self.onEnd then
                self.onEnd()
            end
            if self.loop then
                self.time = 0
                self.running = false
                return false
            else
                return true
            end
        else
            if self.tween then
                self.tween(self.time / self.duration)
            end
            return false
        end
    else
        if self.onBegin then
            self.onBegin()
        end
        self.running = true
        self.time = 0
        return false
    end
end

function Timers:__init__()
    self.timers = {}
end

function Timers:update(dt)
    local finished = {}
    for name, timer in pairs(self.timers) do
        local done = timer:update(dt)
        if done then
            table.insert(finished, name)
        end
    end
    for _, name in ipairs(finished) do
        self.timers[name] = nil
    end
end

function Timers:add(name, props)
    
    local timer = Timer:new(props)
    self.timers[name] = timer

    return {
        timer = timer,
        cancel = function()
            return self:cancel(name, timer)
        end,
        pause = function()
            timer.paused = true
        end,
        resume = function()
            timer.paused = false
        end
    }
end

function Timers:cancel(name, timer)

    if self.timers[name] == nil or self.timers[name] ~= timer then
        return false
    end

    if timer and timer.running then
        timer.running = false
        if timer.onCancel then
            timer.onCancel(timer.time / timer.duration)
        end
    end

    self.timers[name] = nil
    return true
end

function Timers:destroy()
    for name, timer in pairs(self.timers) do
        self:cancel(name, timer)
    end
end

return Timers