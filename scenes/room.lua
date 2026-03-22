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

-- Colors
local FLOOR_COLOR = {0.76, 0.70, 0.50}  -- sandy/tan
local WALL_COLOR = {0.35, 0.25, 0.15}   -- dark brown

function RoomScene:__init__()
    -- Create ECS world with systems in correct order
    self.world = World:new({
        ActionSystem:new(),
        SwordSystem:new(),
        BumpSystem:new(),
        AnimationSystem:new(),
        TimerSystem:new(),
        RenderSystem:new(),
    })

    -- Spawn room geometry (walls)
    self:createRoom()

    -- Spawn player entity
    local playerEntity = self:createPlayer()

    -- Create domain-layer Player object
    self.player = Player:new(playerEntity.uid)
    self.player:syncView(self.world)

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
        Attacking = Components.Attacking(0.2),
        ZOrder = Components.ZOrder(1),
    })

    return entity
end

function RoomScene:wireEvents()
    local world = self.world

    -- Listen for sword hits (ECS → Domain)
    world:on(Events.SWORD_HIT, function(swordEntity, targetEntity)
        -- Future: apply damage, knockback, etc.
        -- For now, just a proof-of-concept
    end)

    -- Listen for attack key press (forwarded from love:keypressed)
    world:on("love:keypressed", function(key)
        if key == "space" or key == "x" then
            self.player:handleAttackPressed(world)
        end
    end)
end

function RoomScene:update(dt)
    -- Domain layer: read input, produce actions
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

    love.graphics.setColor(1, 1, 1, 1)
end

function RoomScene:handleEvent(event, ...)
    if self.world then
        self.world:emit("love:" .. event, ...)
    end
end

return RoomScene
