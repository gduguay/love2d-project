-- StateMachine: a pure flat FSM with phase-based cancellation.
-- The FSM knows nothing about the game domain — no world, no actions, no callbacks.
-- It manages states, phases, timers, and transition rules. It emits signals that the
-- owner (e.g. Player) drains and translates into game actions.
--
-- States can be:
--   Phaseless: { cancellable_by = {...} }
--   Phased:    { phases = { {name, duration, cancellable_by}, ... }, onComplete = "state" }
--
-- Signals emitted:
--   { type = "exit",  state = "old_state" }
--   { type = "enter", state = "new_state", phase = "first_phase" or nil }
--   { type = "phase", state = "current_state", phase = "new_phase" }
--
-- Usage:
--   local fsm = StateMachine:new({ states = {...}, initial = "idle" })
--   fsm:request("walk")           -- request a transition
--   fsm:update(dt)                -- advance timers
--   local signals = fsm:drain()   -- get and clear accumulated signals

local Object = require("modules.object")

local StateMachine = Object:new()

function StateMachine:__init__(config)
    self:__checkNotNil(config, "config")
    self:__checkNotNil(config.states, "config.states")
    self:__checkNotNil(config.initial, "config.initial")

    self.states = config.states
    self.current = config.initial
    self.phaseIndex = nil   -- nil for phaseless states, 1-based index for phased
    self.phaseTimer = 0
    self.signals = {}       -- accumulated transition signals

    -- Enter the initial state
    local state = self.states[self.current]
    if state and state.phases then
        self.phaseIndex = 1
        self.phaseTimer = 0
        self:_emit("enter", self.current, state.phases[1].name)
    else
        self:_emit("enter", self.current, nil)
    end
end

--- Returns the current state name.
function StateMachine:getState()
    return self.current
end

--- Returns the current phase name, or nil for phaseless states.
function StateMachine:getPhase()
    local state = self.states[self.current]
    if state and state.phases and self.phaseIndex then
        local phase = state.phases[self.phaseIndex]
        return phase and phase.name or nil
    end
    return nil
end

--- Returns true if the FSM is currently in a phased state.
function StateMachine:isPhased()
    local state = self.states[self.current]
    return state and state.phases ~= nil
end

--- Drain and return all accumulated signals, clearing the internal buffer.
function StateMachine:drain()
    local out = self.signals
    self.signals = {}
    return out
end

--- Get the cancellable_by list for the current state/phase.
function StateMachine:getCancellableBy()
    local state = self.states[self.current]
    if not state then return {} end

    if state.phases and self.phaseIndex then
        local phase = state.phases[self.phaseIndex]
        return phase and phase.cancellable_by or {}
    end

    return state.cancellable_by or {}
end

--- Check if the current state/phase can be cancelled by the given target state.
function StateMachine:canTransitionTo(targetState)
    if targetState == self.current and not self:isPhased() then
        return false  -- already in this phaseless state
    end
    local cancellable_by = self:getCancellableBy()
    for _, allowed in ipairs(cancellable_by) do
        if allowed == targetState then
            return true
        end
    end
    return false
end

--- Request a transition to targetState. Returns true if the transition was accepted.
function StateMachine:request(targetState)
    if not self.states[targetState] then
        return false  -- unknown state
    end

    if not self:canTransitionTo(targetState) then
        return false
    end

    self:_transition(targetState)
    return true
end

--- Advance timers for phased states. Call each frame.
function StateMachine:update(dt)
    local state = self.states[self.current]
    if not state or not state.phases or not self.phaseIndex then
        return  -- phaseless states don't tick
    end

    local phase = state.phases[self.phaseIndex]
    if not phase then return end

    self.phaseTimer = self.phaseTimer + dt

    if self.phaseTimer >= phase.duration then
        -- Phase complete — advance to next phase or auto-complete
        local nextPhaseIndex = self.phaseIndex + 1
        if nextPhaseIndex <= #state.phases then
            -- Move to next phase within the same state
            self.phaseIndex = nextPhaseIndex
            self.phaseTimer = self.phaseTimer - phase.duration
            local nextPhase = state.phases[nextPhaseIndex]
            self:_emit("phase", self.current, nextPhase.name)
        else
            -- All phases exhausted — auto-transition to onComplete state
            local completeTo = state.onComplete or "idle"
            self:_transition(completeTo)
        end
    end
end

--- Internal: record a signal.
function StateMachine:_emit(signalType, stateName, phaseName)
    table.insert(self.signals, {
        type = signalType,
        state = stateName,
        phase = phaseName,
    })
end

--- Internal: perform the actual state transition.
function StateMachine:_transition(targetState)
    local newState = self.states[targetState]

    -- Exit old state
    self:_emit("exit", self.current, self:getPhase())

    -- Update current state
    self.current = targetState

    -- Set up phase tracking
    if newState.phases then
        self.phaseIndex = 1
        self.phaseTimer = 0
        self:_emit("enter", targetState, newState.phases[1].name)
    else
        self.phaseIndex = nil
        self.phaseTimer = 0
        self:_emit("enter", targetState, nil)
    end
end

return StateMachine