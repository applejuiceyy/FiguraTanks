local class       = require("tank.class")
local util        = require("tank.util.util")

---@params FlameThrower Tank number number
local FlameThrowerEffect = class("FlameThrowerEffect")


FlameThrowerEffect.isWeapon = true

function FlameThrowerEffect:init(owner, tank, charge, id)
    self.owner = owner
    self.tank = tank
    self.id = id

    self.charge = charge
    self.flaming = false
end

function FlameThrowerEffect:tick()
    if self.tank.dead then
        if self.flaming then
            self.flaming = false
            self.owner.setFlaming(self.tank, false, self.id)
        end
    else
        if self.tank.controller:isPressed(self.owner.state.controlRepo.shoot) ~= self.flaming then
            self.flaming = self.tank.controller:isPressed(self.owner.state.controlRepo.shoot)
            self.owner.setFlaming(self.tank, self.flaming, self.id)
        end
    end



    if self.flaming then
        self.charge = self.charge - 0.01

        if self.charge <= 0 then
            self.owner.setFlaming(self.tank, false)
            self.owner.state.itemManagers["default:tntgun"]:apply(self.tank)
        end

        local vel = vec(0.02, 0, 0)
        vel = vectors.rotateAroundAxis(-self.tank.nozzle.y, vel, vec(0, 0, 1))
        vel = vectors.rotateAroundAxis(self.tank.nozzle.x + self.tank.angle, vel, vec(0, 1, 0))
        self.tank.vel = self.tank.vel - vel
    end
end


function FlameThrowerEffect:populateSyncQueue(consumer)
    consumer(function()
        if self.tank:hasEffect(self.id) then
            self.owner.equip(self.tank, self.charge, self.id)
        end
    end)
end

function FlameThrowerEffect:generateIconGraphics(group)
    return self.owner:generateIconGraphics(group)
end

function FlameThrowerEffect:shouldBeKept()
    return true
end

function FlameThrowerEffect:specifyHUD(hud)
    return {
        showsCustomInformation = function()
            return true
        end,

        icon = function(group)
            return self.owner:generateIconGraphics(group)
        end,

        information = function(group, constraints)
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
    }

end

function FlameThrowerEffect:specifyModel(tankModel)
    return {
        tick = function()
            if self.flaming and (not tankModel.isHUD) then
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

                sounds:playSound("block.fire.ambient", self.tank.pos)
            end
        end
    }
end

function FlameThrowerEffect:dispose()
    self.owner.flamingTanks[self.tank] = nil
end

function FlameThrowerEffect:tankFetchControlsInvoked(a, b, c)
    return a * 0.9, b * 0.9, c * 0.9
end


return FlameThrowerEffect