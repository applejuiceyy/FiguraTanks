local class     = require("tank.class")
local util      = require("tank.util")
local collision = require("tank.collision")
local settings    = require("tank.settings")

---@params {actions:{[string]:{arguments:string[],acknowledgementArguments:string[],onAcknowledgement:function,onAcknowledging:function,onAction:function}},dispose:function,rendering:{render:function,tick:function},publicFace:function,createPingDataFromEntity:function,fetchIdFromData:function,fetchIdFromPing:function,createEntityDataFromPing:function,name:string,avatarVars:fun(in:string):string}
local SharedWorldState     = class("SharedWorldState")

local function getChain(obj, a, ...)
    if obj == nil or a == nil then
        return obj
    end
    return getChain(obj[a], ...)
end

local function setChain(obj, thing, a, b, ...)
    if a ~= nil and b == nil then
        obj[a] = thing
        return
    end

    if obj[a] == nil then
        obj[a] = {}
    end
    return setChain(obj[a], thing, b, ...)
end

local function deleteChain(obj, a, b, ...)
    if a ~= nil and b == nil then
        obj[a] = nil
        return
    end
    if obj[a] == nil then
        return
    end
    deleteChain(obj[a], b, ...)
    if next(obj[a]) == nil then
        obj[a] = nil
    end
end


function SharedWorldState:init(opt)
    self.opt = opt
    self.actions = {}

    for actionName, actionData in pairs(self.opt.actions) do
        local obj = {}
        obj.opt = actionData
        obj.perform = {}
        obj.publicFacingPerforms = {}
        obj.performAcknowledgements = {}
        self.actions[actionName] = obj
    end
    
    self.pings = nil

    self.entities = {}
    self.publicFacingEntities = {}

    self.entityRenderers = {}
    self.renderDirtyRenderers = {}
    self.tickDirtyRenderers = {}


    self.hostIsSyncing = false
    self.syncedEntities = {}

    self:updatePublicFacingEntities()
end

--#region pings
function SharedWorldState:makePingStructure()
    local pings = {
        startTransmission = function()
            self.hostIsSyncing = true
            self.syncedEntities = {}
        end,

        endTransmission = function()
            if self.hostIsSyncing then
                for id in pairs(self.entities) do
                    if not self.syncedEntities[id] then
                        self:deleteEntityWithoutPing(id)
                    end
                end

                self.hostIsSyncing = false
                self.syncedEntities = {}
            end
        end,

        syncEntity = function(...)
            local id = self.opt.fetchIdFromPing(...)
            self.syncedEntities[id] = true
            if self.entities[id] == nil then
                local thing = self.opt.createEntityDataFromPing(...)
                if thing ~= nil then
                    self:newEntityWithoutPing(thing)
                end
            end
        end,

        deleteEntity = function(id)
            self:deleteEntityWithoutPing(id)
        end
    }

    for actionName, data in pairs(self.actions) do
        pings["doAction" .. actionName] = {
            arguments = {"default", "default", table.unpack(data.opt.arguments)},

            fn = function(uuid, id, ...)
                setChain(data.publicFacingPerforms, {...}, uuid, id)
            end
        }

        pings["actionAck" .. actionName] = {
            arguments = {"default", "default", table.unpack(data.opt.acknowledgementArguments)},

            fn = function(uuid, id, ...)
                data.opt.onAcknowledgement(id, self.entities[id], ...)
                setChain(data.performAcknowledgements, {...}, uuid, id)
            end
        }
    end

    return pings
end

function SharedWorldState:setBakedPings(pings)
    self.pings = pings
end
--#endregion

--#region api
function SharedWorldState:iterateAllEntities()
    local uuid = nil
    local id = nil
    local current = nil
    local vars = world.avatarVars()

    uuid, current = next(vars)

    local varName = self:avatarVar("sharedWorldStateEntities_" .. self.opt.name)

    return function()
        while true do
            if current[varName] ~= nil then
                local data
                id, data = next(current[varName], id)
                if id ~= nil then
                    return uuid, id, data
                end
            end

            uuid, current = next(vars, uuid)
            id = nil

            if uuid == nil then
                return
            end
        end
    end
end

function SharedWorldState:iterateOwnEntities()
    return pairs(self.entities)
end

function SharedWorldState:fetchEntity(uuid, id)
    local vars = world.avatarVars()
    local varName = self:avatarVar("sharedWorldStateEntities_" .. self.opt.name)

    return getChain(vars, uuid, varName, id)
end

function SharedWorldState:fetchOwnEntity(id)
    return self.entities[id]
end

function SharedWorldState:entityIsWaitingAction(uuid, id, name)
    local data = self.actions[name]
    if data.perform[uuid] == nil then
        return false
    end

    if data.perform[uuid][id] == nil then
        return false
    end

    return data.perform[uuid][id].waitingSince
end
--#endregion

--#region proxies
function SharedWorldState:avatarVar(name)
    return self.opt.avatarVars(name)
end
--#endregion

--#region actions
function SharedWorldState:doAction(uuid, id, name, ...)
    if not host:isHost() then
        return error("perfoming actions only available on host", 2)
    end
    local entity = self:fetchEntity(uuid, id)
    if entity == nil then
        return error("Unknown entity")
    end

    local data = self.actions[name]

    setChain(data.perform, {
        waitingSince = world.getTime(),
        entityData = self:fetchEntity(uuid, id)
    }, uuid, id)

    self.pings["doAction" .. name](uuid, id, ...)
end
--#endregion


