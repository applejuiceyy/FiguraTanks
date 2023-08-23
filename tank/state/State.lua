local class              = require("tank.class")
local Tank               = require("tank.Tank")
local TankModel          = require("tank.model.TankModel")
local UserTablet         = require("tank.model.UserTablet")
local TankController     = require("tank.host.TankController")
local keyboardController = require("tank.host.controller.keyboardController")
local HUD                = require("tank.model.HUD")
local util               = require("tank.util")
local CrateSpawner       = require("tank.state.CrateSpawner")
local createPingChannel  = require("tank.state.createPingChannel")

local State     = class("State")


local loadTank

function State:init()
    self.load = nil
    self.syncTime = 100

    self.tabletPingChannel = createPingChannel("tablet", UserTablet.requiredPings, function (_function, ...)
        if self.load ~= nil then
            _function(self.load.tablet, ...)
        end
    end)

    self.crateSpawner = CrateSpawner:new(
        createPingChannel("create-spawner", CrateSpawner.requiredPings, function(_function, ...)
            _function(self.crateSpawner, ...)
        end),

        self
    )

    self.itemManagers = {}

    for _, path in pairs(listFiles("tank/items", true)) do
        if string.sub(path, 1, 11) == "tank.items." and string.sub(path, -4) == "init" then
            local manager = require(path)
            local name = manager.name

            local transformedPings = createPingChannel("manager-" .. manager.name, manager.requiredPings, function(_function, ...)
                if self.load ~= nil then
                    _function(self.itemManagers[name], self.load.tank, ...)
                end
            end)

            self.itemManagers[name] = manager:new(transformedPings, self)
        end
    end


    self.syncQueue = {}
    self.syncQueueConsumer = function(what)
        table.insert(self.syncQueue, what)
    end
end

function State:tick()
    self.crateSpawner:tickNonHost()
    if host:isHost() then
        self.crateSpawner:tick()
    end
    for name, manager in pairs(self.itemManagers) do
        manager:tick()
    end
    if self.load ~= nil then
        self.load.tankModel:beforeTankTick(self.load.happenings)
        self.load.tablet:beforeTankTick(self.load.happenings)
        if host:isHost() then
            self.load.HUD:beforeTankTick(self.load.happenings)
        end
        self.load.happenings = self.load.tank:tick()
        self.load.tankModel:afterTankTick(self.load.happenings)
        self.load.tablet:afterTankTick(self.load.happenings)
        if host:isHost() then
            self.load.HUD:afterTankTick(self.load.happenings)
        end
    end

    if host:isHost() then
        if #self.syncQueue > 0 then
            table.remove(self.syncQueue, 1)()
        else
            self.syncTime = self.syncTime - 1
            if self.syncTime < 0 then
                self:populateQueue()
                self.syncTime = 100
            end
        end

        if self.load ~= nil and (self.tankPositionIsDirty or world.getTime() % 40 == 0) then
            pings.syncCriticalTank(self.load.tank:serialiseCritical())
        end
    end
end

function State:markTankPositionDirty()
    self.tankPositionIsDirty = true
end

function State:populateTankQueue()
    local dependentConsumer = util.dependsOn(self.syncQueueConsumer, function()
        return self.load ~= nil
    end)

    dependentConsumer(function()
        pings.syncTank(self.load.tank:serialise())
    end)

    if self.load.tank.currentWeapon ~= nil then
        self.load.tank.currentWeapon:populateSyncQueue(dependentConsumer)
    end

    for id, effect in pairs(self.load.tank.effects) do
        effect:populateSyncQueue(dependentConsumer)
    end
end

function State:populateQueue()
    if self.load ~= nil then
        self:populateTankQueue()
        self.load.tablet:populateSyncQueue(self.syncQueueConsumer)
    end
    self.crateSpawner:populateSyncQueue(self.syncQueueConsumer)
end

function State:render()
    self.crateSpawner:render()
    if self.load ~= nil and self.load.happenings ~= nil then
        self.load.tankModel:render(self.load.happenings)
        self.load.tablet:render(self.load.happenings)
        if host:isHost() then
            self.load.tankController:render(self.load.happenings)
            self.load.HUD:render(self.load.happenings)
        end
    end
end

function State:mouseMove(x, y)
    if self.load ~= nil then
        return self.load.tankController:offsetThirdPersonCamera(x, y)
    end
    return false
end

function State:isLoaded()
    return self.load ~= nil
end

function State:loadTank()
    loadTank()
    self.load.tank.pos = player:getPos()
    self.load.tank:flushLerps()
    self.syncTime = 0
end

function State:unloadTank()
    self.syncTime = math.huge
    pings.removeTank()
end

function State:focusTank()
    pings.focusTank()
end

function State:unfocusTank()
    pings.unfocusTank()
end

local state = State:new()

function loadTank()
    state.load = {}

    state.load.tank = Tank:new(function()
        local hits = {}
        for name, manager in pairs(state.itemManagers) do
            manager:handleWeaponDamages(hits, state.load.tank)
        end
        return hits
    end)
    state.itemManagers["default:tntgun"]:apply(state.load.tank)
    local tankModel = util.deepcopy(models.models.tank.body)
    models.world:addChild(tankModel)
    state.load.tankModel = TankModel:new{
        tank = state.load.tank,
        model = tankModel
    }
    state.load.tablet = UserTablet:new(
        state.tabletPingChannel,
        {tank = state.load.tank}
    )


    if host:isHost() then
        state.load.tankController = TankController:new{
            tank = state.load.tank,
            tankModel = state.load.tankModel
        }
        state.load.HUD = HUD:new{
            tank = state.load.tank
        }
    else
        state.load.tank.controller = keyboardController
    end
end

function pings.syncTank(...)
    if state.load == nil then
        loadTank()
    end
    state.load.tank:apply(...)
end

function pings.syncCriticalTank(...)
    if state.load == nil then
        return
    end
    state.load.tank:applyCritical(...)
end

function pings.removeTank()
    if state.load ~= nil then
        state.load.tankModel:dispose()
        if host:isHost() then
            state.load.HUD:dispose()
        end
        state.load = nil
    end
end

function pings.focusTank()
    if state.load ~= nil then
        if host:isHost() then
            state.load.tankController:focusTank()
        end
        state.load.tablet:equip()
    end
end

function pings.unfocusTank()
    if state.load ~= nil then
        if host:isHost() then
            state.load.tankController:unfocusTank()
        end
        state.load.tablet:unequip()
    end
end


return state