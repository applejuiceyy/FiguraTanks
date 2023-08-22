local class    = require("tank/class")


local Recorder = class("Recorder")

function Recorder:init()
    self.unloads = {}
end

function Recorder:record(unload)
    table.insert(self.unloads, unload)
end

function Recorder:perform()
    for _, v in ipairs(self.unloads) do
        v()
    end
    self.unloads = {}
end

return Recorder