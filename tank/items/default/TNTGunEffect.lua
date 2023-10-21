local class       = require("tank.class")
local util        = require("tank.util.util")


---@params TNTGun Tank integer
local TNTGunEffect = class("TNTGunEffect")

TNTGunEffect.isWeapon = true

function TNTGunEffect:init(owner, tank, id)
    self.owner = owner
    self.tank = tank
    self.id = id

    self.charge = 0
end

function TNTGunEffect:tick()
    self.charge = self.charge + 0.08
    self.charge = math.min(1, self.charge)
    
    if self.tank.health > 0 and self.tank.controller:isPressed(self.owner.state.controlRepo.shoot) and self.charge >= 1 then
        self.charge = self.charge - 1
        local vel = vec(2, 0, 0)
        vel = vectors.rotateAroundAxis(-self.tank.nozzle.y, vel, vec(0, 0, 1))
        vel = vectors.rotateAroundAxis(self.tank.nozzle.x + self.tank.angle, vel, vec(0, 1, 0))
        self.owner.shoot(self.tank, self.tank.pos + vec(0, 0.3, 0), vel)
    end
end

function TNTGunEffect:shouldBeKept()
    return true
end

function TNTGunEffect:populateSyncQueue(consumer)
    consumer(function()
        if self.tank:hasEffect(self.id) then
            self.owner.equip(self.tank, self.id)
        end
    end)
end

function TNTGunEffect:generateIconGraphics(group)
    return self.owner:generateIconGraphics(group)
end

function TNTGunEffect:specifyHUD(hud)
    return {
        showsCustomInformation = function()
            return true
        end,

        icon = function(group)
            return self.owner:generateIconGraphics(group)
        end,

        information = function(group, constraints)
            local task = group:newBlock("ee"):setBlock("yellow_concrete"):setScale(constraints.xy_ / 16)
            return {
                tick = function()
                    task
                    :setPos(0, (constraints.y / 2 - 2), 0)
                    :setScale(constraints.x / 16 * self.charge, 4 / 16, 1)
                end
            }
        end
    }
end

return TNTGunEffect