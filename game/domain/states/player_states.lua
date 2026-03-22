-- Player state definitions for the domain-layer FSM.
-- Pure data — no callbacks, no game imports. The StateMachine drives timing and
-- emits signals. The Player domain object drains those signals and decides what
-- actions to push.

local function playerStates()
    return {
        states = {

            idle = {
                cancellable_by = { "walk", "attack", "hurt" },
            },

            walk = {
                cancellable_by = { "idle", "walk", "attack", "hurt" },
            },

            attack = {
                phases = {
                    { name = "startup",  duration = 0.05, cancellable_by = {} },
                    { name = "active",   duration = 0.15, cancellable_by = {} },
                    { name = "recovery", duration = 0.10, cancellable_by = { "walk", "attack", "idle" } },
                },
                onComplete = "idle",
            },

            -- Future states: hurt, dash, etc.
        },

        initial = "idle",
    }
end

return playerStates
