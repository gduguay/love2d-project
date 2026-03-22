# LÖVE2D Zelda Clone — Agent Instructions

## Project Overview
This is a **LÖVE2D (Love2D)** Zelda 1-style game using Lua. The architecture is a **hybrid Domain/ECS** pattern with a strict unidirectional data flow:

```
Input/AI → Domain → Actions → ECS Simulation → Events → Domain → (repeat)
```

- **Domain layer** — High-level game logic (Player, future: Monster AI, Inventory). Produces Actions.
- **Action/Command layer** — Data tables representing intent (Move, Attack, Stop). Bridge between Domain and ECS.
- **ECS (Simulation) layer** — Entities, Components, Systems. Consumes Actions, runs physics/animation, emits Events.
- **Event flow (ECS → Domain)** — ECS emits facts (collision, sword hit). Domain listens and applies game meaning.
- **Rendering** — World rendering via ECS RenderSystem. HUD rendered separately from domain data.

## Architecture Layers

### 1. Object-Oriented Base (`modules/object.lua`)
All classes inherit from `Object`:
- `Object:new(...)` — prototype-based OOP via metatables
- `__init__(...)` — override for initialization
- `__checkNotNil(value, name)` / `__checkKeys(table, keys)` — parameter validation
- `augment(methods)` — mixin-style composition (used by World)

```lua
local Object = require("modules.object")
local MyClass = Object:new()

function MyClass:__init__(name)
    self:__checkNotNil(name, "name")
    self.name = name
end

return MyClass
```

### 2. Domain Layer (`game/domain/`)
Domain objects encapsulate game logic and decision-making. They do NOT touch ECS components directly — they produce **Actions** which the ECS consumes.

**Player** (`game/domain/player.lua`):
- Holds `entity_id` (reference to ECS entity)
- `handleInput(world)` — polls keyboard, pushes `MoveAction`/`StopAction` onto the world's action queue
- `handleAttackPressed(world, entity)` — pushes `AttackAction` (event-driven, not polled)

**Pattern for new domain objects:**
```lua
local Object = require("modules.object")
local Actions = require("game.domain.actions")

local Monster = Object:new()

function Monster:__init__(entity_id)
    self.entity_id = entity_id
end

function Monster:think(world, entity)
    -- AI logic → produce actions
    world:pushAction(Actions.Move(self.entity_id, dx, dy))
end

return Monster
```

### 3. Action / Command Layer (`game/domain/actions.lua`)
Actions are plain data tables with a `type` field. Factory functions ensure consistent structure:

```lua
Actions.Move(entity_id, dx, dy)    -- intent to move (dx/dy are direction, not pixels)
Actions.Stop(entity_id)            -- intent to stop
Actions.Attack(entity_id, direction) -- intent to swing sword
```

**To add a new action**: Add a factory function to `game/domain/actions.lua` and handle it in `game/ecs/systems/action.lua`.

### 4. ECS (Simulation) Layer (`game/ecs/`)

#### World (`game/ecs/world.lua`)
Central ECS manager. Key API:

| Method | Purpose |
|---|---|
| `spawn(entity)` | Add entity, assigns `uid`, emits `entity:spawned` |
| `destroy(entity)` | Remove entity, emits `entity:destroyed` |
| `with({components}, fn)` | Iterate entities with all named components |
| `query({components})` | Return array of matching entities |
| `on(event, listener)` | Subscribe to events (returns unsubscribe fn) |
| `emit(event, ...)` | Emit event to all listeners |
| `pushAction(action)` | Enqueue an action (Domain → ECS bridge) |
| `consumeActions()` | Dequeue all actions (called by ActionSystem) |
| `getEntityById(id)` | O(1) entity lookup by uid |

#### Components (`game/ecs/components/init.lua`)
Factory functions for consistent component creation:

