-- Room scene: a single Zelda-style room with a player that can move and attack.
-- Demonstrates the full architecture flow:
--   Input → Domain (Player) → Actions → ECS (World) → Events → Domain
local Object = require("modules.object")
local World = require("game.ecs.world")
local Components = require("game.ecs.components")
local Events = require("game.events")
local Player = require("game.domain.player")
local SpriteSheet = require("game.drawables.spritesheet")
local Placeholder = require("game.drawables.placeholder")

-- Systems (order matters!)
local ActionSystem = require("game.ecs.systems.action")
local SwordSystem = require("game.ecs.systems.sword")
local BumpSystem = require("game.ecs.systems.bump")
local AnimationSystem = require("game.ecs.systems.animation")
local TimerSystem = require("game.ecs.systems.timer")
local DamageSystem = require("game.ecs.systems.damage")
local RenderSystem = require("game.ecs.systems.render")

local WorldScene = require("scenes.worldscene")
local RoomScene = WorldScene:new()

-- Room layout constants
local TILE = 32
local ROOM_COLS = 10  -- 320 / 32
local ROOM_ROWS = 6   -- 192 / 32 (leaving 8px for HUD at bottom)
local ROOM_W = ROOM_COLS * TILE
local ROOM_H = ROOM_ROWS * TILE
local WALL_THICKNESS = TILE  -- 1 tile thick walls
local MONSTER_STEP = 50

-- Colors
local FLOOR_COLOR = {0.76, 0.70, 0.50}  -- sandy/tan
local WALL_COLOR = {0.35, 0.25, 0.15}   -- dark brown

function RoomScene:__init__()
    -- Create ECS world with systems in correct order
    local actionSystem = ActionSystem:new()
    actionSystem._perfName = "ActionSystem"
    local swordSystem = SwordSystem:new()
    swordSystem._perfName = "SwordSystem"
    local damageSystem = DamageSystem:new()
    damageSystem._perfName = "DamageSystem"
    local bumpSystem = BumpSystem:new()
    bumpSystem._perfName = "BumpSystem"
    local animationSystem = AnimationSystem:new()
    animationSystem._perfName = "AnimationSystem"
    local timerSystem = TimerSystem:new()
    timerSystem._perfName = "TimerSystem"
    local renderSystem = RenderSystem:new()
    renderSystem._perfName = "RenderSystem"

    self.world = World:new({
        actionSystem,
        swordSystem,
        damageSystem,
        bumpSystem,
        animationSystem,
        timerSystem,
        renderSystem,
    })

    -- Spawn room geometry (walls)
    self:createRoom()

    -- Spawn player entity
    local playerEntity = self:createPlayer()

    -- Create domain-layer Player object
    self.player = Player:new(playerEntity.uid)
    self.player:syncView(self.world)
    self.monsterEntities = {}

    -- Spawn bouncing monsters
    self:createMonsters(20)

    -- Wire ECS events → Domain
    self:wireEvents()
end

function RoomScene:createRoom()
    local world = self.world

    -- Floor tiles are just drawn as background (no entities needed)

    -- Wall entities: top, bottom, left, right
    -- Top wall
    world:spawn({
        Position = Components.Position(ROOM_W / 2, WALL_THICKNESS / 2),
        Collider = Components.Collider(ROOM_W, WALL_THICKNESS),
        Solid = Components.Solid(),
        Wall = Components.Wall(),
        Drawable = self:makeWallDrawable(ROOM_W, WALL_THICKNESS),
        ZOrder = Components.ZOrder(0),
    })

    -- Bottom wall
    world:spawn({
        Position = Components.Position(ROOM_W / 2, ROOM_H - WALL_THICKNESS / 2),
        Collider = Components.Collider(ROOM_W, WALL_THICKNESS),
        Solid = Components.Solid(),
        Wall = Components.Wall(),
        Drawable = self:makeWallDrawable(ROOM_W, WALL_THICKNESS),
        ZOrder = Components.ZOrder(0),
    })

    -- Left wall
    world:spawn({
        Position = Components.Position(WALL_THICKNESS / 2, ROOM_H / 2),
        Collider = Components.Collider(WALL_THICKNESS, ROOM_H),
        Solid = Components.Solid(),
        Wall = Components.Wall(),
        Drawable = self:makeWallDrawable(WALL_THICKNESS, ROOM_H),
        ZOrder = Components.ZOrder(0),
    })

    -- Right wall
    world:spawn({
        Position = Components.Position(ROOM_W - WALL_THICKNESS / 2, ROOM_H / 2),
        Collider = Components.Collider(WALL_THICKNESS, ROOM_H),
        Solid = Components.Solid(),
        Wall = Components.Wall(),
        Drawable = self:makeWallDrawable(WALL_THICKNESS, ROOM_H),
        ZOrder = Components.ZOrder(0),
    })
