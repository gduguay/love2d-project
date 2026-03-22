-- Player domain object: handles input interpretation and produces Actions.
-- This is the Domain layer — it decides WHAT to do; the ECS decides HOW.
--
-- The Player owns a pure StateMachine that emits signals (enter/exit/phase).
-- The Player drains those signals and translates them into game actions.
-- The FSM never touches the world — Player is the sole bridge.
local Object = require("modules.object")
local Actions = require("game.domain.actions")
local StateMachine = require("game.domain.statemachine")
local playerStates = require("game.domain.states.player_states")

local Player = Object:new()

function Player:__init__(entity_id)
    self:__checkNotNil(entity_id, "entity_id")
    self.entity_id = entity_id

    -- Create the FSM with player state definitions
    self.fsm = StateMachine:new(playerStates())

    -- View model: exposes domain-relevant state for HUD/UI rendering.
    -- Synced from ECS each frame so the rendering layer never reads components directly.
    self.view = {
        hp = 0,
        maxHp = 0,
        facing = "down",
        state = "idle",
        phase = nil,
    }
end

--- Tick the FSM timers, then drain and handle all emitted signals.
-- Called each frame BEFORE handleInput.
function Player:updateFSM(dt, world)
    self.fsm:update(dt)
    self:_drainSignals(world)
end

-- Called each frame by the scene. Reads input, pushes actions onto the world.
function Player:handleInput(world)
    local dx, dy = 0, 0

    if love.keyboard.isDown("up", "w") then dy = dy - 1 end
    if love.keyboard.isDown("down", "s") then dy = dy + 1 end
    if love.keyboard.isDown("left", "a") then dx = dx - 1 end
    if love.keyboard.isDown("right", "d") then dx = dx + 1 end

    -- Normalize diagonal movement
    if dx ~= 0 and dy ~= 0 then
        local len = math.sqrt(dx * dx + dy * dy)
        dx = dx / len
        dy = dy / len
    end

    if dx ~= 0 or dy ~= 0 then
        -- Request walk state — FSM decides if we're allowed to move
        if self.fsm:request("walk") or self.fsm:getState() == "walk" then
            world:pushAction(Actions.Move(self.entity_id, dx, dy))
        end
        self:_drainSignals(world)
    else
        -- No input — request idle if we're currently walking
        if self.fsm:getState() == "walk" then
            self.fsm:request("idle")
            self:_drainSignals(world)
        end
    end
end

-- Called when attack key is pressed (event-driven, not polled)
function Player:handleAttackPressed(world)
    self.fsm:request("attack")
    self:_drainSignals(world)
end

-- Called when dash key is pressed (event-driven, not polled)
function Player:handleDashPressed(world)
    self.fsm:request("dash")
    self:_drainSignals(world)
end

-- Sync the view model from ECS state. Called each frame after world:update().
function Player:syncView(world)
    local entity = world:getEntityById(self.entity_id)
    if not entity then return end

    if entity.Health then
        self.view.hp = entity.Health.current
        self.view.maxHp = entity.Health.max
    end
    if entity.Facing then
        self.view.facing = entity.Facing.direction
    end

    -- Read state from FSM (authoritative source), not ECS
    self.view.state = self.fsm:getState()
    self.view.phase = self.fsm:getPhase()
end

---------------------------------------------------------------------------
-- Signal handling: translate pure FSM signals into game actions.
-- This is the ONLY place that bridges FSM → world.
---------------------------------------------------------------------------

--- Drain all pending FSM signals and push corresponding actions.
function Player:_drainSignals(world)
    local signals = self.fsm:drain()
    for _, signal in ipairs(signals) do
        print("Player:_drainSignals", signal.type, signal.state, signal.phase)
        self:_handleSignal(signal, world)
    end
end

--- Handle a single FSM signal by pushing the appropriate actions.
function Player:_handleSignal(signal, world)
    if signal.type == "enter" then
        self:_onEnter(signal, world)
    elseif signal.type == "phase" then
        self:_onPhase(signal, world)
    -- "exit" signals don't need action for now
    end
end

function Player:_onEnter(signal, world)
    -- Sync EntityState component to match FSM state
    world:pushAction(Actions.SetEntityState(self.entity_id, signal.state, signal.phase))

    if signal.state == "idle" then
        world:pushAction(Actions.Stop(self.entity_id))

    elseif signal.state == "attack" then
        world:pushAction(Actions.Stop(self.entity_id))

    elseif signal.state == "dash" then
        -- Dash: move quickly forward 1.5 tiles (48px) over 0.10s → 480 px/s
        local entity = world:getEntityById(self.entity_id)
        if entity and entity.Facing then
            world:pushAction(Actions.Dash(self.entity_id, entity.Facing.direction, 480, 0.10))
        end
    end
end

function Player:_onPhase(signal, world)
    -- Sync EntityState component to match FSM phase
    world:pushAction(Actions.SetEntityState(self.entity_id, signal.state, signal.phase))

    if signal.state == "attack" and signal.phase == "active" then
        -- Spawn the sword hitbox at the start of the active phase
        local entity = world:getEntityById(self.entity_id)
        if entity and entity.Facing then
            world:pushAction(Actions.SwordAttack(self.entity_id, entity.Facing.direction, 0.15))
        end
    elseif signal.state == "dash" and signal.phase == "recovery" then
        world:pushAction(Actions.Stop(self.entity_id))
    end
end

return Player