```lua
local C = require("game.ecs.components")

local entity = {
    Position          = C.Position(160, 100),          -- {cx, cy} center-based
    Velocity          = C.Velocity(0, 0),              -- {x, y}
    Facing            = C.Facing("down"),               -- {direction} up/down/left/right
    Collider          = C.Collider(22, 22, "slide"),    -- {w, h, collisionType}
    MovementSpeed     = C.MovementSpeed(120),           -- scalar
    Health            = C.Health(3, 3),                 -- {current, max}
    Attacking         = C.Attacking(0.2),               -- {active, timer, duration}
    AnimationState    = C.AnimationState(anims, "idle_down"),  -- {animations, current, timer, frame}
    ZOrder            = C.ZOrder(1),                    -- number (higher = drawn later)
    SwordHitbox       = C.SwordHitbox(owner_id, 0.15), -- {owner, ttl}
    Solid             = C.Solid(),                      -- tag (true)
    Wall              = C.Wall(),                       -- tag (true)
    PlayerControlled  = C.PlayerControlled(),           -- tag (true)
    Drawable          = spriteSheetInstance,             -- must implement drawAt(x, y)
}
```

**Conventions:**
- Components are **PascalCase** keys on entity tables
- Structured components are tables (`Position`, `Velocity`, `Health`, etc.)
- Tag components are booleans (`Solid`, `Wall`, `PlayerControlled`)
- Scalar components are plain numbers (`MovementSpeed`, `ZOrder`)
- `Drawable` components must implement the `drawAt(x, y)` interface
- Position is always **center-based** (`cx`, `cy`)

#### Systems (`game/ecs/systems/`)

Systems process entities each frame. They have optional `init(world)`, `update(world, dt)`, and `draw(world)` methods.

**System execution order matters!** Current order in the Room scene:

| Order | System | Role |
|---|---|---|
| 1 | **ActionSystem** | Consumes action queue → mutates components (velocity, spawns sword) |
| 2 | **SwordSystem** | Manages sword hitbox TTL, attack cooldowns, detects sword hits |
| 3 | **BumpSystem** | Moves entities via bump.lua, resolves collisions, emits `event:collision` |
| 4 | **AnimationSystem** | Resolves animation name from state, advances frames, updates Drawable |
| 5 | **TimerSystem** | Ticks `Timers` components on entities |
| 6 | **RenderSystem** | Z-sorted + depth-sorted drawing (draw phase only) |

**System details:**

- **ActionSystem** (`action.lua`) — Translates Actions into ECS mutations. `MoveAction` → sets `Velocity` + `Facing`. `AttackAction` → sets `Attacking.active`, spawns sword hitbox entity. `StopAction` → zeroes `Velocity`.
- **BumpSystem** (`bump.lua`) — Top-down AABB collision via bump.lua. No gravity. Handles position integration for all entities with `Collider` + `Velocity`. Collision filter: `Solid` entities slide against `Solid`/`Wall`; sword hitboxes cross through everything. Emits `event:collision`.
- **SwordSystem** (`sword.lua`) — Counts down `SwordHitbox.ttl`, destroys expired hitboxes. Counts down `Attacking.timer`. Listens to `event:collision` and emits `event:sword_hit` when a sword contacts a `Health` entity.
- **AnimationSystem** (`animation.lua`) — Resolves animation name from `Facing` + `Velocity` + `Attacking` state (e.g., `"walk_left"`, `"idle_down"`, `"attack_up"`). Advances frame timer. Calls `Drawable:setFrame()`.
- **TimerSystem** (`timer.lua`) — Iterates entities with `Timers` component, calls `update(dt)` on each.
- **RenderSystem** (`render.lua`) — Collects `Drawable` + `Position` entities, sorts by `ZOrder` then `Position.cy`, draws via `drawAt()`.

### 5. Events (`game/events/init.lua`)
String constants for event names:

| Event | Emitted by | Meaning |
|---|---|---|
| `entity:spawned` | World | Entity added |
| `entity:destroyed` | World | Entity removed |
| `event:collision` | BumpSystem | Two entities collided |
| `event:sword_hit` | SwordSystem | Sword contacted a Health entity |
| `event:entity_damaged` | (future) | Domain applied damage |
| `event:entity_died` | (future) | Entity health reached 0 |