end

function RoomScene:makeWallDrawable(w, h)
    return {
        drawAt = function(_, x, y)
            love.graphics.setColor(WALL_COLOR)
            love.graphics.rectangle("fill", x - w/2, y - h/2, w, h)
            love.graphics.setColor(1, 1, 1, 1)
        end
    }
end

function RoomScene:createPlayer()
    -- Generate placeholder sprite sheet
    local sheetImage = Placeholder.generatePlaceholderSheet(TILE, TILE)
    local animations = Placeholder.buildAnimations(4) -- 4 columns

    local spriteSheet = SpriteSheet:new({
        image = sheetImage,
        quadWidth = TILE,
        quadHeight = TILE,
    })

    local entity = self.world:spawn({
        Position = Components.Position(ROOM_W / 2, ROOM_H / 2),
        Velocity = Components.Velocity(0, 0),
        Facing = Components.Facing("down"),
        Collider = Components.Collider(22, 22, "slide"),  -- slightly smaller than tile
        Solid = Components.Solid(),
        MovementSpeed = Components.MovementSpeed(120),
        Drawable = spriteSheet,
        AnimationState = Components.AnimationState(animations, "idle_down"),
        PlayerControlled = Components.PlayerControlled(),
        Health = Components.Health(3, 3),
        EntityState = Components.EntityState("idle"),
        ZOrder = Components.ZOrder(1),
    })

    return entity
end

function RoomScene:makeMonsterDrawable(r, g, b)
    return {
        drawAt = function(_, x, y)
            love.graphics.setColor(r, g, b, 1)
            love.graphics.rectangle("fill", x - 2, y - 2, 4, 4)
            love.graphics.setColor(1, 1, 1, 1)
        end
    }
end

function RoomScene:createMonsters(count)
    local margin = WALL_THICKNESS + 4  -- keep monsters inside walls
    for i = 1, count do
        -- Random position inside the room
        local cx = margin + math.random() * (ROOM_W - 2 * margin)
        local cy = margin + math.random() * (ROOM_H - 2 * margin)

        -- Random direction and speed
        local angle = math.random() * math.pi * 2
        local speed = 30 + math.random() * 70  -- 30-100 pixels/sec
        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed

        -- Random bright color
        local r = 0.4 + math.random() * 0.6
        local g = 0.4 + math.random() * 0.6
        local b = 0.4 + math.random() * 0.6

        local monster = self.world:spawn({
            Position = Components.Position(cx, cy),
            Velocity = Components.Velocity(vx, vy),
            Collider = Components.Collider(4, 4, "bounce"),
            Monster = Components.Monster(),
            Health = Components.Health(1, 1),
            Drawable = self:makeMonsterDrawable(r, g, b),
            ZOrder = Components.ZOrder(1),
        })
        table.insert(self.monsterEntities, monster)
    end
end

