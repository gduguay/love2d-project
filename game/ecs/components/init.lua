-- Component factory functions.
-- Components are plain data tables attached as keys on entities.
-- These factories ensure consistent structure.

local Components = {}

function Components.Position(cx, cy)
    return { cx = cx, cy = cy }
end

function Components.Velocity(x, y)
    return { x = x or 0, y = y or 0 }
end

function Components.Facing(direction)
    return { direction = direction or "down" }
end

function Components.Collider(w, h, collisionType)
    return { w = w, h = h, collisionType = collisionType or "slide" }
end

function Components.MovementSpeed(speed)
    return speed
end

function Components.Health(current, max)
    return { current = current, max = max or current }
end

function Components.Attacking(duration)
    return { active = false, timer = 0, duration = duration or 0.2 }
end

function Components.AnimationState(animations, defaultAnim)
    return {
        animations = animations,   -- table of named animation sequences
        current = defaultAnim or "idle_down",
        timer = 0,
        frame = 1,
    }
end

function Components.ZOrder(z)
    return z or 0
end

function Components.SwordHitbox(owner_id, ttl)
    return { owner = owner_id, ttl = ttl or 0.15 }
end

function Components.EntityState(state, phase)
    return { state = state or "idle", phase = phase }
end

-- Tag components (just return true)
function Components.Solid()       return true end
function Components.PlayerControlled() return true end
function Components.Wall()        return true end
function Components.Monster()     return true end

return Components
