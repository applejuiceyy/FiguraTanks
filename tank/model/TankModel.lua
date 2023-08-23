local class       = require("tank.class")
local util        = require("tank.util")

local TankModelController = class("TankModelController")

function TankModelController:init(opt)
    self.opt = opt
    self.tank = opt.tank
    self.model = opt.model

    self.oldvel = vec(0, 0, 0)
    self.oldTargetVelocity = vec(0, 0, 0)

    self.soundPower = 1
    self.sounds = {}
    self.stress = 0
    self.oldMonitor = 0

    self.model:setVisible(true)
    self.model.hull:setVisible(true)
    self.model.nozzle:setVisible(true)
    self.model.tracks:setVisible(true)

    self.model.Camera.health.health:setPrimaryRenderType("EMISSIVE_SOLID")
end

function TankModelController:beforeTankTick(oldHappenings)
    self.oldvel = self.tank.vel:copy()
    if oldHappenings ~= nil then
        self.oldTargetVelocity = oldHappenings.targetVelocity
    end
end
function TankModelController:afterTankTick(happenings)
    if not self.opt.isHUD then
        if happenings.targetVelocity:length() < 0.1 then
            self.soundPower = self.soundPower - 0.005
        else
            self.soundPower = self.soundPower + 0.1
        end
        self.soundPower = math.max(0, math.min(self.soundPower, 0.7))
        if self.soundPower > 0 and (not self.tank.dead) then
            self:spawnTankEngineNoises()
        end
    end
end

function TankModelController:render(happenings)
    local delta = client.getFrameTime()
    local lerpAngle = math.lerp(self.tank.oldangle, self.tank.angle, delta)
    local lerpPos = math.lerp(self.tank.oldpos, self.tank.pos, delta)

    local rotatedVelocity = vectors.rotateAroundAxis(
        -math.lerp(self.tank.oldangle, self.tank.angle, delta),
        math.lerp(self.oldTargetVelocity - self.oldvel / 2, happenings.targetVelocity - self.tank.vel / 2, delta),
        vec(0, 1, 0)
    )
    local E = 50

    local treshhold = math.max(6 - happenings.targetVelocity:length() * 20, 1)

    self.model:setMatrix(
        util.transform(
            matrices.yRotation4(180),
            matrices.zRotation4((rotatedVelocity.x + rotatedVelocity.y * 2) * E),
            matrices.xRotation4(rotatedVelocity.z * E * 4 + (self.stress / treshhold - math.pow(self.stress / treshhold, 2))),
            matrices.yRotation4(lerpAngle),
            matrices.translate4((lerpPos + vec(0, math.abs(rotatedVelocity.x) / 4, 0)) * 16)
        )
    )

    self.model.nozzle:setRot(0, self.tank.nozzle.x, 0)
    self.model.nozzle.tube:setRot(0, 0, self.tank.nozzle.y)
    self.model.Camera.health.health:setScale(self.tank.health / 2, 1, 1)

    if not self.opt.isHUD and (not self.tank.dead) then
        self:spawnDragParticles(happenings)
        self:spawnTankIgnitionSound(happenings)
    end
end

function TankModelController:spawnTankIgnitionSound(happenings)
    local time = world.getTime(client.getFrameTime())
    local diff = time - self.oldMonitor
    local currentTreshhold = math.max(6 - happenings.targetVelocity:length() * 20, 1)
    self.stress = self.stress + diff

    if self.stress > currentTreshhold then
        self.stress = self.stress - currentTreshhold
        if self.stress > currentTreshhold then
            self.stress = 0
        end
        table.insert(self.sounds, sounds["entity.iron_golem.repair"]
            :pos(self.tank.pos)
            :volume((0.06 + happenings.targetVelocity:length() / 20) * self.soundPower)
            :pitch(0.17 + happenings.targetVelocity:length() / 100)
            :subtitle()
            :play()
        )

        particles["smoke"]
        :pos(vectors.rotateAroundAxis(self.tank.angle, vec(-0.4, 0.2, -0.3), vec(0, 1, 0)) + self.tank.pos)
        :velocity(vectors.rotateAroundAxis(self.tank.angle, vec(-0.05, 0, 0), vec(0, 1, 0)))
        :scale(0.3, 0.3, 0.3)
        :spawn()
    end

    self.oldMonitor = time
end

function TankModelController:spawnTankEngineNoises()

    
    table.insert(self.sounds, sounds["entity.iron_golem.death"]
        :pos(self.tank.pos)
        :volume(0.01 * self.soundPower)
        :pitch(0.8)
        :subtitle()
        :play()
    )

    while #self.sounds > 8 do
        table.remove(self.sounds, 1):stop()
    end
end

function TankModelController:spawnDragParticles(happenings)
    local wantsdifferential = (self.tank.vel - happenings.targetVelocity):length()
    local offset = vectors.rotateAroundAxis(self.tank.angle, vec(0, 0, 0.5), vec(0, 1, 0))
    local offsetForwards = vectors.rotateAroundAxis(self.tank.angle, vec(0.8, 0, 0), vec(0, 1, 0))
    local pos = self.tank.pos
    if math.random() < wantsdifferential * 10 then
        local blockid = world.getBlockState(pos - vec(0, 0.1, 0)).id
        pcall(function()
            particles:newParticle("minecraft:block " .. blockid, pos + offset + offsetForwards * (math.random() - 0.5), (self.tank.vel - happenings.targetVelocity) * wantsdifferential * 100)
            particles:newParticle("minecraft:block " .. blockid, pos - offset + offsetForwards * (math.random() - 0.5), (self.tank.vel - happenings.targetVelocity) * wantsdifferential * 100)
        end)
    end
end

function TankModelController:dispose()
    --[[models.models.tank:setVisible(false)
    models.models.tank.World.body.hull:setVisible(false)
    models.models.tank.World.body.nozzle:setVisible(false)
    models.models.tank.World.body.tracks:setVisible(false)]]
end

return TankModelController