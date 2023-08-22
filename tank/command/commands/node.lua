local class = require "tank/command/commands/class"
local BaseNode = require "tank/command/commands/basenode"
local Node = class("Node", BaseNode)

function Node:init(parser, format)
    BaseNode.init(self)
    self._parser = parser
    self._suggester = function() return {} end
    self._format = format

    self.executor = nil
    self.checkers = {}
    self.selfCheckers = {}

    self.uncheck = {}
end

function Node:executes(executor)
    self.executor = executor
    return self
end

function Node:suggests(suggester)
    self._suggester = suggester
    return self
end

function Node:check(checker)
    table.insert(self.checkers, checker)
    return self
end

function Node:selfCheck(checker)
    table.insert(self.selfCheckers, checker)
    return self
end

function Node:withoutCheck(check)
    table.insert(self.uncheck, check)
    return self
end

function Node:getFormats(consumer, before, required)
    if before == nil then
        before = ""
    end
    if required == nil then
        required = true
    end

    local withSelf = before .. self._format(required)

    for i, node in ipairs(self.children) do
        node:getFormats(consumer, withSelf .. " ", self.executor == nil)
    end

    if self.executor ~= nil then
        consumer(withSelf)
    end
end

return Node