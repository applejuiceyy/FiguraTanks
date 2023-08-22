local class = require "tank/command/commands/class"
local BaseNode = class("BaseNode")

function BaseNode:init()
    self.children = {}
end

function BaseNode:append(node)
    table.insert(self.children, node)
    return self
end

function BaseNode:with(callable, ...)
    callable(self, ...)
    return self
end

return BaseNode