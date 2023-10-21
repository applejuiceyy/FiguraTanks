local class = require "tank.class"
local Tank  = require "tank.Tank"
local util  = require "tank.util.util"
local TankModel = require "tank.model.TankModel"
local TankController = require "tank.host.TankController"
local HUD                = require "tank.model.HUD"

---@params State PingChannel
local TankComplex = class("TankComplex")

function TankComplex:init(state, pingChannel)
    ---@type {[1]:boolean}
    self.disposed = {false}
    self.pingChannel = pingChannel

    

    self.syncCriticalTankPing = self.pingChannel:register{
        name = "syncCriticalTank",
        arguments = {"default", "default", "default", "default", "default"},
        func = function(...)
            self.tank:applyCritical(...)
        end
    }
    self.tank = Tank:new(state.controlRepo, state.itemManagers)

    self.keyboard = state.keyboardRepo:create(self.tank.controller)

    state.itemManagers["default:tntgun"]:_applyAfterPing(self.tank)

    self.tankModelGroup = util.deepcopy(models.models.tank.body)
    models.world:addChild(self.tankModelGroup)

    self.tankModel = TankModel:new{
        tank = self.tank,
        model = self.tankModelGroup
    }

    self.happenings = nil

    if host:isHost() then
        debugger:region("host only")
        self.tankController = TankController:new{
            tank = self.tank,
            tankModel = self.tankModel
        }
        self.hudModel = util.deepcopy(models.models.hud)
        self.HUD = HUD:new{
            tank = self.tank,
            model = self.hudModel
        }

        models:addChild(self.hudModel)
        self.hudModel:setParentType("NONE")
        self.hudModel:setParentType("HUD")
        self.hudModel:setVisible(false)
        debugger:region(nil)
    end
end

function TankComplex:tick()
    self.tankModel:beforeTankTick(self.happenings)
    
    self.happenings = self.tank:tick()
    self.tankModel:afterTankTick(self.happenings)

    if self.tankPositionIsDirty or world.getTime() % 20 == 0 then
        self.syncCriticalTankPing(self.tank:serialiseCritical())
        self.tankPositionIsDirty = false
    end
end

function TankComplex:dispose()
    self.disposed[1] = true
    self.tankModel:dispose()
    if host:isHost() then
        debugger:region("host only")
        self.HUD:dispose()
        self.tankController:dispose()
        models:removeChild(self.hudModel)
        self.hudModel:setParentType("NONE")
        debugger:region(nil)
    end
    models.world:removeChild(self.tankModelGroup)
    self.keyboard:unlisten()
end


return TankComplex