-- RoamerAI domain object: AI-controlled entity that wanders randomly.
-- Every `interval` seconds, picks a random cardinal direction and walks
-- one tile, then idles until the next move. Slides against walls via BumpSystem.
-- Like Player, it never mutates ECS components directly — only pushes Actions.
local Object = require("modules.object")
local Actions = require("game.domain.actions")

local DIRECTIONS = { "up", "down", "left", "right" }
local DIR_VEC = {
    up    = { dx = 0, dy = -1 },
    down  = { dx = 0, dy =  1 },
    left  = { dx = -1, dy = 0 },
    right = { dx =  1, dy = 0 },
}

local RoamerAI = Object:new()

--- Create a roaming AI.
-- @param entity_id  number  The ECS entity uid
-- @param config     table   { interval = seconds between moves, moveTime = seconds per move }
function RoamerAI:__init__(entity_id, config)
    self:__checkNotNil(entity_id, "entity_id")
    config = config or {}

    self.entity_id = entity_id
    self.interval = config.interval or 3.0    -- seconds between moves
    self.moveTime = config.moveTime or 0.5    -- how long each move lasts
    self.timer = math.random() * self.interval -- stagger initial timing
    self.moveTimer = 0
    self.moving = false
end

--- Called each frame. Manages idle/move timer and pushes actions.
function RoamerAI:update(dt, world)
    local entity = world:getEntityById(self.entity_id)
    if not entity then return end

    if self.moving then
        self.moveTimer = self.moveTimer - dt
        if self.moveTimer <= 0 then
            -- Done moving — stop and start idle timer
            self.moving = false
            self.timer = self.interval
            world:pushAction(Actions.Stop(self.entity_id))
        else
            -- Keep moving in current direction
            local v = DIR_VEC[self.direction]
            world:pushAction(Actions.Move(self.entity_id, v.dx, v.dy))
        end
    else
        self.timer = self.timer - dt
        if self.timer <= 0 then
            -- Pick a random direction and start moving
            self.direction = DIRECTIONS[math.random(#DIRECTIONS)]
            self.moving = true
            self.moveTimer = self.moveTime
        end
    end
end

return RoamerAI