LÖVE input events are forwarded as `love:keypressed`, `love:keyreleased`, etc.

### 6. Drawables (`game/drawables/`)
All drawables implement `drawAt(x, y)` (centered drawing):

- **SpriteSheet** (`spritesheet.lua`) — Quad-based sprite sheet. `setFrame(index)` / `setQuad(col, row)` to select frame.
- **Sprite** (`sprite.lua`) — Single image drawable.
- **Text** (`text.lua`) — Text with optional font and centering.
- **Blink** (`blink.lua`) — Decorator that toggles visibility.
- **Placeholder** (`placeholder.lua`) — Runtime-generated sprite sheet (4 dirs × 4 frames: idle, walk1, walk2, attack).

### 7. Scenes (`scenes/`)
Scenes are managed by `SceneManager` (`game/scenemanager.lua`) which maintains a scene **stack**:
- `register(name, scene)`, `switch(name)`, `push(name)`, `pop()`
- `update(dt)` / `handleEvent(event, ...)` → forwarded to top scene only
- `draw()` → draws all stacked scenes (for overlays)

**WorldScene** (`scenes/worldscene.lua`) — Base class that bridges a scene to an ECS `World`. Forwards `update`, `draw`, and input events (`love:keypressed`, etc.).

**RoomScene** (`scenes/room.lua`) — The active game scene. Creates the World with all systems, spawns room walls and the player entity, creates the `Player` domain object, and wires ECS events to domain handlers. Each frame: `player:handleInput(world)` → `world:update(dt)`. Draws floor, ECS entities, and HUD.

## Display Settings
- **Base resolution**: 320×200 pixels
- **Window**: 640×400 (2× scale)
- **Tile size**: 32×32
- **Room grid**: 10×6 tiles (320×192 play area + 8px HUD bar)
- **Pixel art filter**: `"nearest"` (no smoothing)
- **Fixed timestep**: 1/60s with accumulator

## File Organization
```
game/
  domain/              — Domain layer (game logic, produces Actions)
    actions.lua        — Action factory functions
    player.lua         — Player input → Actions
  ecs/                 — ECS simulation layer
    world.lua          — World: entities, systems, events, action queue
    components/
      init.lua         — Component factory functions
    systems/
      action.lua       — Consumes actions → mutates components
      bump.lua         — Top-down AABB collision (bump.lua)
      sword.lua        — Sword hitbox lifecycle + hit detection
      animation.lua    — Sprite animation driver
      timer.lua        — Timers component driver
      render.lua       — Z-sorted rendering
  events/
    init.lua           — Event name constants
  drawables/           — Renderable objects (drawAt interface)
    spritesheet.lua    — Quad-based sprite sheet
    sprite.lua         — Single image
    text.lua           — Text rendering
    blink.lua          — Visibility toggle decorator
    placeholder.lua    — Runtime-generated placeholder sprites
  components/
    timers.lua         — Named timer manager
  scenemanager.lua     — Scene stack manager
modules/               — Shared utilities (no game logic)
  object.lua           — Base class (OOP via metatables)
  events.lua           — EventBus (pub/sub)
  bump.lua             — bump.lua collision library (3rd party)
  json.lua             — JSON parser (3rd party)
  pq.lua               — Priority queue
  keydown.lua          — Keyboard polling helper
resources/             — Game assets
  sprites/             — Sprite sheet images
  sounds/              — Audio files
scenes/                — Game scenes
  worldscene.lua       — Base scene with World bridge
  room.lua             — Zelda room scene (walls + player + HUD)
```

## Code Style Guidelines

