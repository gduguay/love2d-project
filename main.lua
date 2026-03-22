-- main.lua: entry point for the LÖVE2D Zelda clone.
-- Sets up canvas scaling and the scene manager.

local SceneManager = require("game.scenemanager")
local RoomScene = require("scenes.room")

local sceneManager
local baseWidth, baseHeight
local gameCanvas

function love.load()
    -- Pixel-art scaling
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Base resolution: 320×200 at 2× scale
    baseWidth, baseHeight = 320, 200
    love.window.setMode(baseWidth * 2, baseHeight * 2)
    love.window.setTitle("Zelda Clone")

    gameCanvas = love.graphics.newCanvas(baseWidth, baseHeight)

    -- Scene management
    sceneManager = SceneManager:new()
    sceneManager:register("room", RoomScene:new())
    sceneManager:switch("room")
end

local accumulator = 0
local timestep = 1/60

function love.update(dt)
    accumulator = accumulator + dt
    while accumulator >= timestep do
        sceneManager:update(timestep)
        accumulator = accumulator - timestep
    end
end

function love.draw()
    -- Render to base-resolution canvas
    love.graphics.setCanvas(gameCanvas)
    love.graphics.clear(0, 0, 0, 1)
    sceneManager:draw()
    love.graphics.setCanvas()

    -- Scale canvas to window
    love.graphics.setColor(1, 1, 1, 1)
    local scaleX = love.graphics.getWidth() / baseWidth
    local scaleY = love.graphics.getHeight() / baseHeight
    love.graphics.draw(gameCanvas, 0, 0, 0, scaleX, scaleY)
end

-- Forward input events to the scene manager
function love.keypressed(key)
    sceneManager:handleEvent("keypressed", key)
end

function love.keyreleased(key)
    sceneManager:handleEvent("keyreleased", key)
end

function love.mousepressed(x, y, button)
    sceneManager:handleEvent("mousepressed", x, y, button)
end

function love.mousereleased(x, y, button)
    sceneManager:handleEvent("mousereleased", x, y, button)
end

function love.mousemoved(x, y, dx, dy)
    sceneManager:handleEvent("mousemoved", x, y, dx, dy)
end