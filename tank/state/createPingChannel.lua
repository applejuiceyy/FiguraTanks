return function (name, registry, dispatching)
    local ret = {}
    for pingName, _function in pairs(registry) do
        local fullName = name .. "$" .. pingName
        pings[fullName] = function(...)
            local success, result = pcall(dispatching, _function, ...)

            if not success then
                if not (type(result) == "table" and result.nonerror == true) then
                    error(result, 0)
                end
            end
        end
        ret[pingName] = pings[fullName]
    end
    return ret
end
