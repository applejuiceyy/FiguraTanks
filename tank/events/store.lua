local class = require("tank/class")
local Event = require("tank/events/events")


local Store = class("Store", Event)

function Store:init(start)
    Event.init(self)
    self.value = start
end

function Store:register(func)
    local v = Event.register(self, func)
    func(self.value)
    return v
end

function Store:set(value)
    self.value = value
    self:fire(self.value)
end

function Store:conservativeSet(value)
    if self.value ~= value then
        return self:set(value)
    end
end

return Store