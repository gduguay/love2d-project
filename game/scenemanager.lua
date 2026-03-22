local Object = require("modules.object")
local SceneManager = Object:new()

function SceneManager:__init__()
    self.scenes = {}    -- named scenes: { ["title"] = Scene, ... }
    self.stack = {}     -- scene stack (top = current)
end

-- Register a named scene
function SceneManager:register(name, scene)
    scene.name = name
    scene.manager = self
    self.scenes[name] = scene
end

-- Push a scene onto the stack
-- Can pass either a scene object or a registered name
function SceneManager:push(sceneOrName)
    local scene = sceneOrName
    if type(sceneOrName) == "string" then
        scene = self.scenes[sceneOrName]
        if not scene then
            error("No scene registered with name: " .. sceneOrName)
        end
    elseif type(sceneOrName) ~= "table" then
        error("Invalid scene object passed to SceneManager:push")
    else
        scene.name = scene.name or ("anonymous" + tostring(math.random(1000, 9999)))
    end

    -- Optional: pause current top
    local top = self.stack[#self.stack]
    if top and top.onPause then top:onPause() end

    table.insert(self.stack, scene)
    if scene.onEnter then scene:onEnter() end
end

-- Pop the top scene
function SceneManager:pop(skipresume)
    local top = table.remove(self.stack)
    if not top then return end
    if top.onExit then top:onExit() end

    -- Resume underlying scene if it exists
    local newTop = self.stack[#self.stack]
    if newTop and not skipresume and newTop.onResume then newTop:onResume() end
end

-- Replace entire stack with a scene
function SceneManager:switch(sceneOrName)
    -- Exit all current scenes
    while #self.stack > 0 do self:pop(true) end
    self:push(sceneOrName)
end

-- Get the current scene (top of stack)
function SceneManager:current()
    return self.stack[#self.stack]
end

-- Forward update to top scene
function SceneManager:update(dt)
    local top = self:current()
    if top then top:update(dt) end
end

-- Forward draw to all scenes (stack order)
-- Optional: draw underlying scenes for overlay effects
function SceneManager:draw()
    for _, scene in ipairs(self.stack) do
        scene:draw()
    end
end

function SceneManager:handleEvent(event, ...)
    local top = self:current()
    if top then
        top:handleEvent(event, ...)
    end
end


return SceneManager