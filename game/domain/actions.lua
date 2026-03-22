-- Action definitions: the bridge between Domain and ECS.
-- Actions represent intent. The Domain produces them; the ActionSystem consumes them.

local Actions = {}

function Actions.Move(entity_id, dx, dy)
    return {
        type = "move",
        entity_id = entity_id,
        dx = dx,
        dy = dy,
    }
end

function Actions.Stop(entity_id)
    return {
        type = "stop",
        entity_id = entity_id,
    }
end

function Actions.SwordAttack(entity_id, direction, ttl)
    return {
        type = "sword_attack",
        entity_id = entity_id,
        direction = direction,
        ttl = ttl,
    }
end

function Actions.Dash(entity_id, direction, speed, duration)
    return {
        type = "dash",
        entity_id = entity_id,
        direction = direction,
        speed = speed,
        duration = duration,
    }
end

function Actions.SetEntityState(entity_id, state, phase)
    return {
        type = "set_entity_state",
        entity_id = entity_id,
        state = state,
        phase = phase,  -- nil for phaseless states
    }
end

return Actions
