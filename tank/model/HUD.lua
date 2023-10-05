local class       = require("tank.class")
local util        = require("tank.util")
local CustomKeywords = require("tank.model.CustomKeywords")
local TankModel      = require("tank.model.TankModel")
local WorldSlice     = require("tank.model.WorldSlice")
local CrateCompass     = require("tank.model.CrateCompass")
local EffectDisplay    = require("tank.model.EffectDisplay")


---@params {tank:Tank,model:any}
local HUD = class("HUD")



local function PositionSetter(x, y)
    return function(m, arg)
        local size = client.getWindowSize()
        local scale = client.getGuiScale()
        m:setPos(-size.x * x / scale - m:getPivot().x, -size.y * y / scale - m:getPivot().y)
    end
end

local function CustomPosition(m, arg)
    local size = client.getWindowSize()
    local scale = client.getGuiScale()
    local v = util.vecify(arg())
    m:setPos(-size.x * v.x / scale - m:getPivot().x, -size.y * v.y / scale - m:getPivot().y)
end

function HUD:init(opt)
    self.model = opt.model
    self.keywords = CustomKeywords:new(opt.model, util.injectGenericCustomKeywordsRegistry({
        BottomLeftCorner = {},
        BottomCenterCorner = {},
        BottomRightCorner = {},
        CenterLeftCorner = {},
        CenterCenterCorner = {},
        CenterRightCorner = {},
        TopLeftCorner = {},
        TopCenterCorner = {},
        TopRightCorner = {},
        Position = {},
        EffectAnchor = {
            injectedVariables = {
                UPWARDS = vec(0, 0, 0),
                DOWNWARDS = vec(0, 0, 0),
                LEFTWARDS = vec(0, 0, 0),
                RIGHTWARDS = vec(0, 0, 0),

                totalEffects = 0,
                currentEffectIndex = 0
            }
        },
        FlashingHealthBar = {},
        VelocityBar = {},
        DashBar = {},
        DecoAntenna = {},
        RadarBobberBlack = {},
        RadarBobberTransparent = {},

        WeaponIconAnchor = {},
        WeaponStatsAnchor = {},

        SlotTexture = {}
    }, {
        tank = false,
        happenings = false
    }))

    self.tank = opt.tank

    self.oldHealth = math.huge

    self.currentWeapon = nil
    self.currentWeaponIconGroups = {}
    self.currentWeaponStatsGroups = {}

    self.antennaRot = 0
    self.previousAntennaRot = 0
    self.antennaRotMomentum = 0
    self.prevCameraRot = client.getCameraRot().y

    local tankModel = util.deepcopy(models.models.tank.body)
    self.paperModelRoller = util.group()
    opt.model:addChild(self.paperModelRoller)
    self.paperModelRoller:addChild(tankModel)

    self.backgroundPaperModelRoller = util.group()
    opt.model:addChild(self.backgroundPaperModelRoller)

    self.paperModel = TankModel:new{
        tank = self.tank,
        model = tankModel,
        isHUD = true
    }

    self.worldSlice = WorldSlice:new{
        group = self.paperModelRoller
    }

    self.backgroundWorldSlice = WorldSlice:new{
        group = self.backgroundPaperModelRoller,
        onBlock = function(group, block)
            for _, collision in ipairs(block:getOutlineShape()) do
                group:newBlock(util.stringID())
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

    self.currentEffectsGroups = {}
    for model, args in self.keywords:iterate("EffectAnchor") do
        self.currentEffectsGroups[model] = EffectDisplay:new{
            tank = self.tank,
            group = model,
            positioner = function(i, t)
                local l = util.vecify(args{
                    totalEffects = t,
                    currentEffectIndex = i,
                    UPWARDS = vec(0, (i - 1) * 22, 0),
                    DOWNWARDS = vec(0, (i - 1) * -22, 0),
                    LEFTWARDS = vec((i - 1) * 22, 0, 0),
                    RIGHTWARDS = vec((i - 1) * -22, 0, 0)
                })
                return l + model:getPivot()
            end
        }
    end

    for model, args in self.keywords:iterate("SlotTexture") do
        util.addSlotTexture(model)
    end
end

function HUD:beforeTankTick(oldHappenings)
    self.paperModel:beforeTankTick(oldHappenings)
    self.oldHealth = self.tank.health
end
function HUD:afterTankTick(happenings)

    self.paperModel:afterTankTick(happenings)
    if self.currentWeapon ~= self.tank.currentWeapon then
        for group, data in pairs(self.currentWeaponIconGroups) do
            util.callOn(data.lifecycle, "dispose")
            group:removeChild(data.group)
        end

        for group, data in pairs(self.currentWeaponStatsGroups) do
            util.callOn(data.lifecycle, "dispose")
            group:removeChild(data.group)
        end

        for model in self.keywords:iterate("WeaponIconAnchor") do
            local group = util.group()
            local lifecycle = self.tank.currentWeapon:generateIconGraphics(group)
            self.currentWeaponIconGroups[model] = {
                group = group,
                lifecycle = lifecycle
            }
            model:addChild(group)
            group:setPos(model:getPivot())
        end

        for model, args in self.keywords:iterate("WeaponStatsAnchor") do
            local group = util.group()
            local lifecycle = self.tank.currentWeapon:generateHudInfoGraphics(group, util.vecify(args()), self)
            self.currentWeaponStatsGroups[model] = {
                group = group,
                lifecycle = lifecycle
            }
            model:addChild(group)
            group:setPos(model:getPivot())
        end

        self.currentWeapon = self.tank.currentWeapon
    else
        for group, data in pairs(self.currentWeaponIconGroups) do
            util.callOn(data.lifecycle, "tick")
        end
        for group, data in pairs(self.currentWeaponStatsGroups) do
            util.callOn(data.lifecycle, "tick")
        end
    end

    for model, args in self.keywords:iterate("EffectAnchor") do
        self.currentEffectsGroups[model]:tick()
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

    self.keywords:with(util.injectGenericCustomKeywordsExecution({
        BottomLeftCorner = PositionSetter(1, 1),
        BottomCenterCorner = PositionSetter(0.5, 1),
        BottomRightCorner = PositionSetter(0, 1),

        CenterLeftCorner = PositionSetter(1, 0.5),
        CenterCenterCorner = PositionSetter(0.5, 0.5),
        CenterRightCorner = PositionSetter(0, 0.5),

        TopLeftCorner = PositionSetter(1, 0),
        TopCenterCorner = PositionSetter(0.5, 0),
        TopRightCorner = PositionSetter(0, 0),

        Position = CustomPosition,

        FlashingHealthBar = function (m, arg, delta)
            m:setVisible(world.getTime() % 4 > 1 and (self.oldHealth > self.tank.health or self.tank.health < 50))
            m:setScale(self.tank.health, 1, 1)
        end,

        VelocityBar = function (m, arg, delta)
            m:setScale(math.min(math.abs(self.tank.vel:length() * 100), 100), 1, 1)
        end,

        DashBar = function (m, arg, delta)
            m:setScale(self.tank.dash * 100, 1, 1)
        end,

        DecoAntenna = function (m, arg, delta)
            m:setRot(0, 0, math.lerp(self.previousAntennaRot, self.antennaRot, delta))
        end,

        RadarBobberBlack = function (m, arg, delta)
            local s = world.getTime(delta) / 50 % 1
            m:setScale(s, s, 0)
            m:setColor(1 - s, 1 - s, 1 - s)
        end,

        RadarBobberTransparent = function (m, arg, delta)
            local s = world.getTime(delta) / 50 % 1
            m:setScale(s, s, 0)
            m:setOpacity(1 - s)
        end
    }, {
        tank = self.tank,
        happenings = happenings
    }), client.getFrameTime())
end

function HUD:dispose()
    self.model:removeChild(self.paperModelRoller)
    self.model:removeChild(self.backgroundPaperModelRoller)
    for model, display in pairs(self.currentEffectsGroups) do
        display:dispose()
    end
    
    for group, data in pairs(self.currentWeaponIconGroups) do
        util.callOn(data.lifecycle, "dispose")
        group:removeChild(data.group)
    end

    for group, data in pairs(self.currentWeaponStatsGroups) do
        util.callOn(data.lifecycle, "dispose")
        group:removeChild(data.group)
    end
end

return HUD