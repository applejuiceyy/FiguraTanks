local class = require "tank.class"
local Tank  = require "tank.Tank"
local util  = require "tank.util"
local TankModel = require "tank.model.TankModel"
local TankController = require "tank.host.TankController"
local keyboardController = require "tank.host.controller.keyboardController"
local HUD                = require "tank.model.HUD"

---@params State
local TankComplex = class("TankComplex")

function TankComplex:init(state)
    self.disposed = false
    self.tank = Tank:new(function()
        local hits = {}
        for name, manager in pairs(state.itemManagers) do
            manager:handleWeaponDamages(hits, self.tank)
        end
        return hits
    end)
    state.itemManagers["default:tntgun"]:_applyAfterPing(self.tank)

    self.tankModelGroup = util.deepcopy(models.models.tank.body)
    models.world:addChild(self.tankModelGroup)

    self.tankModel = TankModel:new{
        tank = self.tank,
        model = self.tankModelGroup
    }

    self.happenings = nil


    --[[
    state.load.tablet = UserTablet:new(
        state.tabletPingChannel,
        {tank = state.load.tank}
    )]]


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
        self.hudModel:setVisible(true)
        debugger:region(nil)
    else
        self.tank.controller = keyboardController
    end

end

function TankComplex:dispose()
    self.tankModel:dispose()
    self.tablet:dispose()
    if host:isHost() then
        debugger:region("host only")
        self.HUD:dispose()
        self.tankController:dispose()
        debugger:region(nil)
    end
    models.world:removeChild(self.tankModelGroup)
    models:removeChild(self.hudModel)
end


return TankComplex