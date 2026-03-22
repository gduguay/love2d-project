return function(...)
    for _, key in ipairs({...}) do
        if love.keyboard.isDown(key) then
            return true
        end
    end
    return false
end