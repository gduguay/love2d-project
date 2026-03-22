-- AnimationSystem: drives sprite animation based on entity state.
-- Determines the animation name from Facing + movement + attacking state,
-- advances frame timers, and updates the Drawable's current quad.
local Object = require("modules.object")

local AnimationSystem = Object:new()

function AnimationSystem:update(world, dt)
    world:with({"AnimationState", "Drawable"}, function(entity)
        local anim = entity.AnimationState
        local animations = anim.animations

        -- Determine which animation to play
        local animName = self:resolveAnimationName(entity)

        -- If animation changed, reset timer and frame
        if animName ~= anim.current then
            anim.current = animName
            anim.timer = 0
            anim.frame = 1
        end

        local sequence = animations[anim.current]
        if not sequence then return end

        -- Advance timer
        anim.timer = anim.timer + dt
        local frameDuration = sequence.duration / #sequence.frames
        if frameDuration > 0 and anim.timer >= frameDuration then
            anim.timer = anim.timer - frameDuration
            anim.frame = anim.frame + 1
            if anim.frame > #sequence.frames then
                if sequence.loop ~= false then
                    anim.frame = 1
                else
                    anim.frame = #sequence.frames
                end
            end
        end

        -- Update drawable frame
        local frameIndex = sequence.frames[anim.frame]
        if frameIndex and entity.Drawable.setFrame then
            entity.Drawable:setFrame(frameIndex)
        end
    end)
end

function AnimationSystem:resolveAnimationName(entity)
    local facing = entity.Facing and entity.Facing.direction or "down"

    -- Prefer EntityState (domain FSM) when available
    if entity.EntityState then
        return entity.EntityState.state .. "_" .. facing
    end

    -- Fallback: infer from Attacking/Velocity (for entities without FSM, e.g. simple NPCs)
    local v = entity.Velocity

    -- Attacking overrides movement animation
    if entity.Attacking and entity.Attacking.active then
        return "attack_" .. facing
    end

    -- Moving vs idle
    if v and (v.x ~= 0 or v.y ~= 0) then
        return "walk_" .. facing
    end

    return "idle_" .. facing
end

return AnimationSystem
