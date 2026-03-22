-- WallHuggerAI domain object: AI-controlled entity that produces Actions.
-- Walks forward and turns on wall collision (wall-following patrol).
-- Like Player, it never mutates ECS components directly — only pushes Actions.
local Object = require("modules.object")
local Actions = require("game.domain.actions")
local Events = require("game.events")

local TURN_RIGHT = { up = "right", right = "down", down = "left", left = "up" }
local TURN_LEFT  = { up = "left",  left = "down",  down = "right", right = "up" }

local WallHuggerAI = Object:new()

--- Create a wall-following AI.
-- @param entity_id      number  The ECS entity uid
-- @param config         table   { direction = string, turnDir = "right"|"left" }
function WallHuggerAI:__init__(entity_id, config)
    self:__checkNotNil(entity_id, "entity_id")
    config = config or {}

    self.entity_id = entity_id
    self.direction = config.direction or "right"
    self.turnMap = (config.turnDir == "left") and TURN_LEFT or TURN_RIGHT
end

--- Subscribe to collision events. Called once after world is ready.
function WallHuggerAI:init(world)
    world:on(Events.COLLISION, function(entity, other, col)
        if entity.uid == self.entity_id and other.Wall then
            self.direction = self.turnMap[self.direction]
        end
    end)
end

--- Called each frame. Pushes a Move action in the current direction.
function WallHuggerAI:update(dt, world)
    local entity = world:getEntityById(self.entity_id)
    if not entity then return end

    local dx, dy = 0, 0
    if self.direction == "up" then       dy = -1
    elseif self.direction == "down" then  dy = 1
    elseif self.direction == "left" then  dx = -1
    elseif self.direction == "right" then dx = 1
    end

    world:pushAction(Actions.Move(self.entity_id, dx, dy))
end

return WallHuggerAI
