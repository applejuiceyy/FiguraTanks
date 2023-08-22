local command        = require("tank/command/commands/main")
local State          = require("tank.state.State")

return command.withPrefix(">", vec(0.3, 0.6, 0.9))
:addHelp()
:append(
    command.literal("focus")
    :executes(function()
        State:focusTank()
    end)
)
:append(
    command.literal("unfocus")
    :executes(function()
        State:unfocusTank()
    end)
)
:append(
    command.literal("load")
    :executes(function()
        State:loadTank()
    end)
)
:append(
    command.literal("unload")
    :executes(function()
        State:unloadTank()
    end)
)