-- ECS World: manages entities, systems, events, and the action queue.
-- Unidirectional flow: Domain pushes Actions → ECS consumes → emits Events → Domain listens.
local Object = require("modules.object")
local EventBus = require("modules.events")

local World = Object:new()

World:augment({

    __init__ = function(self, systems)
        self.systems = {}
        self.entities = {}
        self.entity_index = {}      -- uid → entity
        self.component_sets = {}    -- component_name → { [entity] = true }
        self.component_counts = {}  -- component_name → count
        self.entity_id = 0
        self.events = EventBus:new()
        self.action_queue = {}
        self.perf_enabled = false
        self.perf_window_frames = 60
        self.perf_sample_frames = 0
        self.perf_update_total = 0
        self.perf_draw_total = 0
        self.perf_update_system_totals = {}
        self.perf_draw_system_totals = {}

        if systems then
            for _, sys in ipairs(systems) do
                self:addSystem(sys)
            end
        end
    end,

    -- Component index helpers (private)
    _indexEntity = function(self, entity)
        for key, value in pairs(entity) do
            if key ~= "uid" and value ~= nil then
                local set = self.component_sets[key]
                if not set then
                    set = {}
                    self.component_sets[key] = set
                    self.component_counts[key] = 0
                end
                if not set[entity] then
                    set[entity] = true
                    self.component_counts[key] = self.component_counts[key] + 1
                end
            end
        end
    end,

    _unindexEntity = function(self, entity)
        for key, _ in pairs(entity) do
            local set = self.component_sets[key]
            if set and set[entity] then
                set[entity] = nil
                self.component_counts[key] = self.component_counts[key] - 1
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
        if not system._perfName then
            system._perfName = "System" .. tostring(#self.systems)
        end
        if system.init then
            system:init(self)
        end
    end,

    -- Update all systems in order
    update = function(self, dt)
        local frameStart
        if self.perf_enabled then
            frameStart = love.timer.getTime()
        end

        for i, system in ipairs(self.systems) do
            if system.update then
                if self.perf_enabled then
                    local start = love.timer.getTime()
                    system:update(self, dt)
                    local elapsedMs = (love.timer.getTime() - start) * 1000
                    local name = system._perfName or ("System" .. tostring(i))
                    self.perf_update_system_totals[name] = (self.perf_update_system_totals[name] or 0) + elapsedMs
                else
                    system:update(self, dt)
                end
            end
        end

        if self.perf_enabled then
            self.perf_update_total = self.perf_update_total + ((love.timer.getTime() - frameStart) * 1000)
        end
    end,

    -- Draw all systems in order
    draw = function(self)
        local frameStart
        if self.perf_enabled then
            frameStart = love.timer.getTime()
        end

        love.graphics.setColor(1, 1, 1)
        for i, system in ipairs(self.systems) do
            if system.draw then
                if self.perf_enabled then
                    local start = love.timer.getTime()
                    system:draw(self)
                    local elapsedMs = (love.timer.getTime() - start) * 1000
                    local name = system._perfName or ("System" .. tostring(i))
                    self.perf_draw_system_totals[name] = (self.perf_draw_system_totals[name] or 0) + elapsedMs
                else
                    system:draw(self)
                end
            end
        end

        if self.perf_enabled then
            self.perf_draw_total = self.perf_draw_total + ((love.timer.getTime() - frameStart) * 1000)
            self.perf_sample_frames = self.perf_sample_frames + 1

            if self.perf_sample_frames >= self.perf_window_frames then
                local frames = self.perf_sample_frames
                print("[PERF] avg update=" .. string.format("%.3f", self.perf_update_total / frames) .. "ms avg draw=" .. string.format("%.3f", self.perf_draw_total / frames) .. "ms (" .. tostring(frames) .. " frames)")

                for i, system in ipairs(self.systems) do
                    local name = system._perfName or ("System" .. tostring(i))
                    local up = (self.perf_update_system_totals[name] or 0) / frames
                    local dr = (self.perf_draw_system_totals[name] or 0) / frames
                    if up > 0 or dr > 0 then
                        print("[PERF] " .. name .. " update=" .. string.format("%.3f", up) .. "ms draw=" .. string.format("%.3f", dr) .. "ms")
                    end
                end

                self.perf_sample_frames = 0
                self.perf_update_total = 0
                self.perf_draw_total = 0
                self.perf_update_system_totals = {}
                self.perf_draw_system_totals = {}
            end
        end
    end,

    setPerfEnabled = function(self, enabled)
        self.perf_enabled = not not enabled
        self.perf_sample_frames = 0
        self.perf_update_total = 0
        self.perf_draw_total = 0
        self.perf_update_system_totals = {}
        self.perf_draw_system_totals = {}
    end,

    isPerfEnabled = function(self)
        return self.perf_enabled
    end,

    -- Entity lifecycle
    spawn = function(self, entity)
        self.entity_id = self.entity_id + 1
        entity.uid = self.entity_id
        table.insert(self.entities, entity)
        self.entity_index[entity.uid] = entity
        self:_indexEntity(entity)
        self:emit("entity:spawned", entity)
        return entity
    end,

    destroy = function(self, entity)
        self:_unindexEntity(entity)
        for i, e in ipairs(self.entities) do
            if e == entity then
                table.remove(self.entities, i)
                self.entity_index[entity.uid] = nil
                break
            end
        end
        self:emit("entity:destroyed", entity)
    end,

    -- Entity queries (component-indexed: picks smallest set, checks the rest)
    query = function(self, component_names)
        -- Find the component with the fewest entities
        local pivot_name, pivot_set
        local pivot_count = math.huge
        for _, name in ipairs(component_names) do
            local count = self.component_counts[name] or 0
            if count == 0 then return {} end  -- no entities have this component
            if count < pivot_count then
                pivot_count = count
                pivot_name = name
                pivot_set = self.component_sets[name]
            end
        end
        if not pivot_set then return {} end

        local results = {}
        for entity in pairs(pivot_set) do
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
        -- Find the component with the fewest entities
        local pivot_set
        local pivot_count = math.huge
        for _, name in ipairs(component_names) do
            local count = self.component_counts[name] or 0
            if count == 0 then return end  -- no entities have this component
            if count < pivot_count then
                pivot_count = count
                pivot_set = self.component_sets[name]
            end
        end
        if not pivot_set then return end

        -- Snapshot the set keys so callbacks that spawn/destroy don't break iteration
        local snapshot = {}
        local n = 0
        for entity in pairs(pivot_set) do
            n = n + 1
            snapshot[n] = entity
        end

        for i = 1, n do
            local entity = snapshot[i]
            -- Verify entity still alive and still has all components
            if self.entity_index[entity.uid] then
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
