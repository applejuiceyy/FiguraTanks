local class       = require("tank.class")
local util        = require("tank.util.util")
local collision   = require("tank.collision")


---@params Teleport Tank integer integer
local TeleportEffect = class("TeleportEffect")

function TeleportEffect:init(owner, tank, charges, id)
    self.owner = owner
    self.tank = tank
    self.id = id

    self.teleportLocation = nil
    self.cooldown = 1
    self.charges = charges

    self.teleportLocationIsDirty = false
    self.timeoutUntilNewTeleportLocation = 5
    self.publicTeleportLocation = tank.pos

    self.range = 10

    if host:isHost() then
        self.teleportLocationId = util.stringID()
        self.teleportLocationTask = models.world:newBlock(self.teleportLocationId)
    end
end

function TeleportEffect:isTeleportValid(pos)
    local highShape, lowShape = self.tank:getCollisionShape()

    if collision.collidesWithWorld(highShape + pos, lowShape + pos) then
        return false
    end

    if not collision.collidesWithWorld(highShape + pos - vec(0, 0.1, 0), lowShape + pos - vec(0, 0.1, 0)) then
        return false
    end

    return true
end

function TeleportEffect:rateTeleportLocation(pos)
    local mat = util.transform(
        matrices.zRotation4(-self.tank.nozzle.y),
        matrices.yRotation4(self.tank.nozzle.x + self.tank.angle),
        matrices.translate4(self.tank.pos + vec(0, 0.3, 0))
    )

    local l = mat:invert():apply(pos)

    local offsetness = math.abs(l.y) + math.abs(l.z)
    local farthness = l.x

    local base = (self.range - math.abs(self.range - farthness)) - offsetness

    if not collision.collidesWithWorld(pos, pos - vec(0, 0.1, 0)) then
        base = base / 1.5
    end

    return base
end

function TeleportEffect:afterApply()
    self:showRange()
end


function TeleportEffect:showRange()
    host:setActionbar("optimal range is set to " .. self.range .. " blocks")
end

function TeleportEffect:tick()
    self.cooldown = self.cooldown - 0.02
    if self.cooldown < 0 then
        self.cooldown = 0
    end
    if host:isHost() then
        if self.teleportLocation ~= nil and not self:isTeleportValid(self.teleportLocation) then
            self.teleportLocation = nil
        end

        if self.tank.controller:isPressed(self.owner.rangeUp) ~= self.tank.controller:isPressed(self.owner.rangeDown) then
            if self.tank.controller:isPressed(self.owner.rangeUp) then
                self.range = self.range + 0.1
                self.range = math.min(self.range, 20)
            else
                self.range = self.range - 0.1
                self.range = math.max(self.range, 5)
            end
            self:showRange()
        end

        local mat = util.transform(
            matrices.zRotation4(-self.tank.nozzle.y),
            matrices.yRotation4(self.tank.nozzle.x + self.tank.angle),
            matrices.translate4(self.tank.pos + vec(0, 0.3, 0))
        )

        local trueBest = mat:apply(self.range, 0, 0)
        trueBest.y = math.floor(trueBest.y)
        self:testPotentialPosition(trueBest)

        if self.teleportLocation ~= nil then
            for i = 0, 20 do
                local pos = self.teleportLocation + vec(math.random() - 0.5, 0, math.random() - 0.5)
                self:testPotentialPosition(pos)
            end
        end

        local pos = mat:apply((util.unitRandom() - vec(0, 0.5, 0.5)) * vec(self.range + 10, 2, 2) + vec(math.max(0, self.range - 10), 0, 0))
        pos.y = math.floor(pos.y)
        self:testPotentialPosition(pos)

        if self.teleportLocation ~= nil then
            self.teleportLocationTask:block("purple_concrete")
            :setMatrix(
                util.transform(
                    matrices.translate4(-8, 0, -8),
                    matrices.scale4(0.7, 0.02, 0.7),
                    matrices.translate4(self.teleportLocation * 16),
                    matrices.mat4() * math.min(1, 1 / (self.teleportLocation - client.getCameraPos()):length()) * 0.1
                )
            )
        else
            self.teleportLocationTask:block("gray_concrete")
        end

        if self.teleportLocation ~= nil and self.cooldown <= 0 and self.tank.controller:isPressed(self.tank.controlRepo.ability) then
            self.owner.teleport(self.tank, self.teleportLocation, self.id)
        end

        self.timeoutUntilNewTeleportLocation = self.timeoutUntilNewTeleportLocation - 1

        if self.teleportLocation ~= nil and self.timeoutUntilNewTeleportLocation < 0 and self.teleportLocationIsDirty then
            self.owner.teleportPosition(self.tank, self.teleportLocation, self.id)
            self.timeoutUntilNewTeleportLocation = 5
            self.teleportLocationIsDirty = false
        end
    end
end

function TeleportEffect:testPotentialPosition(pos)
    if not self:isTeleportValid(pos) then
        return
    end

    if self.teleportLocation == nil or self:rateTeleportLocation(self.teleportLocation) < self:rateTeleportLocation(pos) then
        self.teleportLocation = pos
        self.teleportLocationIsDirty = true
    end
end

function TeleportEffect:shouldBeKept()
    return true
end

function TeleportEffect:populateSyncQueue(consumer)
    consumer(function()
        if self.tank:hasEffect(self.id) then
            self.owner.equip(self.tank, self.charges, self.id)
        end
    end)
end

function TeleportEffect:generateIconGraphics(group)
    self.owner:generateIconGraphics(group)
    local bar = group:newBlock("bar"):block("redstone_block")
    return {
        tick = function()
            bar:setMatrix(
                util.transform(
                    matrices.translate4(-8, 0, 0.5),
                    matrices.scale4(1 - self.cooldown, self.charges / 4, 0.01),
                    matrices.translate4(0, -8, 0)
                )
            )
        end
    }
end

function TeleportEffect:dispose()
    models.world:removeTask(self.teleportLocationId)
end

function TeleportEffect:specifyModel(model)
    if model.isHUD then
        return
    end

    return {
        tick = function()
            for i = 1, 2 do
                particles:newParticle("portal", vectors.rotateAroundAxis(math.random() * 360, vec(1, 0, 0), vec(0, 1, 0)) + self.tank.pos)
            end
            if not model.focused and self.publicTeleportLocation ~= nil then
                particles:newParticle("firework", self.tank.pos + util.xzCenteredUnitRandom() * vec(0.7, 0.5, 0.7))
                    :velocity((self.publicTeleportLocation - self.tank.pos) / 10)
                    :gravity(0)
                    :physics(false)
                    :scale(0.7)
                    :color(0.6, 0, 1)
            end
        end
    }
end

return TeleportEffect