local class              = require("tank.class")
local UserTablet         = require("tank.model.UserTablet")
local util               = require("tank.util")
local CrateSpawner       = require("tank.state.CrateSpawner")
local WorldDamageDisplay = require("tank.state.WorldDamageDisplay")
local settings           = require("tank.settings")
local PingChannel        = require("tank.state.PingChannel")
local TankComplex        = require("tank.state.TankComplex")

---@params 
local State     = class("State")

local function createConverter(byField, main, specifier)
    return {
        deflate = function(tank)
            if byField[tank] ~= nil then
                return true, byField[tank]
            end
            return false, "Unknown id of " .. tostring(tank)
        end,

        inflate = function(id)
            if main[id] ~= nil then
                return true, specifier(main[id])
            end
            return false, "Unknown id " .. id
        end
    }
end


function State:init()
    ---@type {[string]:TankComplex}
    self.loadedTanks = {}
    self.tankToComplexId = {}

    self.currentlyFocusedTank = nil

    self.tablet = UserTablet:new()


    self.pingChannel = PingChannel:new(
        "figuraTanks",
        nil,
        {
            tank = createConverter(self.tankToComplexId, self.loadedTanks, function(s) return s.tank end),
            default = {
                inflate = function(e) return true, e end,
                deflate = function(e) return true, e end
            }
        },
        {}
    )

    self.syncTankPing = self.pingChannel:register{
        name = "syncTank",
        arguments = {"default", "default", "default", "default", "default", "default", "default", "default", "default"},
        func = function(id, ...)
            if self.loadedTanks[id] == nil then
                local complex = TankComplex:new(self)
                self:setTankComplex(id, complex)
            end
            self.loadedTanks[id].tank:apply(...)
        end
    }

    self.syncCriticalTankPing = self.pingChannel:register{
        name = "syncCriticalTank",
        arguments = {"default", "default", "default", "default", "default", "default", "default", "default", "default"},
        func = function(id, ...)
            if self.loadedTanks[id] == nil then
                return
            end
            self.loadedTanks[id].tank:applyCritical(...)
        end
    }

    
    self.unloadTankPing = self.pingChannel:register{
        name = "unloadTank",
        arguments = {"default"},
        func = function(id, ...)
            if self.loadedTanks[id] == nil then
                return
            end

            self.tankToComplexId[self.loadedTanks[id].tank] = nil
            self.loadedTanks[id]:dispose()
            self.loadedTanks[id] = nil
        end
    }

    self.focusTankPing = self.pingChannel:register{
        name = "focusTank",
        arguments = {"default"},
        func = function(id)
            local o = self.loadedTanks[id]
            if host:isHost() then
                debugger:region("host only")
                if self.currentlyFocusedTank ~= nil then
                    self.loadedTanks[self.currentlyFocusedTank].tankController:unfocusTank()
                end
                o.tankController:focusTank()
                debugger:region(nil)
            end
            self.currentlyFocusedTank = id
            self.tablet:setFocus(o.tank)
        end
    }

    self.unfocusTankPing = self.pingChannel:register{
        name = "unfocusTank",
        arguments = {},
        func = function()
            if self.currentlyFocusedTank == nil then
                return
            end
            self.tablet:setFocus(nil)
            if host:isHost() then
                debugger:region("host only")
                if self.currentlyFocusedTank ~= nil then
                    self.loadedTanks[self.currentlyFocusedTank].tankController:unfocusTank()
                end
                debugger:region(nil)
            end
            self.currentlyFocusedTank = nil
            self.tablet:setFocus(nil)
        end
    }

    self.syncTime = 100

    self.crateSpawner = CrateSpawner:new(self.pingChannel:inherit("create-spawner", {}, nil, {}, {}), self)

    self.worldDamageDisplay = WorldDamageDisplay:new()

    self.itemManagers = {}

    for _, path in pairs(listFiles("tank/items", true)) do
        if string.sub(path, 1, 11) == "tank.items." and string.sub(path, -4) == "init" then
            local manager = require(path)
            local name = manager.name

            self.itemManagers[name] = manager:new(self.pingChannel:inherit("manager-" .. name, {}, nil, {}, {}), self)
        end
    end


    self.syncQueue = {}
    self.syncQueueConsumer = function(what)
        table.insert(self.syncQueue, what)
    end

    self.bulletDestroyBlocksWarning = 121
end

