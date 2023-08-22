---comment
---@param name string
---@param subclass table?
---@return {new:fun(...):any}
return function (name, subclass)
    local obj = setmetatable({}, subclass or {})
    obj.class = obj
    obj.name = name
    obj.__index = obj
    obj.init = function(...) end

    function obj:new(...)
        local obj = setmetatable({}, self)
        obj:init(...)
        return obj
    end

    return obj
end