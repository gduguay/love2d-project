Object = require 'modules.object'

local PriorityQueue = Object:new()

function PriorityQueue:__init__()
    self.heap = {}
    self.counter = 0
end

local function parent(i) return math.floor(i / 2) end
local function left(i) return 2 * i end
local function right(i) return 2 * i + 1 end

local function swap(heap, i, j)
    heap[i], heap[j] = heap[j], heap[i]
end

local function heapify_down(self, i)
    local heap = self.heap
    local l, r, smallest = left(i), right(i), i

    if l <= #heap and (heap[l].priority < heap[smallest].priority or 
        (heap[l].priority == heap[smallest].priority and heap[l].order < heap[smallest].order)) then
        smallest = l
    end
    if r <= #heap and (heap[r].priority < heap[smallest].priority or 
        (heap[r].priority == heap[smallest].priority and heap[r].order < heap[smallest].order)) then
        smallest = r
    end

    if smallest ~= i then
        swap(heap, i, smallest)
        heapify_down(self, smallest)
    end
end

local function heapify_up(self, i)
    local heap = self.heap
    while i > 1 do
        local p = parent(i)
        if heap[p].priority < heap[i].priority or 
            (heap[p].priority == heap[i].priority and heap[p].order < heap[i].order) then
            break
        end
        swap(heap, i, p)
        i = p
    end
end

function PriorityQueue:push(value, priority)
    self.counter = self.counter + 1
    local node = {value = value, priority = priority, order = self.counter}
    table.insert(self.heap, node)
    heapify_up(self, #self.heap)
end

function PriorityQueue:pop()
    local heap = self.heap
    if #heap == 0 then return nil end

    swap(heap, 1, #heap)
    local minNode = table.remove(heap)
    heapify_down(self, 1)

    return minNode.value
end

function PriorityQueue:foreach(fn)
    for _, node in ipairs(self.heap) do
        fn(node.value, node.priority)
    end
end

return PriorityQueue