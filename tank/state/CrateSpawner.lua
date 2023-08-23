local class     = require("tank.class")
local util      = require("tank.util")
local collision = require("tank.collision")

local CrateSpawner     = class("CrateSpawner")

local crates = {
    ["default:health"] = true,
    ["default:speed"] = true,
    ["default:friction"] = true
}

local cratesIndexed = {}

for key in pairs(crates) do
    table.insert(cratesIndexed, key)
---@diagnostic disable-next-line: assign-type-mismatch
    crates[key] = #cratesIndexed
end

CrateSpawner.requiredPings = {
    syncCrate = function(self, ...)
        self:syncCrate(...)
    end,

    deleteCrate = function(self, pos)
        self:deleteCrate(pos)
    end,

    tankReachedCrateAcknowledgement = function (self, avatarId, pos)
        if self.tankReachedCrateAcknowledgement[avatarId] == nil then
            self.tankReachedCrateAcknowledgement[avatarId] = {}
        end
        self.tankReachedCrateAcknowledgement[avatarId][util.serialisePos(pos)] = pos
        self:deleteCrate(pos)
    end,

    tankReachedCrate = function(self, avatarId, pos)
        if self.tankReachedCrate[avatarId] == nil then
            self.tankReachedCrate[avatarId] = {}
        end
        self.tankReachedCrate[avatarId][util.serialisePos(pos)] = pos
    end
}

function CrateSpawner:init(pings, state)
    self.pings = pings

    self.tryingToSpawnCrates = false

    self.state = state
    self.currentlyAnimatedCrates = {}
    self.currentCrates = {}
    self.publicFacingCrates = {}

    self.tankReachedCrate = {}
    self.tankReachedCrateAcknowledgement = {}

    self.awaitingCrateAcknowledgement = {}
end

