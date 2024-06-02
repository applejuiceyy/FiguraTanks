local class              = require("tank.class")
local UserTablet         = require("tank.model.UserTablet")
local util               = require("tank.util.util")
local CrateSpawner       = require("tank.state.CrateSpawner")
local WorldDamageDisplay = require("tank.state.WorldDamageDisplay")
local settings           = require("tank.settings")
local PingChannel        = require("tank.state.PingChannel")
local TankComplex        = require("tank.state.TankComplex")
local ControlRepo        = require("tank.host.controller.ControlRepo")
local Keyboard           = require("tank.host.controller.Keyboard")


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

    self.controlRepo = ControlRepo:new()

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
        arguments = {"default", "default", "default", "default", "default", "default", "default", "default"},
        func = function(id, ...)
            if self.loadedTanks[id] == nil then
                local complex = TankComplex:new(self, self.pingChannel:inherit("TankComplex", {"default"}, function(id)
                    if self.loadedTanks[id] == nil then
                        return
                    end
                    return self.loadedTanks[id].pingChannel
                end, {id}, {}))
                self:setTankComplex(id, complex)
            end
            self.loadedTanks[id].tank:apply(...)
        end
    }

    self.syncCriticalTankPing = self.pingChannel:register{
        name = "syncCriticalTank",
        arguments = {"default", "default", "default", "default", "default", "default", "default", "default"},
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

            if self.currentlyFocusedTank == id then
                self.tablet:setFocus(nil)
                self.currentlyFocusedTank = nil
            end
        end
    }

    self.focusTankPing = self.pingChannel:register{
        name = "focusTank",
        arguments = {"default"},
        func = function(id)
            if id == self.currentlyFocusedTank then
                return
            end
            local o = self.loadedTanks[id]
            if host:isHost() then
                debugger:region("host only")
                if self.currentlyFocusedTank ~= nil then
                    self.loadedTanks[self.currentlyFocusedTank].tankController:unfocusTank()
                    self.loadedTanks[self.currentlyFocusedTank].hudModel:setVisible(false)
                end
                o.tankController:focusTank()
                o.hudModel:setVisible(true)
                debugger:region(nil)
            end
            self.currentlyFocusedTank = id
            self.tablet:setFocus(o.tank)
            o.keyboard:listen()
        end
    }

    self.unfocusTankPing = self.pingChannel:register{
        name = "unfocusTank",
        arguments = {},
        func = function()
            if self.currentlyFocusedTank == nil then
                return
            end
            if host:isHost() then
                debugger:region("host only")
                if self.currentlyFocusedTank ~= nil then
                    self.loadedTanks[self.currentlyFocusedTank].tankController:unfocusTank()
                    self.loadedTanks[self.currentlyFocusedTank].hudModel:setVisible(false)
                end
                debugger:region(nil)
            end
            self.loadedTanks[self.currentlyFocusedTank].keyboard:unlisten()
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
            local name = manager.id

            self.itemManagers[name] = manager:new(self.pingChannel:inherit("manager-" .. name, {}, nil, {}, {}), self, self.controlRepo)
        end
    end

    self.keyboardRepo = Keyboard:new(self.pingChannel:inherit("keyboard", {}, nil, {}, {}), self.controlRepo)


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
    local l
    if self.currentlyFocusedTank ~= nil and self.loadedTanks[self.currentlyFocusedTank] ~= nil then
        l = self.loadedTanks[self.currentlyFocusedTank]
        self.tablet:beforeTankTick(l.happenings)
        if host:isHost() then
            debugger:region("host only")
            l.HUD:beforeTankTick(l.happenings)
            debugger:region(nil)
        end
    end
    for id, tankComplex in pairs(self.loadedTanks) do
        tankComplex:tick()

        local highCollisionShape, lowCollisionShape = tankComplex.tank:getCollisionShape()

        table.insert(store, {hitbox = {lowCollisionShape, highCollisionShape}, pos = tankComplex.tank.pos})
    end
    if l ~= nil then
        self.tablet:afterTankTick(l.happenings)
        if host:isHost() then
            debugger:region("host only")
            l.HUD:afterTankTick(l.happenings)
            debugger:region(nil)
        end
    end

    avatar:store("entities", store)
 
    if host:isHost() then
        debugger:region("host only")
        pcall(function() error("Heheheh") end)
        if #self.syncQueue > 0 then
            if world.getTime() % 5 == 0 then
            table.remove(self.syncQueue, 1)()
            end
        else
            self.syncTime = self.syncTime - 1
            if self.syncTime < 0 then
                self:populateQueue()
                self.syncTime = 100
            end
        end

        debugger:region(nil)
    end
end

function State:markTankPositionDirty()
    self.tankPositionIsDirty = true
end

function State:populateTankConsumer(id, complex, consumer)
    local dependentConsumer = util.dependsOn(consumer, function()
        return not complex.disposed[1]
    end)

    dependentConsumer(function()
        self.syncTankPing(id, complex.tank:serialise())
    end)

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
                debugger:region(nil)
            end
        end
    end
    if self.currentlyFocusedTank ~= nil and self.loadedTanks[self.currentlyFocusedTank].happenings ~= nil then
        self.tablet:render(self.loadedTanks[self.currentlyFocusedTank].happenings)
        if host:isHost() then
            debugger:region("host only")
            self.loadedTanks[self.currentlyFocusedTank].HUD:render(self.loadedTanks[self.currentlyFocusedTank].happenings)
            debugger:region(nil)
        end
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
    local complex = TankComplex:new(self, self.pingChannel:inherit("TankComplex", {"default"}, function(id)
        return self.loadedTanks[id].pingChannel
    end, {id}, {}))
    complex.tank.pos = player:getPos()
    complex.tank:flushLerps()
    self:setTankComplex(id, complex)
    self:populateTankConsumer(id, complex, self.syncQueueConsumer)
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

function State:unloadTank(id)
    self.unloadTankPing(id)
end

function State:focusTank(id)
    self.focusTankPing(id)
end

function State:unfocusTank()
    self.unfocusTankPing()
end

local state = State:new()

_G.state = state

return state