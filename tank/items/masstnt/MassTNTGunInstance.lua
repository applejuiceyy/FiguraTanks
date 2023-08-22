local class       = require("tank.class")
local util        = require("tank.util")

local MassTNTGunInstance = class("MassTNTGunInstance")

function MassTNTGunInstance:init(owner, tank)
    self.owner = owner
    self.tank = tank

    self.charge = 0
end

function MassTNTGunInstance:tick()
    self.charge = self.charge + 0.08
    self.charge = math.min(1, self.charge)
    
    if self.tank.controller.shoot and self.charge >= 1 then
        self.charge = self.charge - 1
        self.owner:shoot(self.tank)
    end
end

function MassTNTGunInstance:generateHudGraphics()
    local group = util.group()
    local rt = group:newBlock("e")
    rt:setBlock("tnt")
    rt:setMatrix(util.transform(
        matrices.rotation4(0, 45, 0),
        matrices.rotation4(-30, 0, 0),
        matrices.scale4(1, 1, 0.01)
    ))
    return group
end

function MassTNTGunInstance:generateWorldGraphics()
    
end


return MassTNTGunInstance