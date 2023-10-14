local class       = require("tank.class")


---@params KeyboardRepo Control
local Keyboard = class("Keyboard")
---@params PingChannel ControlRepo
local KeyboardRepo = class("KeyboardRepo")


function KeyboardRepo:init(pingChannel, controlRepo)
    local proto = {}

    self.listeningKeyboards = {}
    self.toTokens = {}

    for token, data in pairs(controlRepo.availableKeys) do
        

        local key = keybinds:newKeybind(data.name, data.key)
        self.toTokens[key] = token
        if data.sync then
            proto["keyboardOn" .. string.gsub(data.key, "%.", "")] = {
                arguments = {"default"},
                func = function()
                    for keyboard in pairs(self.listeningKeyboards) do
                        keyboard.control:click(self.toTokens[key])
                        keyboard.control:press(self.toTokens[key])
                        keyboard.toRelease[self.toTokens[key]] = true
                    end
                end
            }

            proto["keyboardOff" .. string.gsub(data.key, "%.", "")] = {
                arguments = {"default"},
                func = function()
                    for keyboard in pairs(self.listeningKeyboards) do
                        keyboard.control:release(self.toTokens[key])
                        keyboard.toRelease[self.toTokens[key]] = nil
                    end
                end
            }

            key.press = function()
                if next(self.listeningKeyboards) ~= nil then
                    self.pings["keyboardOn" .. string.gsub(data.key, "%.", "")]()
                    return true
                end
            end
            key.release = function()
                if next(self.listeningKeyboards) ~= nil then
                    self.pings["keyboardOff" .. string.gsub(data.key, "%.", "")]()
                end
            end
        else
            key.press = function()
                local cancel = false
                for keyboard in pairs(self.listeningKeyboards) do
                    keyboard.control:click(self.toTokens[key])
                    keyboard.control:press(self.toTokens[key])
                    keyboard.toRelease[self.toTokens[key]] = true
                    cancel = true
                end
                return cancel
            end
            key.release = function()
                for keyboard in pairs(self.listeningKeyboards) do
                    keyboard.control:release(self.toTokens[key])
                    keyboard.toRelease[self.toTokens[key]] = nil
                end
            end
        end
    end

    keybinds:newKeybind("leftmouse", "key.mouse.left").press = function ()
        return next(self.listeningKeyboards) ~= nil and host:getScreen() == nil
    end
    keybinds:newKeybind("rightmouse", "key.mouse.right").press = function ()
        return next(self.listeningKeyboards) ~= nil and host:getScreen() == nil
    end

    self.pings = pingChannel:registerAll(proto)
end

function KeyboardRepo:create(control)
    return Keyboard:new(self, control)
end

function Keyboard:init(repo, control)
    self.repo = repo
    self.control = control
    self.toRelease = {}
end

function Keyboard:listen()
    self.repo.listeningKeyboards[self] = true
end

function Keyboard:unlisten()
    for token in pairs(self.toRelease) do
        self.control:release(token)
    end
    self.repo.listeningKeyboards[self] = nil
    self.toRelease = {}
end

return KeyboardRepo