function SharedWorldState:populateSyncQueue(consumer)
    consumer(function()
        self.pings.startTransmission()
    end)
    for id, data in pairs(self.entities) do
        consumer(function()
            if self.entities[id] ~= nil then
                self.pings.syncEntity(self.opt.createPingDataFromEntity(data))
            end
        end)
    end
    consumer(function()
        self.pings.endTransmission()
    end)
end

function SharedWorldState:newEntity(...)
    if not host:isHost() then
        return error("creating entities only available on host", 2)
    end
    self.pings.syncEntity(...)
end

function SharedWorldState:deleteEntity(id)
    if not host:isHost() then
        return error("deleting entities only available on host", 2)
    end
    self.pings.deleteEntity(id)
end


function SharedWorldState:newEntityWithoutPing(data)
    local id = self.opt.fetchIdFromData(data)
    local publicFacing = self.opt.publicFace(data)
    self.entities[id] = data
    self.publicFacingEntities[id] = publicFacing
    self:markEntityRenderDirty(id)
    self:markEntityTickDirty(id)
    self:updatePublicFacingEntities()
end

function SharedWorldState:deleteEntityWithoutPing(id)
    if self.entities[id] == nil then
        return
    end
    self.opt.dispose(self.entities[id])
    self.entities[id] = nil
    self.publicFacingEntities[id] = nil
    self:updatePublicFacingEntities()
end


function SharedWorldState:updatePublicFacingEntities()
    avatar:store(self:avatarVar("sharedWorldStateEntities_" .. self.opt.name), self.publicFacingEntities)
end

function SharedWorldState:playerSupports(player)
    return not not player:getVariable(self:avatarVar("sharedWorldStateBeacon_" .. self.opt.name))
end

function SharedWorldState:playerSupportsAction(player, action)
    return self:playerSupports(player) and not not player:getVariable(self:avatarVar("sharedWorldStateActionBeacon_" .. self.opt.name .. "_" .. action))
end

function SharedWorldState:tick()
    avatar:store(self:avatarVar("sharedWorldStateBeacon_" .. self.opt.name), true)

    for actionName, data in pairs(self.actions) do
        avatar:store(self:avatarVar("sharedWorldStateActionBeacon_" .. self.opt.name .. "_" .. actionName), true)
        avatar:store(self:avatarVar("sharedWorldStateAction_" .. self.opt.name .. "_" .. actionName), data.publicFacingPerforms)
        avatar:store(self:avatarVar("sharedWorldStateActionAck_" .. self.opt.name .. "_" .. actionName), data.performAcknowledgements)
        data.publicFacingPerforms = {}
        data.performAcknowledgements = {}
    end

    self:tickRendering()

    if host:isHost() then
        debugger:region("host only")
        for actionName, data in pairs(self.actions) do
            self:processAction(actionName, data)
        end
        debugger:region(nil)
    end
end

function SharedWorldState:processAction(actionName, data)
    local o = {}
    local vars = world.avatarVars()
    for waitingForUUID, thingsWaiting in pairs(data.perform) do
        for id, waitingData in pairs(thingsWaiting) do
            if waitingData.waitingSince < world.getTime() - 100 then
                print("Tried performing action but got no acknowledgment")
                o[{waitingForUUID, id}] = true
            end
        end
    end

    for u in pairs(o) do
        deleteChain(data.perform, u[1], u[2])
    end


    for otherUUID, stuff in pairs(vars) do
        self:processActions(actionName, data, otherUUID, stuff)
        self:processAcknowledgements(actionName, data, otherUUID, stuff)
    end
end

function SharedWorldState:processActions(actionName, actionData, requesterUUID, avatarVars)
    local avatarActionName = self:avatarVar("sharedWorldStateAction_" .. self.opt.name .. "_" .. actionName)

    local stuff = getChain(avatarVars, avatarActionName, player:getUUID())
    if stuff ~= nil then
        for id, data in pairs(stuff) do
            if self.entities[id] == nil then
                print("Got action from unknown entity")
            else
                self.pings["actionAck" .. actionName](requesterUUID, id, actionData.opt.onAcknowledging(id, self.entities[id], table.unpack(data)))
            end
        end
    end
end

function SharedWorldState:processAcknowledgements(actionName, actionData, ackUUID, avatarVars)
    local avatarActionName = self:avatarVar("sharedWorldStateActionAck_" .. self.opt.name .. "_" .. actionName)

    local stuff = getChain(avatarVars, avatarActionName, player:getUUID())
    if stuff ~= nil then
        for id, data in pairs(stuff) do
            if getChain(actionData.perform, ackUUID, id) == nil then
                print("Got action acknowledgment for unknown action")
            else
                actionData.opt.onAction(ackUUID, id, getChain(actionData.perform, ackUUID, id).entityData, table.unpack(data))
                deleteChain(actionData.perform, ackUUID, id)
            end
        end
    end
end

--#region rendering
function SharedWorldState:markEntityRenderDirty(id)
    self.renderDirtyRenderers[id] = true
end

function SharedWorldState:markEntityTickDirty(id)
    self.tickDirtyRenderers[id] = true
end

function SharedWorldState:tickRendering()
    for id in pairs(self.tickDirtyRenderers) do
        if self.entities[id] == nil or self.opt.rendering.tick(id, self.entities[id]) then
            self.tickDirtyRenderers[id] = nil
        end
    end
end

function SharedWorldState:render()
    for id in pairs(self.renderDirtyRenderers) do
        if self.entities[id] == nil or self.opt.rendering.render(id, self.entities[id]) then
            self.renderDirtyRenderers[id] = nil
        end
    end
end
--#endregion


return SharedWorldState