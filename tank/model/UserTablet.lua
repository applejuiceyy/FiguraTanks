local class       = require("tank.class")
local util        = require("tank.util")
local CustomKeywords = require("tank.model.CustomKeywords")
local TankModel      = require("tank.model.TankModel")
local WorldSlice     = require("tank.model.WorldSlice")

---@params {pings:{syncEquip:function}} {tank:any}
local UserTablet = class("UserTablet")

UserTablet.requiredPings = {
    syncEquip = function(self, state)
        util.notHost()
        self:setEquipped(state)
    end
}

function UserTablet:init(pings, opt)
    self.pings = pings
    self.tank = opt.tank

    local tankModel = util.deepcopy(models.models.tank.body)
    tankModel:setLight(15,15)

    self.paperModelRoller = util.group()

    self.paperModelRoller:addChild(tankModel)

    self.paperModel = TankModel:new{
        tank = self.tank,
        model = tankModel,
        isHUD = true
    }

    self.worldSlice = WorldSlice:new{
        group = self.paperModelRoller,
        onTask = function(e) e:setLight(15,15) end
    }

    self.equipped = false
end

function UserTablet:populateSyncQueue(consumer)
    consumer(function()
        self.pings.syncEquip(self.equipped)
    end)
end

function UserTablet:setEquipped(state)
    state = not not state
    if self.equipped ~= state then
        if state then
            self:equip()
        else
            self:unequip()
        end
        self.equipped = state
    end
end

function UserTablet:equip()
    models.models.tablet.Tablet:addChild(self.paperModelRoller)
    models.models.tablet:setVisible(true)
    vanilla_model.HEAD:setVisible(false)
    vanilla_model.HELMET_HEAD:setVisible(false)
    vanilla_model.HAT:setVisible(false)
    vanilla_model.HELMET_HAT:setVisible(false)
    vanilla_model.LEFT_ARM:setVisible(false)
    vanilla_model.RIGHT_ARM:setVisible(false)
    vanilla_model.HELD_ITEMS:setVisible(false)
    self.equipped = true
end

function UserTablet:unequip()
    models.models.tablet.Tablet:removeChild(self.paperModelRoller)
    models.models.tablet:setVisible(false)
    vanilla_model.HEAD:setVisible(true)
    vanilla_model.HELMET_HEAD:setVisible(true)
    vanilla_model.HAT:setVisible(true)
    vanilla_model.HELMET_HAT:setVisible(true)
    vanilla_model.LEFT_ARM:setVisible(true)
    vanilla_model.RIGHT_ARM:setVisible(true)
    vanilla_model.HELD_ITEMS:setVisible(true)
    self.equipped = false
end

function UserTablet:beforeTankTick(oldHappenings)
    self.paperModel:beforeTankTick(oldHappenings)
end
function UserTablet:afterTankTick(happenings)
    self.paperModel:afterTankTick(happenings)
    self.worldSlice:update(self.tank.pos)
end

function UserTablet:render(happenings)
    self.paperModel:render(happenings)
    self.paperModelRoller:setMatrix(
        util.transform(
            matrices.translate4(-math.lerp(self.tank.oldpos, self.tank.pos, client.getFrameTime()) * 16),
            matrices.rotation4(0, 45, 0),
            matrices.rotation4(40, 0, 0),
            matrices.scale4(0.07, 0.07, 0.001),
            matrices.translate4(8, 4, 0),
            matrices.translate4(models.models.tablet.Tablet:getPivot())

        )
    )
end

function UserTablet:dispose()
    self:setEquipped(false)
end

return UserTablet