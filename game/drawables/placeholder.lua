-- Generates a placeholder sprite sheet image at runtime.
-- 4 rows (down, up, left, right) × 4 cols (idle, walk1, walk2, attack)
-- Each frame is quadWidth × quadHeight with a colored body and direction indicator.

local function generatePlaceholderSheet(quadWidth, quadHeight)
    local cols, rows = 4, 4
    local canvas = love.graphics.newCanvas(cols * quadWidth, rows * quadHeight)

    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)

    local directions = {"down", "up", "left", "right"}
    local bodyColor = {0.2, 0.6, 0.3, 1}      -- green body
    local arrowColor = {1, 1, 1, 1}             -- white arrow
    local attackColor = {0.9, 0.9, 0.2, 1}      -- yellow for attack frame

    for row = 1, rows do
        for col = 1, cols do
            local x = (col - 1) * quadWidth
            local y = (row - 1) * quadHeight
            local cx = x + quadWidth / 2
            local cy = y + quadHeight / 2

            -- Body (slightly smaller than full quad for visual padding)
            local pad = 4
            local bw = quadWidth - pad * 2
            local bh = quadHeight - pad * 2

            local isAttack = (col == 4)

            -- Draw body
            love.graphics.setColor(bodyColor)
            love.graphics.rectangle("fill", x + pad, y + pad, bw, bh, 4, 4)

            -- Walk animation: offset body slightly for walk frames
            if col == 2 then
                love.graphics.setColor(bodyColor[1] + 0.1, bodyColor[2], bodyColor[3], 1)
                love.graphics.rectangle("fill", x + pad + 1, y + pad - 1, bw, bh, 4, 4)
            elseif col == 3 then
                love.graphics.setColor(bodyColor[1] + 0.1, bodyColor[2], bodyColor[3], 1)
                love.graphics.rectangle("fill", x + pad - 1, y + pad + 1, bw, bh, 4, 4)
            end

            -- Attack frame: draw a sword extension
            if isAttack then
                love.graphics.setColor(attackColor)
                local dir = directions[row]
                if dir == "down" then
                    love.graphics.rectangle("fill", cx - 3, y + quadHeight - pad, 6, pad + 2)
                elseif dir == "up" then
                    love.graphics.rectangle("fill", cx - 3, y - 2, 6, pad + 2)
                elseif dir == "left" then
                    love.graphics.rectangle("fill", x - 2, cy - 3, pad + 2, 6)
                elseif dir == "right" then
                    love.graphics.rectangle("fill", x + quadWidth - pad, cy - 3, pad + 2, 6)
                end
            end

            -- Direction indicator (small triangle/arrow)
            love.graphics.setColor(arrowColor)
            local dir = directions[row]
            local as = 5  -- arrow size
            if dir == "down" then
                love.graphics.polygon("fill", cx, cy + as, cx - as, cy - as/2, cx + as, cy - as/2)
            elseif dir == "up" then
                love.graphics.polygon("fill", cx, cy - as, cx - as, cy + as/2, cx + as, cy + as/2)
            elseif dir == "left" then
                love.graphics.polygon("fill", cx - as, cy, cx + as/2, cy - as, cx + as/2, cy + as)
            elseif dir == "right" then
                love.graphics.polygon("fill", cx + as, cy, cx - as/2, cy - as, cx - as/2, cy + as)
            end
        end
    end

    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1, 1)

    return canvas
end

-- Build the animation definition table for the placeholder sheet.
-- Rows: 1=down, 2=up, 3=left, 4=right
-- Cols: 1=idle, 2=walk1, 3=walk2, 4=attack
local function buildAnimations(cols)
    local dirs = {"down", "up", "left", "right"}
    local anims = {}

    for i, dir in ipairs(dirs) do
        local rowOffset = (i - 1) * cols

        -- Idle: single frame
        anims["idle_" .. dir] = {
            frames = { rowOffset + 1 },
            duration = 1,
            loop = true,
        }

        -- Walk: 2 frames alternating
        anims["walk_" .. dir] = {
            frames = { rowOffset + 2, rowOffset + 3 },
            duration = 0.3,
            loop = true,
        }

        -- Attack: single frame
        anims["attack_" .. dir] = {
            frames = { rowOffset + 4 },
            duration = 0.2,
            loop = false,
        }
    end

    return anims
end

return {
    generatePlaceholderSheet = generatePlaceholderSheet,
    buildAnimations = buildAnimations,
}
