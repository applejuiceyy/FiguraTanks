local class     = require("tank.class")
local util      = require("tank.util")
local collision = require("tank.collision")
local settings    = require("tank.settings")
local SharedWorldState = require("tank.state.worldState.SharedWorldState")

---@params PingChannel State
local CrateSpawner     = class("CrateSpawner")

local crates = {
    ["default:health"] = true,
    ["default:speed"] = true,
    ["default:friction"] = true,
    ["default:raybeam"] = true,
    ["default:flamethrower"] = true
}

local cratesIndexed = {}

for key in pairs(crates) do
    table.insert(cratesIndexed, key)
---@diagnostic disable-next-line: assign-type-mismatch
    crates[key] = #cratesIndexed
end

local function positionIsSupported(position)
    return not collision.collidesWithWorld(vec(0.3, 0.8, 0.3) + position, vec(-0.3, 0, -0.3) + position)
    and collision.collidesWithWorld(vec(0.1, 0, 0.1) + position, vec(-0.1, -0.1, -0.1) + position)
end


function CrateSpawner:init(pingChannel, state)
    pingChannel:augment{
        crate = {
            inflate = function(id)
                local crate = self.sharedWorldState:fetchOwnEntity(id)
                if crate == nil then
                    return false, "Unknown crate"
                end
                return true, crate
            end,
    
            deflate = function(data)
                local crate = self.sharedWorldState:idFromEntity(data)
                if crate == nil then
                    return false, "Unknown crate"
                end
                return true, crate
            end
        }
    }

    self.unsupportedCrate = pingChannel:register{
        name = "unsupportedCrate",
        arguments = {"default"},
        func = function(id)
                local crate = self.sharedWorldState:fetchOwnEntity(id)
                if crate == nil then
                    return
                end
                self.sharedWorldState:deleteEntityWithoutPing(id)
                for i = 0, 10 do
                    particles:newParticle("block barrel",
                    crate.location + vec(math.random() - 0.5, math.random(), math.random() - 0.5) * vec(0.6, 0.8, 0.6)
                )
            end
        end
    }

    self.tryingToSpawnCrates = true

    self.state = state

    self.destroyCrates = false

    self.sharedWorldStatePingChannel = pingChannel:inherit(
        "SWS", {}, function() return self.sharedWorldStatePingChannel end, {}, {}
    )

    self.sharedWorldState = SharedWorldState:new{
        name = "tankCrates",
        avatarVars = function(name)
            return "__FiguraTanks_" .. name
        end,
        pingChannel = self.sharedWorldStatePingChannel,
        actions = {
            tankReach = {
                arguments = {},
                acknowledgementArguments = {},
                onAcknowledgement = function(id)
                    self.sharedWorldState:deleteEntityWithoutPing(id)
                end,
                onAcknowledging = function(id) end,
                onAction = function(pd, uuid, id, data)
                    if not pd.disposed[1] then
                        self:applyEffect(pd.tank, uuid, data.kind)
                    end
                end
            }
        },

        createEntityDataFromPing = function(id, location, kindIndex, validIn)
            if not player:isLoaded() then
                return
            end

            local kind = cratesIndexed[kindIndex]

            local icon = util.group()
            self.state.itemManagers[kind]:generateIconGraphics(icon)
            models.world:addChild(icon)
            icon:matrix(
                util.transform(
                    matrices.rotation4(90, 0, 0),
                    matrices.scale4(0.7, 0.7, 0.7),
                    matrices.translate4(location * 16 + vec(0, 0.1, 0))
                )
            )

            local crate = util.group()
            crate:newBlock("e"):block("barrel[facing=up]"):matrix(util.transform(
                matrices.translate4(-8, 0, -8),
                matrices.scale4(0.6, 0.8, 0.6)
            ))
            local group = util.group():setScale(0.5, 0.5, 0.5):setPos(0, 0.4 * 16, 0.3 * 16 + 0.01):setRot(0, 180, 0)
            self.state.itemManagers[kind]:generateIconGraphics(group)
            crate:addChild(group)
            local group = util.group():setScale(0.5, 0.5, 0.5):setPos(0, 0.4 * 16, -0.3 * 16 - 0.01):setRot(0, 0, 0)
            self.state.itemManagers[kind]:generateIconGraphics(group)
            crate:addChild(group)
            local group = util.group():setScale(0.5, 0.5, 0.5):setPos(0.3 * 16 + 0.01, 0.4 * 16, 0):setRot(0, 270, 0)
            self.state.itemManagers[kind]:generateIconGraphics(group)
            crate:addChild(group)
            local group = util.group():setScale(0.5, 0.5, 0.5):setPos(-0.3 * 16 - 0.01, 0.4 * 16, 0):setRot(0, 90, 0)
            self.state.itemManagers[kind]:generateIconGraphics(group)
            crate:addChild(group)

            local overTextGroup = util.group()
            overTextGroup:setParentType("CAMERA")


            local anchorGrup = util.group()
            anchorGrup:setPos(0, 20, 0)
            anchorGrup:addChild(overTextGroup)

            local text = overTextGroup:newText("e")
            text:setText(string.format('[{"text":%q, "color":"#ff6622"}, {"text":"\\n"}, {"text":"Crate hosted by ", "color":"#ffffff"}, {"text":%q, "color":"#ff6622"}]', kind, player:getName()))
            text:setAlignment("CENTER")
            text:setPos(0, 9 * 0.4, 0)
            text:setScale(0.4, 0.4, 0.4)
            text:shadow(true)
            crate:addChild(anchorGrup)


            models.world:addChild(crate)

            local creator = self.state.worldDamageDisplay:createDamageCreator((location - vec(0, 0.01, 0)):floor(), 30)

            return {
                id = id,
                location = location,
                kind = kind,
                groundModel = icon,
                crateModel = crate,
                validIn = validIn,
                modelRotation = math.random() * 360,
                crateRotation = math.random() * 360,
                damageCreator = creator
            }
        end,
        syncEntityArgs = {"default", "default", "default", "default"},
        createPingDataFromEntity = function(data)
            return data.id, data.location, crates[data.kind], data.validIn
        end,

        fetchIdFromData = function(data)
            return data.id
        end,

        fetchIdFromPing = function(id)
            return id
        end,

        publicFace = function(data)
            return {
                id = data.id,
                location = data.location,
                kind = data.kind,
                validIn = data.validIn
            }
        end,

        rendering = {
            render = function(id, data)
                local since = world.getTime() - (data.validIn - 100)
        
                if since >= 100 then
                    data.crateModel:matrix(
                        util.transform(
                            matrices.rotation4(0, data.crateRotation, 0),
                            matrices.translate4(data.location * 16)
                        )
                    )
                    local id = world.getBlockState(data.location - vec(0, 1, 0)).id
                    pcall(function()
                        for i = 0, 40 do
                            particles:newParticle("block " .. id, data.location + vec(0.5, 0, 0.5)):velocity(vec(math.random() - 0.5, math.random(), math.random() - 0.5) / 3)
                        end
                    end)
                    if since == 100 then
                        data.damageCreator:apply()
                    end
                    return true
                else
                    data.crateModel:matrix(
                        util.transform(
                            matrices.rotation4(0, data.crateRotation, 0),
                            matrices.translate4(0, (100 - since - client.getFrameTime()) * 30, 0),
                            matrices.rotation4(0, data.modelRotation, 0),
                            matrices.rotation4(10, 0, 0),
                            matrices.rotation4(0, -data.modelRotation, 0),
                            matrices.translate4(data.location * 16)
                        )
                    )
                end
            end,

            tick = function() end
        },

        dispose = function(data)
            models.world:removeChild(data.groundModel)
            models.world:removeChild(data.crateModel)
        end
    }
