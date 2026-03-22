-- Event name constants for ECS → Domain communication.
-- Using a central table keeps event names consistent across the codebase.

local Events = {
    -- Entity lifecycle (emitted by World)
    ENTITY_SPAWNED   = "entity:spawned",
    ENTITY_DESTROYED = "entity:destroyed",

    -- Collision (emitted by BumpSystem)
    COLLISION        = "event:collision",

    -- Combat (emitted by SwordSystem)
    SWORD_HIT        = "event:sword_hit",

    -- Domain-level (emitted by domain handlers)
    ENTITY_DAMAGED   = "event:entity_damaged",
    ENTITY_DIED      = "event:entity_died",
}

return Events
