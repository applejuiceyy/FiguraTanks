local class       = require("tank.class")
local util        = require("tank.util")
local CustomKeywords = require("tank.model.CustomKeywords")
local TankModel      = require("tank.model.TankModel")
local WorldSlice     = require("tank.model.WorldSlice")
local CrateCompass     = require("tank.model.CrateCompass")

local HUD = class("HUD")



local function PositionSetter(x, y)
    return function(_, m)
        local size = client.getWindowSize()
        local scale = client.getGuiScale()
        m:setPos(-size.x * x / scale - m:getPivot().x, -size.y * y / scale - m:getPivot().y)
    end
end

function HUD:init(opt)
    self.tank = opt.tank

    self.oldHealth = math.huge

    self.currentWeapon = nil
    self.currentWeaponGroups = {}

    self.antennaRot = 0
    self.previousAntennaRot = 0
    self.antennaRotMomentum = 0
    self.prevCameraRot = client.getCameraRot().y

    local tankModel = util.deepcopy(models.models.tank.body)
    self.paperModelRoller = util.group()
    models.models.hud:addChild(self.paperModelRoller)
    self.paperModelRoller:addChild(tankModel)

    self.backgroundPaperModelRoller = util.group()
    models.models.hud:addChild(self.backgroundPaperModelRoller)

    self.paperModel = TankModel:new{
        tank = self.tank,
        model = tankModel,
        isHud = true
    }

    self.worldSlice = WorldSlice:new{
        group = self.paperModelRoller
    }

    self.backgroundWorldSlice = WorldSlice:new{
        group = self.backgroundPaperModelRoller,
        onBlock = function(group, block)
            for _, collision in ipairs(block:getOutlineShape()) do
                group:newBlock("gen-" .. math.random())
                    :block("black_concrete")
                    :pos((collision[1] + block:getPos()) * 16 - vec(2, 2, 2))
                    :scale(collision[2] - collision[1] + vec(4, 4, 4) / 16)
            end
        end
    }

    self.compassGroup = util.group()
    self.paperModelRoller:addChild(self.compassGroup)
    
    self.crateCompess = CrateCompass:new{
        group = self.compassGroup
    }

    self.previousPaperModelCurrentRotation = 0
    self.startShiftAnimationPaperModelCurrentRotation = 0
    self.paperModelCurrentRotation = 0
    self.paperModelCurrentRotationBelief = 0

    self.keywords = CustomKeywords:new(models.models.hud, {
        BottomLeftCorner = PositionSetter(1, 1),
        BottomCenterCorner = PositionSetter(0.5, 1),
        BottomRightCorner = PositionSetter(0, 1),

        CenterLeftCorner = PositionSetter(1, 0.5),
        CenterCenterCorner = PositionSetter(0.5, 0.5),
        CenterRightCorner = PositionSetter(0, 0.5),

        TopLeftCorner = PositionSetter(1, 0),
        TopCenterCorner = PositionSetter(0.5, 0),
        TopRightCorner = PositionSetter(0, 0),

        HealthBar = function (delta, m)
            m:setScale(self.tank.health, 1, 1)
        end,

        FlashingHealthBar = function (delta, m)
            m:setVisible(world.getTime() % 4 > 1 and (self.oldHealth > self.tank.health or self.tank.health < 50))
            m:setScale(self.tank.health, 1, 1)
        end,

        VelocityBar = function (delta, m)
            m:setScale(math.min(math.abs(self.tank.vel:length() * 100), 100), 1, 1)
        end,

        DashBar = function (delta, m)
            m:setScale(self.tank.dash * 100, 1, 1)
        end,

        DecoAntenna = function (delta, m)
            m:setRot(0, 0, math.lerp(self.previousAntennaRot, self.antennaRot, delta))
        end,

        RadarBobberBlack = function (delta, m)
            local s = world.getTime(delta) / 50 % 1
            m:setScale(s, s, 0)
            m:setColor(1 - s, 1 - s, 1 - s)
        end,

        RadarBobberTransparent = function (delta, m)
            local s = world.getTime(delta) / 50 % 1
            m:setScale(s, s, 0)
            m:setOpacity(1 - s)
        end,

        WeaponIcon = function() end
    })