end

function CrateSpawner:trySpawnCrate()
    self.tryingToSpawnCrates = self.tryingToSpawnCrates or math.random() > 0.99
    if not self.tryingToSpawnCrates then
        return
    end

    local x = math.random(-20, 20)
    local y = math.random(-5, 5)
    local z = math.random(-20, 20)

    local candidates = {player:getPos():floor()}
    for _, complex in pairs(self.state.loadedTanks) do
        table.insert(candidates, complex.tank.pos)
    end

    local center = candidates[math.random(1, #candidates)]

    local place = vec(x, y, z) + center + vec(math.random() - 0.5, 0, math.random() - 0.5)

    local y = 0
    local block = world.getBlockState(place)
    for _, shape in ipairs(block:getCollisionShape()) do
        y = math.max(y, shape[2].y)
    end

    place.y = place.y + y

    if not positionIsSupported(place) then
        return
    end

    for uuid, id, data in self.sharedWorldState:iterateAllEntities() do
        if (data.location - place):length() < 20 then
            return
        end
    end


    local kindIndex = math.random(1, #cratesIndexed)
    self.sharedWorldState:newEntity(util.intID(), place, kindIndex, world.getTime() + 100)
    self.tryingToSpawnCrates = false
end

function CrateSpawner:populateSyncQueue(consumer)
    self.sharedWorldState:populateSyncQueue(consumer)
end

function CrateSpawner:testCrateReach(tankDispose, tank)

    local highCollisionShape, lowCollisionShape = tank:getCollisionShape()

    for uuid, id, data in self.sharedWorldState:iterateAllEntities() do
        if (not self.sharedWorldState:entityIsWaitingAction(uuid, id, "tankReach")) and

        (data.validIn - 2 == world.getTime() or data.validIn <= world.getTime()) and

        collision.collidesWithRectangle(
            highCollisionShape + tank.pos,
            lowCollisionShape + tank.pos,
            data.location + vec(0.3, 0.8, 0.3),
            data.location - vec(0.3, 0, 0.3)
        ) then
            if data.validIn - 2 == world.getTime() then
                tank.health = tank.health - 20
            end

            if data.validIn <= world.getTime() then
                self.sharedWorldState:doAction({disposed = tankDispose, tank = tank}, uuid, id, "tankReach")
            end
        end
    end
end



function CrateSpawner:applyEffect(tank, owner, id)
    if not crates[id] then
        host:setActionbar(
            string.format(
                '[{"text":"Unknown item "}, {"text":%q, "color":"#ff6622"}, {"text": ", maybe "}, {"text":%q, "color":"#ff6622"}, {"text":" has a custom item?"}]',
                id, world.getEntity(owner):getName()
            )
        )
        return
    end
    
    self.state.itemManagers[id]:apply(tank)
end

function CrateSpawner:tick()
    if host:isHost() then
        debugger:region("host only")
        if settings.spawnCrates then
            self:trySpawnCrate()
            for id, crate in self.sharedWorldState:iterateOwnEntities() do
                if not positionIsSupported(crate.location) then
                    self.unsupportedCrate(id)
                end
            end
        end

        if self.destroyCrates then
            for id in self.sharedWorldState:iterateOwnEntities() do
                self.unsupportedCrate(id)
                goto finish
            end
            self.destroyCrates = false
            ::finish::
        end

        for _, complex in pairs(self.state.loadedTanks) do
            self:testCrateReach(complex.disposed, complex.tank)
        end
        debugger:region(nil)
    end

    self.sharedWorldState:tick()
end

function CrateSpawner:render()
    self.sharedWorldState:render()
end



return CrateSpawner