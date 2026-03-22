-- BumpSystem: top-down AABB collision using bump.lua.
-- Handles position integration for all collider entities (no separate MovementSystem needed).
-- Emits "event:collision" for each collision detected.
local Object = require("modules.object")
local bump = require("modules.bump")
local Events = require("game.events")

local BumpSystem = Object:new()

function BumpSystem:__init__()
    self.bumpWorld = nil
end

function BumpSystem:init(world)
    self.bumpWorld = bump.newWorld(32) -- cell size matches tile size

    world:on(Events.ENTITY_SPAWNED, function(entity)
        self:addEntity(entity)
    end)

    world:on(Events.ENTITY_DESTROYED, function(entity)
        self:removeEntity(entity)
    end)
end

function BumpSystem:addEntity(entity)
    if entity.Collider and entity.Position then
        local p = entity.Position
        local c = entity.Collider
        -- Convert center-based position to top-left for bump
        local x = p.cx - c.w / 2
        local y = p.cy - c.h / 2
        self.bumpWorld:add(entity, x, y, c.w, c.h)
    end
end

function BumpSystem:removeEntity(entity)
    if self.bumpWorld:hasItem(entity) then
        self.bumpWorld:remove(entity)
    end
end

function BumpSystem:update(world, dt)
    local monsterFilter = function(_, other)
        if other.Wall then return "bounce" end
        if other.SwordHitbox then return "cross" end
        return nil
    end

    local defaultFilter = function(item, other)
        -- Sword hitboxes cross through everything
        if item.SwordHitbox then return "cross" end
        -- Solid entities slide against other solids/walls
        if item.Solid and (other.Solid or other.Wall) then return "slide" end
        -- Everything else crosses
        return "cross"
    end

    -- Move all entities with Collider + Position + Velocity
    world:with({"Collider", "Position", "Velocity"}, function(entity)
        local p = entity.Position
        local v = entity.Velocity
        local c = entity.Collider

        -- Compute goal position (center-based)
        local goalCx = p.cx + v.x * dt
        local goalCy = p.cy + v.y * dt

        -- Convert to top-left for bump
        local goalX = goalCx - c.w / 2
        local goalY = goalCy - c.h / 2

        if not self.bumpWorld:hasItem(entity) then return end

        local filter = entity.Monster and monsterFilter or defaultFilter

        local actualX, actualY, cols, len = self.bumpWorld:move(entity, goalX, goalY, filter)

        -- Update center-based position from bump result
        p.cx = actualX + c.w / 2
        p.cy = actualY + c.h / 2

        -- Reflect velocity for bounce collisions
        for i = 1, len do
            local col = cols[i]
            if col.type == "bounce" and v then
                if col.normal.x ~= 0 then v.x = -v.x end
                if col.normal.y ~= 0 then v.y = -v.y end
            end
            world:emit(Events.COLLISION, entity, col.other, col)
        end
    end)

    -- Sync position for entities that may have been moved externally (e.g., teleport)
    world:with({"Collider", "Position"}, function(entity)
        if not entity.Velocity and self.bumpWorld:hasItem(entity) then
            local p = entity.Position
            local c = entity.Collider
            self.bumpWorld:update(entity, p.cx - c.w / 2, p.cy - c.h / 2)
        end
    end)
end

return BumpSystem
