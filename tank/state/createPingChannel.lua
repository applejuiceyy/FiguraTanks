return function (name, registry, dispatching)
    local ret = {}
    for pingName, _function in pairs(registry) do
        local fullName = name .. "$" .. pingName
        pings[fullName] = function(...)
            return dispatching(_function, ...)
        end
        ret[pingName] = pings[fullName]
    end
    return ret
end
