local controls = {
    forwards = false,
    backwards = false,
    left = false,
    right = false,
    shoot = false,
    nozzleup = false,
    nozzledown = false,
    nozzleleft = false,
    nozzleright = false,
    dash = false,
    activated = false
}

local keybingToPing = {
    forwards = "f",
    backwards = "b",
    left = "l",
    right = "r",
    shoot = "s",
    nozzleup = "u",
    nozzledown = "j",
    nozzleleft = "h",
    nozzleright = "k",
    dash = "d"
}

local pingToKeybind = {}

for i, v in pairs(keybingToPing) do
    pingToKeybind[v] = i
end

local createdKeybinds = {}

function pings.control(buttons)
    for i = 1, math.floor(string.len(buttons) / 2) do
        local key = string.sub(buttons, i * 2 - 1, i * 2 - 1)
        local value = string.sub(buttons, i * 2, i * 2) == "1"
        controls[pingToKeybind[key]] = value
    end
end

if host:isHost() then
    local b = {}
    local sendStuff = false

    local function bind(keybindName, keybindKey, func)
        if func == nil then
            func = function (key, val)
                if controls[key] ~= val then
                    b[key] = val
                    sendStuff = true
                else
                    b[key] = nil
                    sendStuff = false
                    -- set to true if there's keys
                    for _, _ in pairs(b) do sendStuff = true break end
                end
                return controls.activated
            end
        end
        local k = keybinds:newKeybind(keybindName, keybindKey)

        k.press = function ()
            if controls.activated then
                return func(keybindName, true)
            end
        end

        k.release = function ()
            if controls.activated then
                return func(keybindName, false)
            end
        end

        createdKeybinds[keybindName] = k

        return k
    end

    bind("forwards", "key.keyboard.w")
    bind("backwards", "key.keyboard.s")
    bind("left", "key.keyboard.a")
    bind("right", "key.keyboard.d")
    bind("shoot", "key.keyboard.space", function (_ ,val)
        controls.shoot = val
        return controls.activated
    end)

    bind("nozzleup", "key.keyboard.up")
    bind("nozzledown", "key.keyboard.down")
    bind("nozzleleft", "key.keyboard.left")
    bind("nozzleright", "key.keyboard.right")

    bind("dash", "key.keyboard.left.control")

    local m1 = bind("leftmouse", "key.mouse.left", function() return controls.activated and host:getScreen() == nil end)
    local m2 = bind("rightmouse", "key.mouse.right", function() return controls.activated and host:getScreen() == nil end)

    events.TICK:register(function()
        if sendStuff then
            local send = {}
            for i, v in pairs(b) do
                table.insert(send, keybingToPing[i])
                table.insert(send, v and "1" or "0")
            end
            pings.control(table.concat(send, ""))
            b = {}
            sendStuff = false
        end
    end)
end

controls.activate = function()
    controls.activated = true
end

controls.deactivate = function()
    controls.activated = false
    for n, v in pairs(createdKeybinds) do
        if controls[n] then
            local name = "set" .. string.upper(string.sub(n, 1, 1)) .. string.sub(n, 2)
            if controls[name] then
                controls[name](false)
            else
                controls[n] = false
            end
        end
    end
end

return controls