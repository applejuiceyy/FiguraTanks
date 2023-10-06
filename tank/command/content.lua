local command        = require("tank/command/commands/main")
local State          = require("tank.state.State")
local settings       = require("tank.settings")

local function traverseSettings(consumer, prefix, obj)
    for name, thing in pairs(obj) do
        if type(thing) == "table" then
            traverseSettings(consumer, prefix .. name .. ".", thing)
        else
            consumer(prefix .. name)
        end
    end
end

local function SettingsNode(arg)
    return command.str(arg)
    :suggests(function()
        local ret = {}
        traverseSettings(function(name) table.insert(ret, name) end, "", settings)
        return ret
    end)
end

local function traverseGet(name, obj)
    local pos = string.find(name, ".", nil, true)
    if pos == nil then
        return obj[name]
    else
        local chunk = string.sub(name, 1, pos)
        local subthing = obj[chunk]
        if subthing == nil then
            return nil
        end
        return traverseGet(string.sub(name, pos + 1), subthing)
    end
end

local function traverseSet(name, obj, value)
    local pos = string.find(name, ".", nil, true)
    if pos == nil then
        obj[name] = value
    else
        local chunk = string.sub(name, 1, pos)
        local subthing = obj[chunk]
        if subthing == nil then
            return
        end
        return traverseSet(string.sub(name, pos + 1), subthing, value)
    end
end

local function SuggestTanks()
    local ret = {}
    for id in pairs(State.loadedTanks) do
        table.insert(ret, id)
    end
    return ret
end

function pings.emitSettingsChange(path, value)
    traverseSet(path, settings, value)
end

return command.withPrefix(">", vec(0.3, 0.6, 0.9))
:addHelp()
:append(
    command.literal("focus")
    :append(
        command.str("id")
        :executes(function(ctx)
            State:focusTank(ctx.args.id)
        end)
        :suggests(SuggestTanks)
    )
)
:append(
    command.literal("unfocus")
    :executes(function()
        State:unfocusTank()
    end)
)
:append(
    command.literal("load")
    :executes(function(ctx)
        local id = State:generateId()
        State:loadTank(id)
        ctx:respond("Loaded tank with id " .. id)
    end)
)
:append(
    command.literal("unload")
    :append(
        command.str("id")
        :executes(function(ctx)
            State:unloadTank(ctx.args.id)
        end)
        :suggests(SuggestTanks)
    )
)
:append(
    command.literal("settings")
    :append(
        command.literal("get")
        :append(
            SettingsNode("name")
            :executes(function(ctx)
                local thing = traverseGet(ctx.args.name, settings)
                print(thing)
            end)
        )
    )
    :append(
        command.literal("set")
        :append(
            SettingsNode("name")
            :append(
                command.str("value")
                :suggests(function(ctx)
                    local thing = traverseGet(ctx.args.name, settings)
                    if type(thing) == "boolean" then
                        return {"true", "false"}
                    end
                    return {}
                end)
                :executes(function(ctx)
                    pings.emitSettingsChange(ctx.args.name, load("return " .. ctx.args.value)())
                end)
            )
        )
    )
)
:append(
    command.literal("destroy-crates")
    :executes(function()
        State.crateSpawner.destroyCrates = true
    end)
)