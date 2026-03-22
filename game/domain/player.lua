-- Player domain object: handles input interpretation and produces Actions.
-- This is the Domain layer — it decides WHAT to do; the ECS decides HOW.
local Object = require("modules.object")
local Actions = require("game.domain.actions")

local Player = Object:new()

function Player:__init__(entity_id)
    self:__checkNotNil(entity_id, "entity_id")
    self.entity_id = entity_id

    -- View model: exposes domain-relevant state for HUD/UI rendering.
    -- Synced from ECS each frame so the rendering layer never reads components directly.
    self.view = {
        hp = 0,
        maxHp = 0,
        facing = "down",
        attacking = false,
    }
end

-- Called each frame by the scene. Reads input, pushes actions onto the world.
function Player:handleInput(world)
    local dx, dy = 0, 0

    if love.keyboard.isDown("up", "w") then dy = dy - 1 end
    if love.keyboard.isDown("down", "s") then dy = dy + 1 end
    if love.keyboard.isDown("left", "a") then dx = dx - 1 end
    if love.keyboard.isDown("right", "d") then dx = dx + 1 end

    -- Normalize diagonal movement
    if dx ~= 0 and dy ~= 0 then
        local len = math.sqrt(dx * dx + dy * dy)
        dx = dx / len
        dy = dy / len
    end

    if dx ~= 0 or dy ~= 0 then
        world:pushAction(Actions.Move(self.entity_id, dx, dy))
    else
        world:pushAction(Actions.Stop(self.entity_id))
    end
end

-- Called when attack key is pressed (event-driven, not polled)
function Player:handleAttackPressed(world)
    local dir = self.view.facing
    if not self.view.attacking then
        world:pushAction(Actions.Attack(self.entity_id, dir))
    end
end

-- Sync the view model from ECS state. Called each frame after world:update().
function Player:syncView(world)
    local entity = world:getEntityById(self.entity_id)
    if not entity then return end

    if entity.Health then
        self.view.hp = entity.Health.current
        self.view.maxHp = entity.Health.max
    end
    if entity.Facing then
        self.view.facing = entity.Facing.direction
    end
    if entity.Attacking then
        self.view.attacking = entity.Attacking.active
    end
end

return Player
