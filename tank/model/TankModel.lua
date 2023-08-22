local class       = require("tank.class")
local util        = require("tank.util")

local TankModelController = class("TankModelController")

function TankModelController:init(opt)
    self.opt = opt
    self.tank = opt.tank
    self.model = opt.model

    self.oldvel = vec(0, 0, 0)
    self.oldTargetVelocity = vec(0, 0, 0)

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

    self.model:setMatrix(
        util.transform(
            matrices.yRotation4(180),
            matrices.zRotation4((rotatedVelocity.x + rotatedVelocity.y * 2) * E),
            matrices.xRotation4(rotatedVelocity.z * E * 4),
            matrices.yRotation4(lerpAngle),
            matrices.translate4((lerpPos + vec(0, math.abs(rotatedVelocity.x) / 4, 0)) * 16)
        )
    )

    self.model.nozzle:setRot(0, self.tank.nozzle.x, 0)
    self.model.nozzle.tube:setRot(0, 0, self.tank.nozzle.y)
    self.model.Camera.health.health:setScale(self.tank.health / 2, 1, 1)

    if self.opt.spawnParticles == nil or self.opt.spawnParticles then
        self:spawnDragParticles(happenings)
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