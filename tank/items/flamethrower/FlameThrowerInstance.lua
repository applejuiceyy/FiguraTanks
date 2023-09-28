local class       = require("tank.class")
local util        = require("tank.util")

local FlameThrowerInstance = class("FlameThrowerInstance")

function FlameThrowerInstance:init(owner, tank, bulletsRemaining)
    self.owner = owner
    self.tank = tank

    self.charge = 1
    self.flaming = false
end

function FlameThrowerInstance:tick()
    if self.tank.controller.shoot ~= self.flaming then
        self.flaming = self.tank.controller.shoot
        self.owner.pings.setFlaming(self.flaming)
    end
    if self.flaming then
        self.charge = self.charge - 0.005

        if self.charge <= 0 then
            self.owner.pings.setFlaming(false)
            self.owner.state.itemManagers["default:tntgun"]:apply(self.tank)
        end
    end
end


function FlameThrowerInstance:populateSyncQueue(consumer)
    consumer(function()
        if self.tank.currentWeapon == self then
            self.owner.pings.equip(self.charge)
        end
    end)
end

function FlameThrowerInstance:generateIconGraphics(group)
    return self.owner:generateIconGraphics(group)
end

function FlameThrowerInstance:generateHudInfoGraphics(group, constraints, hud)
    local tasks = {}

    for x = 0, constraints.x, 1 do
        local id = util.stringID()
        table.insert(
            tasks, {task = group:newBlock(id):setBlock("red_concrete"), id = id}
        )
    end

    return {
        tick = function()
            local waving = self.charge - math.pow(self.charge, 2)
            
            local center = #tasks / 2


            for i, thing in pairs(tasks) do
                local g = center - i

                local d = math.cos((world.getTime() + i) / 10) + math.cos((-world.getTime() + i) / 8) + math.cos((world.getTime() + i) / 20)
                local height = (self.charge + d * waving / 5)
                height = height + (g * hud.antennaRot) / #tasks / constraints.y
                
                thing.task
                :setPos(i, 0, 0)
                :setScale(1 / 16, math.min(1, math.max(height, 0)) / 16 * constraints.y, 1)
            end

        end
    }
end

function FlameThrowerInstance:generateTankModelGraphics(tankModel)
    return {
        tick = function()
            if self.flaming then
                if (not tankModel.isHUD) then
                    local initial = util.pitchYawToUnitVector(self.tank.nozzle + vec(self.tank.angle, 0))

                    for i = 0, 5 do
                        local randomned = initial + (util.unitRandom() - vec(0.5, 0.5, 0.5)) * vec(1, 0.5, 1)
                        particles["flame"]
                        :pos(self.tank.pos + vec(0, 0.3, 0) + randomned * 2)
                        :velocity(randomned)
                        :lifetime(10)
                        :scale(3)
                        :spawn()
                    end
                end

                sounds:playSound("block.fire.ambient", self.tank.pos)
            end


        end
    }
end

function FlameThrowerInstance:tankWeaponDispose()
    self.owner.flamingTanks[self.tank] = nil
end

return FlameThrowerInstance