function RoomScene:removeMonsters(count)
    local toRemove = math.min(count, #self.monsterEntities)
    for i = 1, toRemove do
        local monster = table.remove(self.monsterEntities)
        if monster then
            self.world:destroy(monster)
        end
    end
end

function RoomScene:wireEvents()
    local world = self.world

    -- Track monster deaths so we can remove them from monsterEntities
    world:on(Events.ENTITY_DIED, function(entity)
        if entity.Monster then
            for i, m in ipairs(self.monsterEntities) do
                if m == entity then
                    table.remove(self.monsterEntities, i)
                    break
                end
            end
        end
    end)

    -- Listen for attack key press (forwarded from love:keypressed)
    world:on("love:keypressed", function(key)
        if key == "space" or key == "x" then
            self.player:handleAttackPressed(world)
        elseif key == "m" then
            self.player:handleDashPressed(world)
        elseif key == "f3" then
            world:setPerfEnabled(not world:isPerfEnabled())
            print("[PERF] profiler " .. (world:isPerfEnabled() and "enabled" or "disabled"))
        elseif key == "]" then
            self:createMonsters(MONSTER_STEP)
            print("[PERF] monsters=" .. tostring(#self.monsterEntities))
        elseif key == "[" then
            self:removeMonsters(MONSTER_STEP)
            print("[PERF] monsters=" .. tostring(#self.monsterEntities))
        end
    end)
end

function RoomScene:update(dt)
    -- Domain layer: tick FSM timers (auto-transitions, phase advancement)
    self.player:updateFSM(dt, self.world)

    -- Domain layer: read input, produce actions (gated by FSM)
    self.player:handleInput(self.world)

    -- ECS layer: consume actions, simulate, emit events
    self.world:update(dt)

    -- Sync domain view model from ECS state (for HUD/UI)
    self.player:syncView(self.world)
end

function RoomScene:draw()
    -- Draw floor background
    love.graphics.setColor(FLOOR_COLOR)
    love.graphics.rectangle("fill", 0, 0, ROOM_W, ROOM_H)
    love.graphics.setColor(1, 1, 1, 1)

    -- Draw floor grid (subtle)
    love.graphics.setColor(0.68, 0.62, 0.44, 0.3)
    for col = 0, ROOM_COLS do
        love.graphics.line(col * TILE, 0, col * TILE, ROOM_H)
    end
    for row = 0, ROOM_ROWS do
        love.graphics.line(0, row * TILE, ROOM_W, row * TILE)
    end
    love.graphics.setColor(1, 1, 1, 1)

    -- Draw ECS entities (walls, player, sword hitboxes, etc.)
    self.world:draw()

    -- Draw HUD below the room area
    self:drawHUD()
end

function RoomScene:drawHUD()
    local hudY = ROOM_H + 1
    love.graphics.setColor(0.1, 0.1, 0.1, 1)
    love.graphics.rectangle("fill", 0, hudY, ROOM_W, 200 - ROOM_H)

    -- Draw hearts from the Player view model (no ECS component access)
    local view = self.player.view
    local heartSize = 7
    local heartSpacing = 10
    local startX = 4
    for i = 1, view.maxHp do
        if i <= view.hp then
            love.graphics.setColor(1, 0, 0, 1)  -- red = filled
        else
            love.graphics.setColor(0.3, 0.3, 0.3, 1)  -- gray = empty
        end
        local hx = startX + (i - 1) * heartSpacing
        love.graphics.rectangle("fill", hx, hudY + 1, heartSize, heartSize)
    end

    -- FPS counter
    love.graphics.setColor(1, 1, 1, 1)
    local fpsText = "FPS: " .. love.timer.getFPS()
    local fpsX = ROOM_W - love.graphics.getFont():getWidth(fpsText) - 4
    love.graphics.print(fpsText, fpsX, hudY + 1)

    local monsterText = "M: " .. tostring(#self.monsterEntities)
    local monsterX = fpsX - love.graphics.getFont():getWidth(monsterText) - 8
    love.graphics.print(monsterText, monsterX, hudY + 1)

    -- Player state/phase
    local stateText = view.state or "?"
    if view.phase then
        stateText = stateText .. ":" .. view.phase
    end
    local stateX = startX + view.maxHp * heartSpacing + 8
    love.graphics.setColor(0.8, 0.8, 0.2, 1)
    love.graphics.print(stateText, stateX, hudY + 1)

    love.graphics.setColor(1, 1, 1, 1)
end

function RoomScene:handleEvent(event, ...)
    if self.world then
        self.world:emit("love:" .. event, ...)
    end
end

return RoomScene
