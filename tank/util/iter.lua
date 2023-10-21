local function count(step, current)
    return step + current
end

local iter iter = {
    closure = function(upstream, invariant, control)
        return function()
            local stuff = {upstream(invariant, control)}
            control = stuff[1]

            if control == nil then
                return
            end

            return table.unpack(stuff)
        end
    end,

    count = function(start, step)
        return count, step, start
    end,

    cycle = function(upstream, invariant, control)
        local previous = {}
        local live = true
        local pos = 1

        return function()
            if live then
                local stuff = {upstream(invariant, control)}
                control = stuff[1]

                if control ~= nil then
                    table.insert(previous, stuff)
                    return table.unpack(stuff)
                end

                live = false
            end

            local stuff = previous[pos]
            pos = pos + 1
            if pos > #previous then
                pos = 1
            end

            return table.unpack(stuff)
        end
    end,

    repeatValue = function(value, c)
        return function()
            c = c - 1
            if c < 0 then
                return
            end
            return value
        end
    end,

    map = function (map, upstream, invariant, control)
        return function()
            local stuff = {upstream(invariant, control)}
            control = stuff[1]

            if control == nil then
                return
            end

            return map(table.unpack(stuff))
        end
    end,

    join = function(upstream, invariant, control)
        return function(upstream2, invariant2, control2)
            local closured = iter.closure(upstream, invariant, control)
            local closured2 = iter.closure(upstream2, invariant2, control2)
            local isSecond = false
            return function()
                if not isSecond then
                    local stuff = {closured()}
                    if stuff[1] ~= nil then
                        return table.unpack(stuff)
                    end
                    isSecond = true
                end
                local stuff = {closured2()}
                if stuff[1] ~= nil then
                    return table.unpack(stuff)
                end
            end
        end
    end
}

return iter