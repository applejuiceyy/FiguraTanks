local class       = require("tank.class")
local util        = require("tank.util.util")
local CustomKeywords = require("tank.model.CustomKeywords")
local TankModel      = require("tank.model.TankModel")
local WorldSlice     = require("tank.model.WorldSlice")

---@params 
local UserTablet = class("UserTablet")

function UserTablet:init()
    self.currentlyFocusedTank = nil
    self.paperModelRoller = nil
    self.paperModel = nil
    self.worldSlice = nil

    self.equipped = false
end

function UserTablet:disband()
    models.models.tablet.Tablet:removeChild(self.paperModelRoller)
    models.models.tablet:setVisible(false)
    vanilla_model.HEAD:setVisible(true)
    vanilla_model.HELMET_HEAD:setVisible(true)
    vanilla_model.HAT:setVisible(true)
    vanilla_model.HELMET_HAT:setVisible(true)
    vanilla_model.LEFT_ARM:setVisible(true)
    vanilla_model.RIGHT_ARM:setVisible(true)
    vanilla_model.HELD_ITEMS:setVisible(true)
    self.currentlyFocusedTank = nil
    self.paperModelRoller = nil
    self.paperModel = nil
    self.worldSlice = nil
end

function UserTablet:setFocus(tank)
    if tank ~= self.currentlyFocusedTank then
        if self.currentlyFocusedTank ~= nil then
            self:disband()
        end
        self.currentlyFocusedTank = tank

        if tank == nil then
            return
        end

        local tankModel = util.deepcopy(models.models.tank.body)
        tankModel:setLight(15,15)
    
        self.paperModelRoller = util.group()
    
        self.paperModelRoller:addChild(tankModel)
    
        self.paperModel = TankModel:new{
            tank = tank,
            model = tankModel,
            isHUD = true
        }
    
        self.worldSlice = WorldSlice:new{
            group = self.paperModelRoller,
            onTask = function(e) e:setLight(15,15) end
        }

        models.models.tablet.Tablet:addChild(self.paperModelRoller)
        models.models.tablet:setVisible(true)
        vanilla_model.HEAD:setVisible(false)
        vanilla_model.HELMET_HEAD:setVisible(false)
        vanilla_model.HAT:setVisible(false)
        vanilla_model.HELMET_HAT:setVisible(false)
        vanilla_model.LEFT_ARM:setVisible(false)
        vanilla_model.RIGHT_ARM:setVisible(false)
        vanilla_model.HELD_ITEMS:setVisible(false)
    end
end

function UserTablet:beforeTankTick(oldHappenings)
    self.paperModel:beforeTankTick(oldHappenings)
end
function UserTablet:afterTankTick(happenings)
    self.paperModel:afterTankTick(happenings)
    self.worldSlice:update(self.currentlyFocusedTank.pos)
end

function UserTablet:render(happenings)
    self.paperModel:render(happenings)
    self.paperModelRoller:setMatrix(
        util.transform(
            matrices.translate4(-math.lerp(self.currentlyFocusedTank.oldpos, self.currentlyFocusedTank.pos, client.getFrameTime()) * 16),
            matrices.rotation4(0, 45, 0),
            matrices.rotation4(40, 0, 0),
            matrices.scale4(0.07, 0.07, 0.001),
            matrices.translate4(8, 4, 0),
            matrices.translate4(models.models.tablet.Tablet:getPivot())

        )
    )
end

function UserTablet:dispose()

end

return UserTablet