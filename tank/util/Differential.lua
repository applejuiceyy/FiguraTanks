local class = require "tank.class"

---@params function function function function
local Differential = class("Differential")

local SENTINEL = {}

function Differential:init(iterator, creation, destruction, keyer)
    self.iterator = iterator
    self.creation = creation
    self.destruction = destruction
    self.keyer = keyer

    self.current = {}
end

function Differential:update(update)
    local iterator, invariant, control = self.iterator()
    local seen = {}

    debugger:region("creation")
    while true do
        local stuff = {iterator(invariant, control)}
        control = stuff[1]
        if control == nil then break end

        local key = self.keyer(table.unpack(stuff))
        
        if self.current[key] == nil then
            local val = self.creation(table.unpack(stuff))
            if val == nil then
                val = SENTINEL
            end
            self.current[key] = val
        end
        seen[key] = true
    end
    debugger:region("update")

    iterator, invariant, control = self.iterator()
    
    while true do
        local stuff = {iterator(invariant, control)}
        control = stuff[1]
        if control == nil then break end

        local key = self.keyer(table.unpack(stuff))

        if self.current[key] ~= SENTINEL then
            update(self.current[key])
        end
    end

    debugger:region("pruning")
    local o = {}
    for key, v in pairs(self.current) do
        if not seen[key] then
            self.destruction(v)
            o[key] = true
        end
    end
    debugger:region("removal")
    for key in pairs(o) do
        self.current[key] = nil
    end
end

function Differential:iterateWithoutUpdate(update)
    local iterator, invariant, control = self.iterator()
    
    while true do
        local stuff = {iterator(invariant, control)}
        control = stuff[1]
        if control == nil then break end

        local key = self.keyer(table.unpack(stuff))
        
        if self.current[key] ~= nil and self.current[key] ~= SENTINEL and update(self.current[key]) then
            return
        end
    end
end

function Differential:dispose()
    for key, v in pairs(self.current) do
        self.destruction(v)
    end
    self.current = {}
end


return Differential