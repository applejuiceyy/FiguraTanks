local class       = require("tank.class")

local TankModelController = class("TankModelController")




function TankModelController:init(opt)
    self.tank = opt.tank
    self.tankModel = opt.tankModel

    self.focusingTank = false
    self.thirdPersonCameraRot = vec(0, 0)
end

function TankModelController:beforeTankTick()
    self.oldvel = self.tank.vel
end
function TankModelController:afterTankTick()
    
end

function TankModelController:offsetThirdPersonCamera(x, y)
    if host:getScreen() == nil and not action_wheel:isEnabled() then
        self.thirdPersonCameraRot = self.thirdPersonCameraRot + vec(y, x) / 3
        self.thirdPersonCameraRot.x = math.min(self.thirdPersonCameraRot.x, 90)
        return self.focusingTank
    end
end

function TankModelController:render()
    local delta = client.getFrameTime()
    local lerpAngle = math.lerp(self.tank.oldangle, self.tank.angle, delta)
    local lerpPos = math.lerp(self.tank.oldpos, self.tank.pos, delta)

    if renderer:isFirstPerson() and self.focusingTank then
        renderer:offsetCameraRot(0, 0, 0)
        renderer:setCameraPivot(lerpPos + vec(0, 0.3, 0) + vectors.rotateAroundAxis(lerpAngle, vec(-0.15, 0.35, 0), vec(0, 1, 0)))
        renderer:setCameraRot(
            math.lerp(self.tank.oldnozzle.y, self.tank.nozzle.y, delta),
            math.lerp(-self.tank.oldnozzle.x, -self.tank.nozzle.x, delta) - lerpAngle - 90, 0
        )
    elseif self.focusingTank then
        renderer:setCameraPivot(lerpPos + vec(0, 0.5, 0))
        renderer:setCameraRot(self.thirdPersonCameraRot.xy_ + vec(0, -lerpAngle, 0))
    end

    local e = renderer:isFirstPerson() and self.focusingTank
    self.tankModel.focused = e
end

function TankModelController:dispose()
    self:unfocusTank()
    renderer:setCameraRot(nil, nil, nil)
    renderer:setCameraPivot(nil, nil, nil)
    renderer:setCameraRot(nil, nil, nil)
end

function TankModelController:unfocusTank()
    renderer:offsetCameraRot(0, 0, 0)
    renderer:setCameraPivot()
    self.focusingTank = false
    renderer:setCameraRot(nil, nil, nil)
end

function TankModelController:focusTank()
    self.focusingTank = true
    --renderer.renderHUD = false
end

return TankModelController