1. **Always use the Object base class** for new classes/systems
2. **Use `__init__()` for initialization** instead of constructor logic
3. **Validate parameters** using `__checkNotNil()` and `__checkKeys()`
4. **Follow the system pattern** with optional `init()`, `update()`, and `draw()` methods
5. **Keep components as pure data** — no logic in components
6. **Put logic in systems** that query for relevant components
7. **Use Actions for Domain → ECS communication** — domain objects never mutate components directly
8. **Use Events for ECS → Domain communication** — systems emit events, domain listens
9. **Use `game/events/init.lua` constants** for event names
10. **Use `game/ecs/components/init.lua` factories** to create components
11. **Return the class/system** at the end of each module file

## When Creating New Features

### Adding a New Action
1. Add a factory function in `game/domain/actions.lua`
2. Add a handler in `ActionSystem:update()` (`game/ecs/systems/action.lua`)

### Adding a New Component
1. Add a factory function in `game/ecs/components/init.lua`
2. Use the factory when spawning entities

### Adding a New System
1. Inherit from `Object`, implement `init()`, `update()`, and/or `draw()`
2. Add to the World in the scene's `__init__` — **order matters!**
3. Use `world:with()` for entity queries, `world:on()` for event listening

### Adding a New Domain Object
1. Create in `game/domain/`, inherit from `Object`
2. Read state via `world:getEntityById()`, produce Actions via `world:pushAction()`
3. **Never mutate components directly** — always go through Actions

### Adding a New Entity
1. Compose components using factories from `game/ecs/components/init.lua`
2. Call `world:spawn(entity)` — entities are plain tables with component keys

### Adding a New Drawable
1. Must implement `drawAt(x, y)` — draws centered at the given position
2. Place in `game/drawables/`

### Adding a New Event
1. Add a constant to `game/events/init.lua`
2. Emit from the appropriate system using `world:emit(Events.MY_EVENT, ...)`
3. Listen in domain objects or other systems via `world:on(Events.MY_EVENT, fn)`

## Example: Adding a Damage System

```lua
-- game/ecs/systems/damage.lua
local Object = require("modules.object")
local Events = require("game.events")

local DamageSystem = Object:new()

function DamageSystem:init(world)
    world:on(Events.SWORD_HIT, function(swordEntity, targetEntity)
        -- ECS emits the fact; domain applies meaning
        if targetEntity.Health then
            targetEntity.Health.current = targetEntity.Health.current - 1
            world:emit(Events.ENTITY_DAMAGED, targetEntity, 1)
            if targetEntity.Health.current <= 0 then
                world:emit(Events.ENTITY_DIED, targetEntity)
            end
        end
    end)
end

return DamageSystem
```

## Example: Adding a Monster Domain Object

```lua
-- game/domain/monster.lua
local Object = require("modules.object")
local Actions = require("game.domain.actions")

local Monster = Object:new()

function Monster:__init__(entity_id)
    self.entity_id = entity_id
    self.state = "patrol"
end

function Monster:think(world)
    local entity = world:getEntityById(self.entity_id)
    if not entity then return end

    if self.state == "patrol" then
        -- Simple AI: move in current facing direction
        local dir = entity.Facing and entity.Facing.direction or "down"
        local dx, dy = 0, 0
        if dir == "up" then dy = -1
        elseif dir == "down" then dy = 1
        elseif dir == "left" then dx = -1
        elseif dir == "right" then dx = 1
        end
        world:pushAction(Actions.Move(self.entity_id, dx, dy))
    end
end

return Monster
```

## Tips for AI Assistance

- **Respect the unidirectional flow**: Input/AI → Domain → Actions → ECS → Events → Domain
- Domain objects produce Actions; they never touch components directly
- Systems consume Actions and emit Events; they never call domain logic
- System execution order matters — add new systems at the right position
- When adding game mechanics, decide: is this Domain logic (rules/decisions) or ECS logic (simulation)?
- Use component factories for consistency; add new factory functions as needed
- Use event constants from `game/events/init.lua` — never use raw event strings
- Entities are plain tables; components are keys; there is no Entity class
- Position is always center-based (`cx`, `cy`); bump.lua conversion is handled internally
