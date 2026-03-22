-- ActionSystem: consumes the action queue and translates intent into ECS component mutations.
-- This is the bridge: Domain pushes Actions → ActionSystem applies them to entities.
local Object = require("modules.object")

local ActionSystem = Object:new()

function ActionSystem:init(world)
    self.world = world
end

function ActionSystem:update(world, dt)
    local actions = world:consumeActions()

    for _, action in ipairs(actions) do
        local entity = world:getEntityById(action.entity_id)
        if entity then
            if action.type == "move" then
                self:handleMove(world, entity, action)
            elseif action.type == "stop" then
                self:handleStop(world, entity, action)
            elseif action.type == "attack" then
                self:handleAttack(world, entity, action)
            end
        end
    end
end

function ActionSystem:handleMove(world, entity, action)
    if entity.Velocity and entity.MovementSpeed then
        local speed = entity.MovementSpeed
        entity.Velocity.x = action.dx * speed
        entity.Velocity.y = action.dy * speed
    end
    if entity.Facing then
        -- Update facing based on dominant axis
        if action.dy < 0 then
            entity.Facing.direction = "up"
        elseif action.dy > 0 then
            entity.Facing.direction = "down"
        elseif action.dx < 0 then
            entity.Facing.direction = "left"
        elseif action.dx > 0 then
            entity.Facing.direction = "right"
        end
    end
end

function ActionSystem:handleStop(world, entity, action)
    if entity.Velocity then
        entity.Velocity.x = 0
        entity.Velocity.y = 0
    end
end

function ActionSystem:handleAttack(world, entity, action)
    if not entity.Attacking then return end
    if entity.Attacking.active then return end -- already attacking

    entity.Attacking.active = true
    entity.Attacking.timer = entity.Attacking.duration

    -- Spawn sword hitbox entity in front of the player
    local dir = action.direction
    local pos = entity.Position
    if not pos then return end

    local sw, sh = 20, 20  -- sword hitbox size
    local ox, oy = 0, 0
    if dir == "up" then
        ox, oy = 0, -28
    elseif dir == "down" then
        ox, oy = 0, 28
    elseif dir == "left" then
        ox, oy = -28, 0
    elseif dir == "right" then
        ox, oy = 28, 0
    end

    -- Create the sword hitbox entity
    world:spawn({
        Position = { cx = pos.cx + ox, cy = pos.cy + oy },
        Collider = { w = sw, h = sh, collisionType = "cross" },
        SwordHitbox = { owner = entity.uid, ttl = entity.Attacking.duration },
        Drawable = {
            drawAt = function(_, x, y)
                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.rectangle("fill", x - sw/2, y - sh/2, sw, sh)
                love.graphics.setColor(1, 1, 1, 1)
            end
        },
        ZOrder = 10,
    })
end

return ActionSystem
