local noop = function(...) end
local new = function (self, ...)
    local obj = setmetatable({}, self)
    obj:init(...)
    return obj
end

---comment
---@param name string
local class = function (name, subclass)
    local obj = setmetatable({}, subclass or {__index = {functionsUseSelf = true}})
    obj.class = obj
    obj.name = name
    obj.__index = obj
    obj.init = noop
    obj.new = new
    return obj
end

return class