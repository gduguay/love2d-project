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

function Actions.Attack(entity_id, direction)
    return {
        type = "attack",
        entity_id = entity_id,
        direction = direction,
    }
end

return Actions
