-- SwordSystem: manages sword hitbox lifecycle.
-- Counts down TTL and destroys expired sword entities.
-- Listens for collisions involving sword hitboxes and emits "event:sword_hit".
local Object = require("modules.object")
local Events = require("game.events")

local SwordSystem = Object:new()

function SwordSystem:__init__()
    self.pendingDestroy = {}
end

function SwordSystem:init(world)
    -- Listen for collisions involving sword hitboxes
    world:on(Events.COLLISION, function(entity, other, col)
        -- Sword hit something that has Health
        if entity.SwordHitbox and other.Health then
            world:emit(Events.SWORD_HIT, entity, other)
        elseif other.SwordHitbox and entity.Health then
            world:emit(Events.SWORD_HIT, other, entity)
        end
    end)
end

function SwordSystem:update(world, dt)
    -- Destroy pending from last frame (safe, avoids mid-iteration removal)
    for _, entity in ipairs(self.pendingDestroy) do
        world:destroy(entity)
    end
    self.pendingDestroy = {}

    -- Update attacking state on entities
    world:with({"Attacking"}, function(entity)
        local atk = entity.Attacking
        if atk.active then
            atk.timer = atk.timer - dt
            if atk.timer <= 0 then
                atk.active = false
                atk.timer = 0
            end
        end
    end)

    -- Count down sword hitbox TTL
    world:with({"SwordHitbox"}, function(entity)
        entity.SwordHitbox.ttl = entity.SwordHitbox.ttl - dt
        if entity.SwordHitbox.ttl <= 0 then
            table.insert(self.pendingDestroy, entity)
        end
    end)
end

return SwordSystem
