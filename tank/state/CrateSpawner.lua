local class     = require("tank.class")
local util      = require("tank.util")
local collision = require("tank.collision")

local CrateSpawner     = class("CrateSpawner")

local crates = {
    ["default:speed"] = function(self, tank)
        self.state.itemManagers["default:speed"]:apply(tank)
    end
}

local cratesIndexed = {}

for key in pairs(crates) do
    table.insert(cratesIndexed, key)
end

CrateSpawner.requiredPings = {
    spawnCrate = function(self, ...)
        self:spawnCrate(...)
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

    self.state = state
    self.currentlyAnimatedCrates = {}
    self.currentCrates = {}
    self.publicFacingCrates = {}

    self.tankReachedCrate = {}
    self.tankReachedCrateAcknowledgement = {}

    self.awaitingCrateAcknowledgement = {}

    self.potentialPos = nil
    self.currentScanningPlayerUUID = nil
    self.currentScanningCratePos = nil
end

function CrateSpawner:trySpawnCrate()
    if self.potentialPos == nil then
        local x = math.random(-20, 20)
        local y = math.random(-20, 20)
        local z = math.random(-20, 20)

        local center = player:getPos():floor()

        if self.state.load ~= nil and math.random() > 0.5 then
            center = self.state.load.tank.pos:copy():floor()
        end

        local place = vec(x, y, z) + center

        if world.getBlockState(place):isAir() and world.getBlockState(place - vec(0, 1, 0)):isFullCube() then
            self.potentialPos = place
            self.currentScanningCratePos = nil
            self.currentScanningPlayerUUID = nil
        end
    else
        --[[
        for uuid, stuff in pairs(world.avatarVars()) do
            if stuff.__FiguraTanks_crates ~= nil then
                for _, crate in ipairs(stuff.__FiguraTanks_crates) do
                    if (crate.location - self.potentialPos):length() < 5 then
                        self.potentialPos = nil
                    end
                end
            end
        end
        ]]

        local avatarVars = world.avatarVars()
        local nextvalue, stuff = next(avatarVars, self.currentScanningPlayerUUID)

        if stuff ~= nil and stuff.__FiguraTanks_crates ~= nil then
            local value
            self.currentScanningCratePos, value = next(stuff.__FiguraTanks_crates, self.currentScanningCratePos)

            if self.currentScanningCratePos == nil then
                self.currentScanningPlayerUUID = nextvalue
            else
                if (value.location - self.potentialPos):length() < 10 then
                    self.potentialPos = nil
                end
            end
        else
            self.currentScanningPlayerUUID = nextvalue
        end

        if nextvalue == nil then
            local kindIndex = math.random(1, #cratesIndexed)
            self.pings.spawnCrate(self.potentialPos, kindIndex)
            self.potentialPos = nil
        end
    end
end

function CrateSpawner:spawnCrate(location, kindIndex)
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
    local s = util.serialisePos(location)

    self.currentCrates[s] = {
        location = location,
        kind = kind,
        groundModel = icon,
        crateModel = crate,
        spawned = world.getTime(),
        modelRotation = math.random() * 360
    }

    self.publicFacingCrates[s] = {
        location = location,
        kind = kind,
        validIn = world.getTime() + 100
    }

    self.currentlyAnimatedCrates[s] = true

    avatar:store("__FiguraTanks_crates", self.publicFacingCrates)
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

function CrateSpawner:tick()
    self:trySpawnCrate()

    local myUUID = player:getUUID()
    local vars = world.avatarVars()

    if self.state.load ~= nil then
        local tank = self.state.load.tank
        local highCollisionShape, lowCollisionShape = tank:getCollisionShape()
        for otherUUID, stuff in pairs(vars) do
            if stuff.__FiguraTanks_crates ~= nil then
                for str, data in pairs(stuff.__FiguraTanks_crates) do
                    if (
                        self.awaitingCrateAcknowledgement[otherUUID] == nil or
                        self.awaitingCrateAcknowledgement[otherUUID][util.serialisePos(data.location)] == nil
                    ) and
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
                        self.pings.tankReachedCrate(otherUUID, data.location)
                    end
                end
            end
        end
    end

    for _, stuff in ipairs(self.currentCrates) do
        particles:newParticle("dust 1 1 1 1", stuff.location + vec(0.5, 0.5, 0.5))
    end
    if self.potentialPos ~= nil then
        particles:newParticle("dust 1 0 0 1", self.potentialPos + vec(0.5, 0.5, 0.5))
    end

    for otherUUID, stuff in pairs(vars) do
        if stuff.__FiguraTanks_tankReachedCrate ~= nil then
            for crateOwnerUUID, crateData in pairs(stuff.__FiguraTanks_tankReachedCrate) do
                if crateOwnerUUID == otherUUID then
                    for _, pos in pairs(crateData) do
                        self.pings.tankReachedCrateAcknowledgement(otherUUID, pos)
                    end
                end
            end
        end
    end

    for crateOwnerUUID, ccrates in pairs(self.awaitingCrateAcknowledgement) do
        if vars[crateOwnerUUID] == nil then
            self.awaitingCrateAcknowledgement[crateOwnerUUID] = nil
        elseif vars[crateOwnerUUID].__FiguraTanks_tankReachedCrateAcknowledgment ~= nil then
            local acknowledgements = vars[crateOwnerUUID].__FiguraTanks_tankReachedCrateAcknowledgment[myUUID]
            if acknowledgements ~= nil then
                for st, data in pairs(ccrates) do
                    if acknowledgements[st] ~= nil then
                        crates[data.kind](self, self.state.load.tank)
                    end
                end
            end
        end
    end
end

function CrateSpawner:render()
    for pos in pairs(self.currentlyAnimatedCrates) do
        local privateCrate = self.currentCrates[pos]
        local since = world.getTime() - privateCrate.spawned

        if since >= 100 then
            privateCrate.crateModel:matrix(matrices.translate4(privateCrate.location * 16 + vec(8, 0, 8)))
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