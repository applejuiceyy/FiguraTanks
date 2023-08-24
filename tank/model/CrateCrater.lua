local class       = require("tank.class")
local util        = require("tank.util")

local CrateCompass = class("CrateCompass")

function CrateCompass:init(opt)
    self.group = opt.group

    self.fractures = {}

    for i = 0, 2 do
        self:populateFractures(vec(0, 0, 0), math.random() * 360, 0)
    end
end

function CrateCompass:populateFractures(pos, angle, depth)
    local id = "gen-" .. math.random()
    local task = self.group:newBlock(id):block("black_concrete")
    local scale = math.random() * 0.2 + 0.5
    table.insert(self.fractures, 1, {
        angle = angle,
        pos = pos,
        scale = scale,
        id = id,
        task = task
    })
    self:applyMatrix(self.fractures[1])

    local origin = vectors.rotateAroundAxis(angle, vec(scale, 0, 0), vec(0, 1, 0)) + pos
    for i = 0, 3 do
        if math.random() * 3 > depth then
            self:populateFractures(origin, angle + (math.random() * 100 - 50), depth + 1)
        end
    end
end

function CrateCompass:applyMatrix(obj)
    obj.task:matrix(
        util.transform(
            matrices.translate4(0, 0, -8),
            matrices.scale4(obj.scale, 0.01, 0.01),
            matrices.rotation4(0, obj.angle, 0),
            matrices.translate4(obj.pos * 16)
        )
    )
end

function CrateCompass:tick()
    if #self.fractures == 0 then
        return false
    end
    local obj = self.fractures[1]
    obj.scale = obj.scale - 0.1
    self:applyMatrix(obj)
    if obj.scale <= 0 then
        self.group:removeTask(obj.id)
        table.remove(self.fractures, 1)
    end
    return true
end


return CrateCompass