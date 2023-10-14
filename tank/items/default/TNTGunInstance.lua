local class       = require("tank.class")
local util        = require("tank.util")


---@params TNTGun Tank
local TNTGunInstance = class("TNTGunInstance")

function TNTGunInstance:init(owner, tank)
    self.owner = owner
    self.tank = tank

    self.charge = 0
end

function TNTGunInstance:tick()
    self.charge = self.charge + 0.08
    self.charge = math.min(1, self.charge)
    
    if self.tank.controller:isPressed(self.owner.state.controlRepo.shoot) and self.charge >= 1 then
        self.charge = self.charge - 1
        local vel = vec(2, 0, 0)
        vel = vectors.rotateAroundAxis(-self.tank.nozzle.y, vel, vec(0, 0, 1))
        vel = vectors.rotateAroundAxis(self.tank.nozzle.x + self.tank.angle, vel, vec(0, 1, 0))
        self.owner.shoot(self.tank, self.tank.pos + vec(0, 0.3, 0), vel)
    end
end

function TNTGunInstance:populateSyncQueue(consumer)
    consumer(function()
        if self.tank.currentWeapon == self then
            self.owner.equip(self.tank)
        end
    end)
end

function TNTGunInstance:generateIconGraphics(group)
    group:newBlock("ee"):setBlock("tnt"):setMatrix(util.transform(
        matrices.translate4(-8, -8, -8),
        matrices.rotation4(0, 45, 0),
        matrices.rotation4(-30, 0, 0),
        matrices.scale4(0.6, 0.6, 0.001)
    ))
end

function TNTGunInstance:generateHudInfoGraphics(group, constraints)
    local task = group:newBlock("ee"):setBlock("yellow_concrete"):setScale(constraints.xy_ / 16)
    return {
        tick = function()
            task
            :setPos(0, (constraints.y / 2 - 2), 0)
            :setScale(constraints.x / 16 * self.charge, 4 / 16, 1)
        end
    }
end

function TNTGunInstance:generateTankModelGraphics(tankModel)
    return {
        tick = function()

        end
    }
end

function TNTGunInstance:tankWeaponDispose() end

return TNTGunInstance