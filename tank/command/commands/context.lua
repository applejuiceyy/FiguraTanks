local class = require "tank/command/commands/class"
local util  = require "tank/command/commands/util"
local ParsingContext = class("ParsingContext")
local CommandContext = class("CommandContext")

function ParsingContext:init(reader, root)
    self.reader = reader
    self.args = {}
    self.nodes = {}
    self.suggestions = {}
    self.root = root

    self.currentNode = nil
end

function ParsingContext:addArgument(name, value)
    self.args[name] = value
end

function ParsingContext:consumeSuggestion(extends)
    table.insert(self.suggestions, {size = extends, suggester = self.currentNode})
end

function ParsingContext:copy()
    local c = ParsingContext:new(self.reader)
    for a, b in pairs(self.args) do
        c.args[a] = b
    end
    for a, b in pairs(self.suggestions) do
        c.suggestions[a] = b
    end
    return c
end


function CommandContext:init(args, responseColor)
    self.args = args
    self.responseColor = responseColor

    self._responded = false
end

function CommandContext:respond(text, color)
    self._responded = true
    printJson(util.withColor(text .. "\n", self.responseColor or color))
end

return {ParsingContext = ParsingContext, CommandContext = CommandContext}