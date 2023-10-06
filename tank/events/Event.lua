local class        = require("tank/class")

local Event        = class("Event")
local Subscription = class("Subscription")

local __recorder = nil

function Subscription:init(event, name)
    self.event = event
    self.name = name

    if __recorder ~= nil then
        self:record(__recorder)
    end
end

function Subscription:record(recorder)
    recorder:record(function() self:remove() end)
end

function Subscription:remove()
    self.event:remove(self.name)
end

function Event:init()
    self.subs = {}
end

function Event:register(func)
    local name = {}
    self.subs[name] = func
    return Subscription:new(self, name)
end

function Event:fire(...)
    for _, v in pairs(self.subs) do
        v(...)
    end
end

function Event:remove(name)
    self.subs[name] = nil
end

function Event.beginRecord(recorder)
    __recorder = recorder
end

function Event.endRecord()
    __recorder = nil
end

return Event