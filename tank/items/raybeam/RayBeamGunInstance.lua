local class       = require("tank.class")
local util        = require("tank.util")

local RayBeamGunInstance = class("RayBeamGunInstance")

function RayBeamGunInstance:init(owner, tank, bulletsRemaining)
    self.owner = owner
    self.tank = tank

    self.charge = 0
    self.charged = false
    self.isShooting = false
    self.bulletsRemaining = bulletsRemaining
end

function RayBeamGunInstance:tick()
    if self.isShooting then
        self.charge = self.charge - 0.02
        self.charge = math.max(0, self.charge)
        sounds["block.respawn_anchor.set_spawn"]
        :pos(self.tank.pos)
        :volume(0.4)
        :pitch(2 - self.charge)
        :subtitle("Ray beam discharges")
        :play()

        self.tank.vel = self.tank.vel - util.pitchYawToUnitVector(self.tank.nozzle + vec(self.tank.angle, 0)) / 200

        if self.charge == 0 then
            if self.bulletsRemaining <= 0 then
                self.owner.state.itemManagers["default:tntgun"]:apply(self.tank)
            else
                self.isShooting = false
            end
            
            self.owner:shoot(self.tank)
        end
        return
    end

    self.charge = self.charge + 0.01
    self.charge = math.min(1, self.charge)

    if self.charge >= 1 then
        if not self.charged then
            self.charged = true
            sounds:playSound("block.beacon.activate", self.tank.pos)
        end
    else
        self.charged = false
    end
    
    if self.tank.controller.shoot and self.charge >= 1 then
        self.owner:startShooting(self.tank)
    end
end


function RayBeamGunInstance:startShooting()
    self.bulletsRemaining = self.bulletsRemaining - 1
    self.isShooting = true
end

function RayBeamGunInstance:populateSyncQueue(consumer)
    consumer(function()
        if self.tank.currentWeapon == self then
            self.owner.pings.equip(self.bulletsRemaining)
        end
    end)
end

function RayBeamGunInstance:generateIconGraphics(group)
    return self.owner:generateIconGraphics(group)
end

function RayBeamGunInstance:generateHudInfoGraphics(group, constraints)
    local charge = group:newBlock("ee"):setBlock("yellow_concrete")
    local text = group:newText("e")
    return {
        tick = function()
            local w = self.charge
            if self.isShooting then
                w = 1 - math.pow(1 - self.charge, 3)
            end
            charge
            :setPos(0, (constraints.y / 2 - 2), 0)
            :setScale(constraints.x / 16 * w, 4 / 16, 1)

            local t = string.format('[{"text":%q, "color":"#ff4422"}, {"text":" bullets", "color":"#000000"}]', self.bulletsRemaining)

            text
            :setText(t)
            :setPos(client.getTextWidth(t), 9, 0)
        end
    }
end

function RayBeamGunInstance:generateTankModelGraphics(tankModel)
    return {
        tick = function()
            if (not tankModel.isHUD) and self.isShooting then
                particles["firework"]
                :pos(vectors.rotateAroundAxis(math.random() * 360, vec(1, 0, 0), vec(0, 1, 0)) + self.tank.pos)
                :spawn()

                local initial = util.pitchYawToUnitVector(self.tank.nozzle + vec(self.tank.angle, 0)) * (2 - self.charge)
                local inverse = 1 - self.charge
                local range = inverse - math.pow(inverse, 3)
                for i = 0, 20 - self.charge * 20 do
                    particles["firework"]
                    :pos(self.tank.pos + vec(0, 0.3, 0))
                    :velocity(initial + (util.unitRandom() - 0.5) * range * 4)
                    :lifetime(10)
                    :spawn()
                end
            end
        end
    }
end

function RayBeamGunInstance:tankFetchControlsInvoked(a, b, c)
    if self.isShooting then
        return a * 0.2, b * 0.2, c * 0.2
    end
    return a, b, c
end

function RayBeamGunInstance:tankWeaponDispose() end

return RayBeamGunInstance