function State:tick()
    if self.bulletDestroyBlocksWarning <= 120 then
        local color = "ff0000"
        if self.bulletDestroyBlocksWarning % 40 < 20 then
            color = "ffffff"
        end
        host:setActionbar('{"text":"The tank can destroy blocks!", "color":"#' .. color .. '"}')
        self.bulletDestroyBlocksWarning = self.bulletDestroyBlocksWarning + 1
    end

    self.worldDamageDisplay:tick()
    self.crateSpawner:tick()
    for name, manager in pairs(self.itemManagers) do
        manager:tick()
    end

    local store = {}
    if self.currentlyFocusedTank ~= nil then
        self.tablet:beforeTankTick(self.loadedTanks[self.currentlyFocusedTank].happenings)
    end
    for id, tankComplex in pairs(self.loadedTanks) do
        tankComplex.tankModel:beforeTankTick(tankComplex.happenings)
        if host:isHost() then
            debugger:region("host only")
            tankComplex.HUD:beforeTankTick(tankComplex.happenings)
            debugger:region(nil)
        end
        tankComplex.happenings = tankComplex.tank:tick()
        tankComplex.tankModel:afterTankTick(tankComplex.happenings)
        if host:isHost() then
            debugger:region("host only")
            tankComplex.HUD:afterTankTick(tankComplex.happenings)
            debugger:region(nil)
        end

        local highCollisionShape, lowCollisionShape = tankComplex.tank:getCollisionShape()

        table.insert(store, {hitbox = {lowCollisionShape, highCollisionShape}, pos = tankComplex.tank.pos})
    end
    if self.currentlyFocusedTank ~= nil then
        self.tablet:afterTankTick(self.loadedTanks[self.currentlyFocusedTank].happenings)
    end

    avatar:store("entities", store)

    if host:isHost() then
        debugger:region("host only")
        if #self.syncQueue > 0 then
            table.remove(self.syncQueue, 1)()
        else
            self.syncTime = self.syncTime - 1
            if self.syncTime < 0 then
                self:populateQueue()
                self.syncTime = 100
            end
        end
        --[[
        if self.load ~= nil and (self.tankPositionIsDirty or world.getTime() % 40 == 0) then
            pings.syncCriticalTank(self.load.tank:serialiseCritical())
            self.tankPositionIsDirty = false
        end]]
        debugger:region(nil)
    end
end

function State:markTankPositionDirty()
    self.tankPositionIsDirty = true
end

function State:populateTankConsumer(id, complex, consumer)
    local dependentConsumer = util.dependsOn(consumer, function()
        return not complex.disposed
    end)

    dependentConsumer(function()
        self.syncTankPing(id, complex.tank:serialise())
    end)

    if complex.tank.currentWeapon ~= nil then
        complex.tank.currentWeapon:populateSyncQueue(dependentConsumer)
    end

    for id, effect in pairs(complex.tank.effects) do
        effect:populateSyncQueue(dependentConsumer)
    end
end

function State:populateQueue()
    for id, complex in pairs(self.loadedTanks) do
        self:populateTankConsumer(id, complex, self.syncQueueConsumer)
    end
    self.crateSpawner:populateSyncQueue(self.syncQueueConsumer)
end

function State:render()
    for name, manager in pairs(self.itemManagers) do
        manager:render()
    end
    self.crateSpawner:render()
    for id, tankComplex in pairs(self.loadedTanks) do
        if tankComplex.happenings ~= nil then
            tankComplex.tankModel:render(tankComplex.happenings)
            if host:isHost() then
                debugger:region("host only")
                tankComplex.tankController:render(tankComplex.happenings)
                tankComplex.HUD:render(tankComplex.happenings)
                debugger:region(nil)
            end
        end
    end
    if self.currentlyFocusedTank ~= nil and self.loadedTanks[self.currentlyFocusedTank].happenings ~= nil then
        self.tablet:render(self.loadedTanks[self.currentlyFocusedTank].happenings)
    end
end

function State:mouseMove(x, y)
    if self.currentlyFocusedTank ~= nil then
        return self.loadedTanks[self.currentlyFocusedTank].tankController:offsetThirdPersonCamera(x, y)
    end
    return false
end

function State:loadTank(id)
    if settings.bulletsCanBreakBlocks then
        self.bulletDestroyBlocksWarning = 0
    end
    local complex = TankComplex:new(self)
    complex.tank.pos = player:getPos()
    complex.tank:flushLerps()
    self:setTankComplex(id, complex)
    self.syncTime = 0
end

local abc = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

function State:generateId()
    local result
    repeat
        local v = {}
        for i = 1, 5 do
            local s = math.floor(math.random() * string.len(abc)) + 1
            table.insert(v, string.sub(abc, s, s))
        end
        result = table.concat(v, "")
    until self.loadedTanks[result] == nil
    return result
end

function State:setTankComplex(id, complex)
    self.loadedTanks[id] = complex
    self.tankToComplexId[complex.tank] = id
end

function State:unloadTank()
    self.syncTime = math.huge
    pings.removeTank()
end

function State:focusTank(id)
    self.focusTankPing(id)
end

function State:unfocusTank()
    self.unfocusTankPing()
end

local state = State:new()

function pings.syncTank(...)

end

function pings.syncCriticalTank(...)

end

_G.state = state

return state