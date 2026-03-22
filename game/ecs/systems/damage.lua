-- DamageSystem: listens for sword hits and applies damage.
-- Destroys entities whose health reaches zero.
local Object = require("modules.object")
local Events = require("game.events")

local DamageSystem = Object:new()

function DamageSystem:__init__()
    self.pendingDestroy = {}
end

function DamageSystem:init(world)
    world:on(Events.SWORD_HIT, function(swordEntity, targetEntity)
        if not targetEntity.Health then return end

        print("DamageSystem: applying damage to entity", targetEntity.uid)

        targetEntity.Health.current = targetEntity.Health.current - 1
        world:emit(Events.ENTITY_DAMAGED, targetEntity, 1)

        if targetEntity.Health.current <= 0 then
            world:emit(Events.ENTITY_DIED, targetEntity)
            table.insert(self.pendingDestroy, targetEntity)
        end
    end)
end

function DamageSystem:update(world, dt)
    -- Destroy dead entities (deferred to avoid mid-iteration issues)
    for _, entity in ipairs(self.pendingDestroy) do
        world:destroy(entity)
    end
    self.pendingDestroy = {}
end

return DamageSystem