function CrateSpawner:trySpawnCrate()
    self.tryingToSpawnCrates = self.tryingToSpawnCrates or math.random() > 0.99
    if not self.tryingToSpawnCrates then
        return
    end

    local x = math.random(-20, 20)
    local y = math.random(-5, 5)
    local z = math.random(-20, 20)

    local center = player:getPos():floor()

    if self.state.load ~= nil and math.random() > 0.5 then
        center = self.state.load.tank.pos:copy():floor()
    end

    local place = vec(x, y, z) + center



    if not (world.getBlockState(place):isAir() and world.getBlockState(place - vec(0, 1, 0)):isFullCube()) then
        return
    end

    for uuid, stuff in pairs(world.avatarVars()) do
        if stuff.__FiguraTanks_crates ~= nil then
            for _, crate in pairs(stuff.__FiguraTanks_crates) do
                if (crate.location - place):length() < 20 then
                    return
                end
            end
        end
    end


    local kindIndex = math.random(1, #cratesIndexed)
    self.pings.syncCrate(place, kindIndex, world.getTime())
    self.tryingToSpawnCrates = false
end

function CrateSpawner:syncCrate(location, kindIndex, validIn)
    local s = util.serialisePos(location)
    if self.currentCrates[s] then
        return
    end
    local kind = cratesIndexed[kindIndex]
    local icon = self.state.itemManagers[kind]:generateIconGraphics()
    models.world:addChild(icon)
    icon:matrix(
        util.transform(
            matrices.rotation4(90, 0, 0),
            matrices.scale4(0.7, 0.7, 0.7),
            matrices.translate4(location * 16),
            matrices.translate4(8, 0.01, 8)
        )
    )

    local crate = util.group()
    crate:newBlock("e"):block("barrel[facing=up]"):matrix(util.transform(
        matrices.translate4(-8, 0, -8),
        matrices.scale4(0.6, 0.8, 0.6)
    ))
    models.world:addChild(crate)


    self.currentCrates[s] = {
        location = location,
        kind = kind,
        groundModel = icon,
        crateModel = crate,
        spawned = validIn,
        modelRotation = math.random() * 360
    }

    self.publicFacingCrates[s] = {
        location = location,
        kind = kind,
        validIn = validIn + 100
    }

    self.currentlyAnimatedCrates[s] = true

    avatar:store("__FiguraTanks_crates", self.publicFacingCrates)
end

function CrateSpawner:populateSyncQueue(consumer)
    for i, crate in pairs(self.currentCrates) do
        local against = crate.spawned
        consumer(function()
            if self.currentCrates[i] ~= nil and self.currentCrates[i].spawned == against then
                self.pings.syncCrate(crate.location, crates[crate.kind], crate.spawned)
            end
        end)
    end
end

function CrateSpawner:deleteCrate(location)
    local s = util.serialisePos(location)
    if self.currentCrates[s] ~= nil then
        self.currentlyAnimatedCrates[s] = nil
        models.world:removeChild(self.currentCrates[s].groundModel)
        models.world:removeChild(self.currentCrates[s].crateModel)
        self.currentCrates[s] = nil
        self.publicFacingCrates[s] = nil
        avatar:store("__FiguraTanks_crates", self.publicFacingCrates)
    end
end

function CrateSpawner:testCrateReach()
    local vars = world.avatarVars()
    local tank = self.state.load.tank
    local highCollisionShape, lowCollisionShape = tank:getCollisionShape()
    for otherUUID, stuff in pairs(vars) do
        if stuff.__FiguraTanks_crates ~= nil then
            for str, data in pairs(stuff.__FiguraTanks_crates) do
                if (
                    self.awaitingCrateAcknowledgement[otherUUID] == nil or
                    self.awaitingCrateAcknowledgement[otherUUID][util.serialisePos(data.location)] == nil
                )

                and

                data.validIn < world.getTime()

                and

                collision.collidesWithRectangle(
                    highCollisionShape + tank.pos,
                    lowCollisionShape + tank.pos,
                    data.location + vec(0.8, 0.8, 0.8),
                    data.location + vec(0.2, 0, 0.2)
                ) then
                    if self.awaitingCrateAcknowledgement[otherUUID] == nil then
                        self.awaitingCrateAcknowledgement[otherUUID] = {}
                    end
                    self.awaitingCrateAcknowledgement[otherUUID][util.serialisePos(data.location)] = {
                        location = data.location,
                        kind = data.kind
                    }
                    print(string.format("Sending tank reach to crate %q from %q", data.kind, world.getEntity(otherUUID):getName()))
                    self.pings.tankReachedCrate(otherUUID, data.location)
                end
            end
        end
    end
end

function CrateSpawner:sendCrateReachAcknowledgments()
    local vars = world.avatarVars()
    for otherUUID, stuff in pairs(vars) do
        if stuff.__FiguraTanks_tankReachedCrate ~= nil and stuff.__FiguraTanks_tankReachedCrate[player:getUUID()] ~= nil then
            for _, pos in pairs(stuff.__FiguraTanks_tankReachedCrate[player:getUUID()]) do
                print(string.format("Acknowledging tank's %q reach to crate", world.getEntity(otherUUID):getName()))
                self.pings.tankReachedCrateAcknowledgement(otherUUID, pos)
            end
        end
    end
end

function CrateSpawner:applyCrateAcknowledgementEffects()
    local myUUID = player:getUUID()
    local vars = world.avatarVars()
    for crateOwnerUUID, ccrates in pairs(self.awaitingCrateAcknowledgement) do
        if vars[crateOwnerUUID] == nil then
            self.awaitingCrateAcknowledgement[crateOwnerUUID] = nil
        elseif vars[crateOwnerUUID].__FiguraTanks_tankReachedCrateAcknowledgment ~= nil then
            local acknowledgements = vars[crateOwnerUUID].__FiguraTanks_tankReachedCrateAcknowledgment[myUUID]
            if acknowledgements ~= nil then
                for st, data in pairs(ccrates) do
                    if acknowledgements[st] ~= nil then
                        print(string.format("Applying effect %q from %q", data.kind, world.getEntity(crateOwnerUUID):getName()))
                        self:applyEffect(crateOwnerUUID, data.kind)
                        self.awaitingCrateAcknowledgement[crateOwnerUUID][st] = nil
                        if next(self.awaitingCrateAcknowledgement[crateOwnerUUID]) == nil then
                            self.awaitingCrateAcknowledgement[crateOwnerUUID] = nil
                        end
                    end
                end
            end
        end
    end
end

function CrateSpawner:applyEffect(owner, id)
    if not crates[id] then
        host:setActionbar(
            string.format(
                '[{"text":"Unknown item "}, {"text":%q, "color":"#ff6622"}, {"text": ", maybe "}, {"text":%q, "color":"#ff6622"}, {"text":" has a custom item?"}]',
                id, world.getEntity(owner):getName()
            )
        )
        return
    end
    
    self.state.itemManagers[id]:apply(self.state.load.tank)
end

function CrateSpawner:tick()
    for i = 0, 10 do
        self:trySpawnCrate()
    end

    if self.state.load ~= nil then
        self:testCrateReach()
    end
    self:sendCrateReachAcknowledgments()
    self:applyCrateAcknowledgementEffects()
end

function CrateSpawner:render()
    for pos in pairs(self.currentlyAnimatedCrates) do
        local privateCrate = self.currentCrates[pos]
        local since = world.getTime() - privateCrate.spawned

        if since >= 99 then
            privateCrate.crateModel:matrix(matrices.translate4(privateCrate.location * 16 + vec(8, 0.1, 8)))
            local id = world.getBlockState(privateCrate.location - vec(0, 1, 0)).id
            pcall(function()
                for i = 0, 40 do
                    particles:newParticle("block " .. id, privateCrate.location + vec(0.5, 0, 0.5), vec(math.random() * 100 - 50, math.random() * 100 - 50, math.random() * 100 - 50))
                end
            end)
            self.currentlyAnimatedCrates[pos] = nil
        else
            privateCrate.crateModel:matrix(
                util.transform(
                    matrices.translate4(0, (100 - since - client.getFrameTime()) * 30, 0),
                    matrices.rotation4(0, privateCrate.modelRotation, 0),
                    matrices.rotation4(10, 0, 0),
                    matrices.rotation4(0, -privateCrate.modelRotation, 0),
                    matrices.translate4(privateCrate.location * 16 + vec(8, 0, 8))
                )
            )
        end
    end
end

function CrateSpawner:tickNonHost()
    avatar:store("__FiguraTanks_tankReachedCrate", self.tankReachedCrate)
    avatar:store("__FiguraTanks_tankReachedCrateAcknowledgment", self.tankReachedCrateAcknowledgement)

    self.tankReachedCrate = {}
    self.tankReachedCrateAcknowledgement = {}
end



return CrateSpawner