end

function HUD:beforeTankTick(oldHappenings)
    self.paperModel:beforeTankTick(oldHappenings)
    self.oldHealth = self.tank.health
end
function HUD:afterTankTick(happenings)
    self.paperModel:afterTankTick(happenings)
    if self.currentWeapon ~= self.tank.currentWeapon then
        for group in pairs(self.currentWeaponGroups) do
            group.parent:removeChild(group)
        end

        for model in self.keywords:iterate("WeaponIcon") do
            self.currentWeaponGroup = self.tank.currentWeapon:generateHudGraphics()
            model:addChild(self.currentWeaponGroup)
        end
    end


    local camera = client.getCameraRot().y
    local movement = math.shortAngle(camera, self.prevCameraRot) / 3
    self.prevCameraRot = camera

    self.antennaRotMomentum = self.antennaRotMomentum + movement
    self.antennaRotMomentum = self.antennaRotMomentum - (self.antennaRot / 10)
    self.antennaRotMomentum = self.antennaRotMomentum * 0.7

    self.previousAntennaRot = self.antennaRot
    self.antennaRot = self.antennaRot + self.antennaRotMomentum

    local bestYaw = self.worldSlice:update(self.tank.pos)
    self.backgroundWorldSlice:update(self.tank.pos)

    local downsampled = math.floor(-bestYaw / 90 + 0.5) * 90 - 45

    if self.paperModelCurrentRotation ~= downsampled then
        self.paperModelCurrentRotationBelief = self.paperModelCurrentRotationBelief - 1
        if self.tank.vel:length() < 0.05 then
            self.paperModelCurrentRotationBelief = self.paperModelCurrentRotationBelief - 5
        end
        if self.paperModelCurrentRotationBelief <= 0 then
            self.previousPaperModelCurrentRotation = self.paperModelCurrentRotation
            self.paperModelCurrentRotation = downsampled
            self.startShiftAnimationPaperModelCurrentRotation = world.getTime()
            self.paperModelCurrentRotationBelief = 100
        end
    else
        self.paperModelCurrentRotationBelief = 100
    end
end

function HUD:render(happenings)
    self.paperModel:render(happenings)
    local size = client.getWindowSize()
    local scale = client.getGuiScale()
    local lerpedPos = math.lerp(self.tank.oldpos, self.tank.pos, client.getFrameTime())
    -- -math.lerp(self.tank.oldangle, self.tank.angle, client.getFrameTime())
    local rotateBy = math.lerpAngle(self.previousPaperModelCurrentRotation, self.paperModelCurrentRotation, 1 - math.pow(0.9, world.getTime(client.getFrameTime()) - self.startShiftAnimationPaperModelCurrentRotation))
    self.paperModelRoller:setMatrix(
        util.transform(
            matrices.translate4(-lerpedPos * 16),
            matrices.rotation4(0, rotateBy, 0),
            matrices.rotation4(-40, 0, 0),
            matrices.scale4(0.5, 0.5, 0.01),
            matrices.translate4(vec(-size.x * 0.5 / scale, -size.y * 0.8 / scale, 0))
        )
    )
    self.backgroundPaperModelRoller:setMatrix(
        util.transform(
            matrices.translate4(-lerpedPos * 16),
            matrices.rotation4(0, rotateBy, 0),
            matrices.rotation4(-40, 0, 0),
            matrices.scale4(0.5, 0.5, 0.01),
            matrices.translate4(vec(-size.x * 0.5 / scale, -size.y * 0.8 / scale, 1))
        )
    )
    self.crateCompess:update(lerpedPos)
    --[[self.compassGroup:setMatrix(
        matrices.translate4(math.lerp(self.tank.oldpos, self.tank.pos, client.getFrameTime()) * 16)
    )]]

    self.keywords:render(client.getFrameTime())
end

function HUD:dispose()

end

return HUD