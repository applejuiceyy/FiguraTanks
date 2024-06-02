local class     = require("tank.class")
local util      = require("tank.util.util")
local collision = require("tank.collision")
local settings    = require("tank.settings")
local SharedWorldState = require("tank.state.worldState.SharedWorldState")

---@params PingChannel State
local CrateSpawner     = class("CrateSpawner")

local function getCliffScore(pos)
    local flatPos = pos:copy():floor()
    local cliffScore = 0
    local bigCliff = false
    if not collision.collidesWithWorld(vec(1, 0, 0) + flatPos, vec(0, -3, -1) + flatPos) then
        cliffScore = cliffScore + 1
    end

    if not collision.collidesWithWorld(vec(0, 0, 1) + flatPos, vec(-1, -3, 0) + flatPos) then
        cliffScore = cliffScore + 1
    end

    if not collision.collidesWithWorld(vec(2, 0, 1) + flatPos, vec(1, -3, 0) + flatPos) then
        cliffScore = cliffScore + 1
    end
    if not collision.collidesWithWorld(vec(1, 0, 2) + flatPos, vec(0, -3, 1) + flatPos) then
        cliffScore = cliffScore + 1
    end


    if not collision.collidesWithWorld(vec(1, 0, 0) + flatPos, vec(0, -15, -1) + flatPos) then
        cliffScore = cliffScore + 2
        bigCliff = true
    end
    if not collision.collidesWithWorld(vec(0, 0, 1) + flatPos, vec(-1, -15, 0) + flatPos) then
        cliffScore = cliffScore + 2
        bigCliff = true
    end
    if not collision.collidesWithWorld(vec(2, 0, 1) + flatPos, vec(1, -15, 0) + flatPos) then
        cliffScore = cliffScore + 2
        bigCliff = true
    end
    if not collision.collidesWithWorld(vec(1, 0, 2) + flatPos, vec(0, -15, 1) + flatPos) then
        cliffScore = cliffScore + 2
        bigCliff = true
    end

    return cliffScore, bigCliff
end

local crates = {
    ["default:health"] = function()
        return 50
    end,
    ["default:speed"] = function()
        return 100
    end,
    ["default:friction"] = function(pos)
        if string.find(world.getBlockState(pos - vec(0, 0.2, 0)).id, "ice") then
            return 170
        end
        return 80
    end,
    ["default:raybeam"] = function(pos)
        if world.getBlockState(pos - vec(0, 0.2, 0)).id == "minecraft:endstone" then
            return 140
        end
        return 100
    end,
    ["default:flamethrower"] = function(pos)
        if world.getBlockState(pos - vec(0, 0.2, 0)).id == "minecraft:sand" then
            return 120
        end
        return 100
    end,
    ["default:teleport"] = function()
        return 30
    end,
    ["default:aircontrol"] = function(pos)
        return 25 * getCliffScore(pos)
    end
}

local distanceFromOthers = {
    ["default:aircontrol"] = function(pos)
        local score, big = getCliffScore(pos)
        if big then
            return 5
        end
        return 20
    end
}

local cratesChances = {}
local cratesIndexed = {}

for key in pairs(crates) do
    table.insert(cratesIndexed, key)
    cratesChances[key] = crates[key]
    ---@diagnostic disable-next-line: assign-type-mismatch
    crates[key] = #cratesIndexed
end

local function positionIsSupported(position)
    return not collision.collidesWithWorld(vec(0.3, 0.8, 0.3) + position, vec(-0.3, 0, -0.3) + position)
    and collision.collidesWithWorld(vec(0.1, 0, 0.1) + position, vec(-0.1, -0.1, -0.1) + position)
end

local function randomCandidatePosition(center, xd, yd, zd)
    local x = math.random(-xd, xd)
    local y = math.random(-yd, yd)
    local z = math.random(-zd, zd)

    local place = vec(x, y, z) + center + vec(math.random() - 0.5, 0, math.random() - 0.5)

    local y = 0
    local block = world.getBlockState(place)
    for _, shape in ipairs(block:getCollisionShape()) do
        y = math.max(y, shape[2].y)
    end

    place.y = place.y + y

    return place
end

