local class = require "tank.class"

---@params string ((fun(name:string):fun(...))|nil) table table
local PingChannel = class("PingChannel")

local function convertArguments(arguments, argumentPointer, argumentTypes, converters, directive)
    local ret = {}
    for i, type in ipairs(argumentTypes) do
        local argument = arguments[argumentPointer]
        local success, result = converters[type][directive](argument)
        if not success then
            error(result)
        end
        table.insert(ret, result)
        argumentPointer = argumentPointer + 1
    end
    return ret, argumentPointer
end

function PingChannel:init(name, backer, converters, dispatchArguments)
    self.name = name
    self.backer = backer or function(name)
        local n = self.name .. "$" .. name
        if pings[n] == nil then
            pings[n] = function(...)
                self:handle(name, {...}, 1)
            end
        end
        return function(...)
            pings[n](...)
        end
    end

    self.converters = converters

    self.dispatchArguments = dispatchArguments

    self.routing = {}
    self.childRouting = {}
end

function PingChannel:augment(converters)
    self.converters = setmetatable(converters, {__index = self.converters})
end

function PingChannel:register(opt)
    self.routing[opt.name] = opt
    local og = self.backer(opt.name)
    if #opt.arguments == 0 then
        return og
    end
    return function(...)
        local converted = convertArguments({...}, 1, opt.arguments, self.converters, "deflate")
        og(table.unpack(converted, 1, #opt.arguments))
    end
end

function PingChannel:registerAll(opts)
    local ret = {}
    for name, opt in pairs(opts) do
        opt.name = name
        ret[opt.name] = self:register(opt)
    end
    return ret
end

function PingChannel:handle(name, arguments, pointer)
    if self.routing[name] ~= nil then
        local things = self.routing[name]
        local converted, newPointer = convertArguments(arguments, pointer, things.arguments, self.converters, "inflate")
        things.func(table.unpack(converted))
        return
    end
    local child = self.childRouting[name]
    if #child.dispatchArguments == 0 then
        return child.dispatch():handle(child.name, arguments, pointer)
    else
        local converted, newPointer = convertArguments(arguments, pointer, child.dispatchArguments, self.converters, "inflate")

        local value = child.dispatch(table.unpack(converted))

        if value == nil then
            return
        end
        
        value:handle(child.name, arguments, newPointer)
    end
end

function PingChannel:inherit(name, dispatchArguments, dispatch, resolve, converters)
    local channel
    channel = PingChannel:new(name, function(pingName)
        self.childRouting[name .. "$" .. pingName] = {
            dispatchArguments = dispatchArguments,
            dispatch = dispatch or function() return channel end,
            name = pingName
        }
        local og = self.backer(name .. "$" .. pingName)
        if #dispatchArguments == 0 then
            return og
        end
        return function(...)
            local converted = convertArguments(resolve, 1, dispatchArguments, channel.converters, "deflate")
            og(table.unpack(converted, 1, #dispatchArguments), ...)
        end
    end, setmetatable(converters, {__index=self.converters}), dispatchArguments)
    return channel
end


return PingChannel