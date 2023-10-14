local class       = require("tank.class")

---@params 
local ControlRepo = class("ControlRepo")


local function unnocupied(t, a, b, ...)
    if b == nil then
        return a
    end
    if t[a] == nil then
        return a
    end
    return unnocupied(t, b, ...)
end

function ControlRepo:init()
    ---@type {key:string,name:string,sync:boolean}[]
    self.availableKeys = {}
    self.forKeybind = {}

    self.forwards = self:defineKey("forwards", true, "key.keyboard.w")
    self.backwards = self:defineKey("backwards", true, "key.keyboard.s")
    self.left = self:defineKey("left", true, "key.keyboard.a")
    self.right = self:defineKey("right", true, "key.keyboard.d")

    self.shoot = self:defineKey("shoot", false, "key.keyboard.space")

    self.nozzleup = self:defineKey("nozzleup", true, "key.keyboard.up")
    self.nozzledown = self:defineKey("nozzledown", true, "key.keyboard.down")
    self.nozzleleft = self:defineKey("nozzleleft", true, "key.keyboard.left")
    self.nozzleright = self:defineKey("nozzleright", true, "key.keyboard.right")

    self.dash = self:defineKey("dash", true, "key.keyboard.left.control")
end

function ControlRepo:defineKey(name, sync, ...)
    local key = unnocupied(self.forKeybind, ...)
    local token = {}
    self.forKeybind[key] = true
    self.availableKeys[token] = {
        key = key,
        name = name,
        sync = sync
    }
    return token
end

return ControlRepo