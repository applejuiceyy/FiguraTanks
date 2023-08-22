local class = require "tank/command/commands/class"
local basenode = require "tank/command/commands/basenode"
local util     = require "tank/command/commands/util"
local context  = require "tank/command/commands/context"
local stringreader = require "tank/command/commands/stringreader"
local RootNode = class("BaseNode", basenode)


function RootNode:init(prefix, color)
    basenode.init(self)
    self.prefix = prefix
    self.color = color
    self.echoColor = color * 0.7

    self._echoing = false
    self._help = false
end

function RootNode:addHelp()
    if self._help then
        return
    end
    self._help = true
    local main = require("tank/command/commands/main")
    self:append(
        main.literal("help")
        :append(
            main.str("name")
            :executes(function (ctx)
                for _, node in pairs(self.children) do
                    local sr = stringreader:new(ctx.args.name)
                    local pctx = context.ParsingContext:new(sr, self)
                    if node._parser(pctx) then
                        local res = "All formats for command " .. node._format(true) .. ":\n"

                        node:getFormats(function(t)
                            res = res .. "    " .. t .. "\n"
                        end)

                        ctx:respond(res)
                        return
                    end
                end
                ctx:respond("No command matching " .. ctx.args.name)

                self:getFormats(function(n) print(n) end)
            end)
        )
        :executes(function(ctx)
            local res = "All commands:\n"
            for _, node in pairs(self.children) do
                res = res .. "    " .. node._format(true) .. "\n"
            end
            ctx:respond(res .. "\ntype " .. self.prefix .. "help [name] to get information about a command")
            local main = require("tank/command/commands/main")

            if not main.canSuggest then
            ctx:respond("\nThis command parser is compatible with autocomplete, but there doesn't seem to be an autocomplete event")
            end
        end)
    )
    return self
end

function RootNode:echoing()
    self._echoing = true
end

return RootNode