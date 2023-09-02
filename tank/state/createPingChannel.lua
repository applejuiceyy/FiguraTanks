local function convertTable(values, argumentTypes, converters, directive)
    local ret = {}

    for idx, value in ipairs(values) do
        local t = argumentTypes[idx]
        if t ~= nil and t ~= "default" then
            value = converters[directive](value)
        end
        table.insert(ret, value)
    end

    return ret
end

return function (name, registry, valueConverters, dispatching)
    local ret = {}
    for pingName, data in pairs(registry) do
        local fullName = name .. "$" .. pingName
        local arguments = {}
        local fn = data

        if type(data) == "table" then
            arguments = data.arguments
            fn = data.fn
        end

        pings[fullName] = function(...)
            local success, result = pcall(
                dispatching, fn,
                table.unpack(convertTable({...}, arguments, valueConverters, "inflate"))
            )

            if not success then
                if not (type(result) == "table" and result.nonerror == true) then
                    error(result, 0)
                end
            end
        end

        ret[pingName] = function(...)
            pings[fullName](table.unpack(convertTable({...}, arguments, valueConverters, "deflate")))
        end
    end
    return ret
end
