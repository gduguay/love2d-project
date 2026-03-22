-- ECS World: manages entities, systems, events, and the action queue.
-- Unidirectional flow: Domain pushes Actions → ECS consumes → emits Events → Domain listens.
local Object = require("modules.object")
local EventBus = require("modules.events")

local World = Object:new()

World:augment({

    __init__ = function(self, systems)
        self.systems = {}
        self.entities = {}
        self.entity_index = {}
        self.entity_id = 0
        self.events = EventBus:new()
        self.action_queue = {}

        if systems then
            for _, sys in ipairs(systems) do
                self:addSystem(sys)
            end
        end
    end,

    -- Action queue: Domain pushes actions, ActionSystem consumes them
    pushAction = function(self, action)
        table.insert(self.action_queue, action)
    end,

    consumeActions = function(self)
        local actions = self.action_queue
        self.action_queue = {}
        return actions
    end,

    -- System management
    addSystem = function(self, system)
        table.insert(self.systems, system)
        if system.init then
            system:init(self)
        end
    end,

    -- Update all systems in order
    update = function(self, dt)
        for _, system in ipairs(self.systems) do
            if system.update then
                system:update(self, dt)
            end
        end
    end,

    -- Draw all systems in order
    draw = function(self)
        love.graphics.setColor(1, 1, 1)
        for _, system in ipairs(self.systems) do
            if system.draw then
                system:draw(self)
            end
        end
    end,

    -- Entity lifecycle
    spawn = function(self, entity)
        self.entity_id = self.entity_id + 1
        entity.uid = self.entity_id
        table.insert(self.entities, entity)
        self.entity_index[entity.uid] = entity
        self:emit("entity:spawned", entity)
        return entity
    end,

    destroy = function(self, entity)
        for i, e in ipairs(self.entities) do
            if e == entity then
                table.remove(self.entities, i)
                self.entity_index[entity.uid] = nil
                break
            end
        end
        self:emit("entity:destroyed", entity)
    end,

    -- Entity queries
    query = function(self, component_names)
        local results = {}
        for _, entity in ipairs(self.entities) do
            local has_all = true
            for _, name in ipairs(component_names) do
                if entity[name] == nil then
                    has_all = false
                    break
                end
            end
            if has_all then
                table.insert(results, entity)
            end
        end
        return results
    end,

    with = function(self, component_names, fn)
        for _, entity in ipairs(self.entities) do
            local has_all = true
            for _, name in ipairs(component_names) do
                if entity[name] == nil then
                    has_all = false
                    break
                end
            end
            if has_all then
                fn(entity)
            end
        end
    end,

    -- Event bus delegation
    on = function(self, event, listener)
        return self.events:subscribe(event, listener)
    end,

    emit = function(self, event, ...)
        self.events:emit(event, ...)
    end,

    -- Entity lookup
    getEntityById = function(self, id)
        return self.entity_index[id]
    end,
})

return World
