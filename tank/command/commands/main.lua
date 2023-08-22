-- author: applejuice
-- stage: alpha
-- features may be missing

local Node = require("tank/command/commands/node")
local rootnode = require("tank/command/commands/rootnode")
local StringReader = require("tank/command/commands/stringreader")
local context      = require("tank/command/commands/context")
local util  = require "tank/command/commands/util"

local rootNodes = {}
local function withPrefix(pref, color)
    if rootNodes[pref] ~= nil then
        return rootNodes[pref]
    end
    local node = rootnode:new(pref, color)
    rootNodes[pref] = node
    return node
end

local function argWrap(required, str)
    if required then
        return "<" .. str .. ">";
    else

        return "[" .. str .. "]";
    end
end




local function literal(name)
    return Node:new(
        function (context)
            local r = context.reader:read(string.len(name))
            if r == name and (context.reader:peek() == " " or not context.reader:canRead()) then
                context:consumeSuggestion(string.len(name))
                return true
            end
        end,

        function (required)
            if required then
                return name
            end

            return argWrap(false, name)
        end
    ):suggests(function()
        return {name}
    end)
end

local function str(arg)
    return Node:new(
        function (context)
            local start = context.reader:getCursor()
            local s = context.reader:readString()
            if s == nil then
                return nil
            end
            context:consumeSuggestion(context.reader:getCursor() - start)
            context:addArgument(arg, s)
            return true
        end,

        function(required)
            return argWrap(required, arg .. ": string")
        end
    )
end

local function integer(arg)
    return Node:new(
        function (context)
            local start = context.reader:getCursor()
            local n = context.reader:readInteger()

            if n == nil then
                return nil
            end
            context:consumeSuggestion(context.reader:getCursor() - start)
            context:addArgument(arg, n)
            return true
        end,

        function(required)
            return argWrap(required, arg .. ": integer")
        end
    )
end




local function parseNodes(context, node)
    for _, child in ipairs(node.children) do
        local pos = context.reader:getCursor()
        context.currentNode = child
        local success = child._parser(context)

        context.currentNode = nil

        if success then
            table.insert(context.nodes, child)
            if context.reader:peek() == " " then
                context.reader:skip()
            end
            return parseNodes(context, child)
        else
            context.reader:move(pos)
        end
    end
end

local function executeParse(ctx, root)
    if root.echoing then
        printJson(util.withColor("<< " .. ctx.reader._str .. "\n", root.echoColor))
    end

    local cctx = context.CommandContext:new(ctx.args, root.color)

    if ctx.reader:canRead() then
        cctx:respond("Command Incomplete")
        return
    end

    local last = ctx.nodes[#ctx.nodes]
    
    if last.executor == nil then
        cctx:respond("Command incomplete")
        return
    end

    local blacklist = {}

    for i = #ctx.nodes, 1, -1 do
        local node = ctx.nodes[i]
        for _, uncheck in ipairs(node.uncheck) do
            blacklist[uncheck] = true
        end
        for _, check in ipairs(node.checkers) do
            if not blacklist[check] then
                local v = check(cctx)
                if type(v) == "string" then
                    cctx:respond("Cannot execute: " .. v)
                    return
                end
            end
        end
    end

    for _, check in ipairs(last.selfCheckers) do
        local v = check(cctx)
        if type(v) == "string" then
            cctx:respond("Cannot execute: " .. v)
            return
        end
    end

    last.executor(cctx)

    if not cctx._responded then
        cctx:respond("Command executed, but nothing was printed")
    end
end

local function getAutocomplete(context, pos)
    local current = 1
    local str = context.reader._str

    for _, suggester in pairs(context.suggestions) do
        if current <= pos and pos < current + suggester.size then

            if suggester.suggester == nil then
                return current, {}
            end

            local suggestions = suggester.suggester._suggester()
            
            local typed = string.sub(str, current, pos)
            local r = {}
            for _, suggestion in ipairs(suggestions) do
                local s = suggestion

                if type(s) == "table" then
                    s = suggestion.name
                end
                if string.sub(s, 1, string.len(typed)) == typed and typed ~= s then
                    table.insert(r, suggestion)
                end
            end
            return current, r
        end
        current = current + suggester.size + 1
    end

    local candidates = #context.nodes > 0 and context.nodes[#context.nodes] or context.root
    candidates = candidates.children

    local accumulate = {}
    for _, child in ipairs(candidates) do
        for _, suggestion in ipairs(child._suggester()) do
            table.insert(accumulate, suggestion)
        end
    end

    local r = {}
    for _, suggestion in ipairs(accumulate) do
        local s = suggestion
        if type(suggestion) == "table" then
            s = suggestion.name
        end

        local typed = string.sub(str, current)

        if typed == string.sub(s, 1, string.len(typed)) and typed ~= s then
            table.insert(r, suggestion)
        end
    end

    return current, r
end


local canSuggest = false
if host:isHost() then
    events.CHAT_SEND_MESSAGE:register(function(cmd)
        for prefix, node in pairs(rootNodes) do
            local cmdPrefix = string.sub(cmd, 1, string.len(prefix))

            if cmdPrefix == prefix then
                local stripped = string.sub(cmd, string.len(prefix) + 1)

                local context = context.ParsingContext:new(StringReader:new(stripped), node)

                local result, stuff = pcall(function()
                    parseNodes(context, node)
                    executeParse(context, node)
                end)

                if not result then
                    printJson(util.withColor("An error happened while executing:\n" .. stuff, vectors.hexToRGB("LUA_ERROR")))
                end

                host:appendChatHistory(cmd)

                return
            end
        end

        return cmd
    end)

    events.RENDER:register(function()
        local text = host:getChatText()
        if text ~= nil then
            for prefix, node in pairs(rootNodes) do
                local cmdPrefix = string.sub(text, 1, string.len(prefix))
    
                if cmdPrefix == prefix then
                    host:setChatColor(node.color)
                    return
                end
            end
    
            host:setChatColor(1, 1, 1)
        end
    end)
    if events.CHAT_AUTOCOMPLETE ~= nil then
        events.CHAT_AUTOCOMPLETE:register(function(cmd, pos)
            local result, stuff, stufff = pcall(function()
                for prefix, node in pairs(rootNodes) do
                    local cmdPrefix = string.sub(cmd, 1, string.len(prefix))

                    if cmdPrefix == prefix then
                        local stripped = string.sub(cmd, string.len(prefix) + 1)

                        local context = context.ParsingContext:new(StringReader:new(stripped), node)
                        parseNodes(context, node)
                        local cpos = pos
                        local pos, completion = getAutocomplete(context, pos - 2)
                        if #completion == 0 then
                            return true, {
                                result = "usage",
                                position = cpos,
                                usage = "Nothing to suggest"
                            }
                        end
                        return true, {
                            result = "suggest",
                            position = pos + string.len(prefix),
                            suggestions = completion
                        }
                    end
                end
            end)

            if not result then
                printJson(util.withColor("An error happened while completing:\n" .. stuff, vectors.hexToRGB("LUA_ERROR")))
            else
                return stuff, stufff
            end
        end)
        canSuggest = true
    end
end


return {
    withPrefix = withPrefix,
    Node = Node,
    str = str,
    integer = integer,
    literal = literal,

    canSuggest = canSuggest,
    argWrap = argWrap
}