local function generateCrateTextFromData(kind, owner, timeGone)
    local e = string.format('[{"text":%q, "color":"#ff6622"}, {"text":"\\n"}, {"text":"Crate hosted by ", "color":"#ffffff"}, {"text":%q, "color":"#ff6622"}', kind, owner)

    if timeGone ~= 0 then
        e = e .. string.format(',{"text":"\\nDisappearing in ", "color":"#ffffff"}, {"text":%q, "color":"#ff6622"}, {"text":" seconds", "color":"#ffffff"}', math.floor((timeGone - world.getTime()) / 20))
    end

    return e .. "]"
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

    self.megaHealthGenerators = {

    }

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

        createEntityDataFromPing = function(id, location, kindIndex, validIn, timeGone, golden)
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
            text:setText(generateCrateTextFromData(kind, player:getName(), timeGone))
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
                textTask = text,
                modelRotation = math.random() * 360,
                crateRotation = math.random() * 360,
                damageCreator = creator,
                golden = golden,
                timeGone = timeGone
            }
        end,
        syncEntityArgs = {"default", "default", "default", "default", "default", "default"},
        createPingDataFromEntity = function(data)
            return data.id, data.location, crates[data.kind], data.validIn, data.timeGone, data.golden
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
                validIn = data.validIn,
                golden = data.golden,
                timeGone = data.timeGone
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

            tick = function(id, data)
                local shouldDispose = true
                if data.golden then
                    particles["dust 1 1 0 1"]
                        :pos(data.location + (util.unitRandom() - vec(0.5, 0, 0.5)) * vec(0.6, 0, 0.6))
                        :velocity(0, 0.1, 0)
                        :spawn()
                    shouldDispose = false
                end
                if data.timeGone ~= 0 then
                    data.textTask:setText(generateCrateTextFromData(data.kind, player:getName(), data.timeGone))
                    shouldDispose = false
                end
                return shouldDispose
            end
        },

        dispose = function(data)
            models.world:removeChild(data.groundModel)
            models.world:removeChild(data.crateModel)
        end
    }
end

function CrateSpawner:getAvailableCrates()
    return crates
end

function CrateSpawner:trySpawnCrate()
    self.tryingToSpawnCrates = self.tryingToSpawnCrates or math.random() > 0.99
    if not self.tryingToSpawnCrates then
        return
    end

    local candidates = {player:getPos():floor()}
    for _, complex in pairs(self.state.loadedTanks) do
        table.insert(candidates, complex.tank.pos)
    end

    local center = candidates[math.random(1, #candidates)]

    local place = randomCandidatePosition(center, 20, 5, 20)

    if not positionIsSupported(place) then
        return
    end

    local crateKindIndex = self:pickGenerationCrate(place)
    local crateKind = cratesIndexed[crateKindIndex]



    local thisDistance = 20
    
    if distanceFromOthers[crateKind] ~= nil then
        thisDistance = distanceFromOthers[crateKind](place)
    end
    for uuid, id, data in self.sharedWorldState:iterateAllEntities() do
        local kind = data.kind
        local otherDistance = 20
        if distanceFromOthers[kind] ~= nil then
            otherDistance = distanceFromOthers[kind](place)
        end
        local distance = math.min(thisDistance, otherDistance)
        if (data.location - place):length() < distance then
            return
        end
    end

    self:trySpawnCrateAfterPositionIsPicked(place, crateKindIndex)
end

function CrateSpawner:pickGenerationCrate(place)
    local size = 0
    local weights = {}
    for key, weightGen in pairs(cratesChances) do
        local o = weightGen(place)
        size = size + o
        table.insert(weights, {allowance = size, key = crates[key], s=key})
    end

    local selected = math.random(1, size)
    local kindIndex
    for i, thing in ipairs(weights) do
        if thing.allowance >= selected then
            kindIndex = thing.key
            break
        end
    end

    return kindIndex
end

function CrateSpawner:trySpawnCrateAfterPositionIsPicked(place, index)
    local golden = false
    local timeGone = 0
    if cratesIndexed[index] == "default:health" and math.random() > 0.9 then
        local moreCrate = 2
        local percentage = 0.3
        if math.random() > 0.9 then
            percentage = 0.05
        end
        while math.random() > percentage do
            moreCrate = moreCrate + 1
        end
        self.megaHealthGenerators[place] = moreCrate
        golden = true
        timeGone = world.getTime() + 500
    end

    self.sharedWorldState:newEntity(util.intID(), place, index, world.getTime() + 100, timeGone, golden)
    self.tryingToSpawnCrates = false
end

function CrateSpawner:trySpawnMegaHealthCrate(center)
    local place = randomCandidatePosition(center, 2, 2, 2)

    if not positionIsSupported(place) then
        return
    end

    self.sharedWorldState:newEntity(util.intID(), place, crates["default:health"], world.getTime() + 100, world.getTime() + 500, true)
    return true
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
            for i = 1, 5 do
                self:trySpawnCrate()
            end
            for id, crate in self.sharedWorldState:iterateOwnEntities() do
                if (crate.timeGone ~= 0 and crate.timeGone < world.getTime()) or not positionIsSupported(crate.location) then
                    self.unsupportedCrate(id)
                end
            end

            for i = 1, 5 do
                local key, value = next(self.megaHealthGenerators)

                if key ~= nil then
                    if self:trySpawnMegaHealthCrate(key) then
                        if value <= 1 then
                            self.megaHealthGenerators[key] = nil
                        else
                            self.megaHealthGenerators[key] = value - 1
                        end
                    end
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