local Event     = require("tank.events.Event")
local collision = require("tank.collision")
local class     = require("tank.class")
local settings  = require("tank.settings")
local Control   = require("tank.host.controller.Control")
local util      = require("tank.util.util")


---@params ControlRepo {specifyTank:fun(...:any):any}[]
local Tank      = class("Tank")

local waterlogs = {
    ["minecraft:water"] = true,
    ["minecraft:help"] = true,
    ["minecraft:kelp_plant"] = true,
    ["minecraft:tall_seagrass"] = true,
    ["minecraft:seagrass"] = true
}

local overrideVelocityMultiplier = {
    ["minecraft:slime_block"] = 0.2,
    ["minecraft:white_concrete"] = 1.3,
    ["minecraft:sand"] = 0.4
}

local function includes(t, v)
    for _, k in pairs(t) do if k == v then return true end end return false
end

local function blocksWithFluid(fluid)
    return function(block)
        local fluids = block:getFluidTags()

        if not includes(fluids, fluid) then
            return {}
        end

        if block.properties == nil or tonumber(block.properties.level) == nil or block.properties.level == "8" or block.properties.waterlogged == "true" then
            return {{vec(0, 0, 0), vec(1, 1, 1)}}
        end

        return {{vec(0, 0, 0), vec(1, 1 - tonumber(block.properties.level) / 8, 1)}}
    end
end



local function collides(highCollisionShape, lowCollisionShape, climbBudget, originalPos, currentPos, vel)
    local coliding = nil
    local shape = nil

    local movedPos = currentPos + vel

    local block, collider = collision.collidesWithWorld(movedPos + highCollisionShape, movedPos + lowCollisionShape)

    if block then
        local requiredClimbing = (collider[2].y + block:getPos().y) - currentPos.y

        if climbBudget ~= 0 and requiredClimbing ~= 0 and requiredClimbing <= climbBudget then
            local remainingClimbing = requiredClimbing
            local climbingPos = currentPos
            local allowsClimbing = true

            while remainingClimbing > 0 do
                local thisClimbingState = math.min(0.5, remainingClimbing)
                remainingClimbing = remainingClimbing - thisClimbingState

                climbingPos = climbingPos + vec(0, thisClimbingState, 0)

                if collision.collidesWithWorld(climbingPos + highCollisionShape, climbingPos + lowCollisionShape, nil, vec(0, 0, 0), vec(0, 0, 0)) then
                    allowsClimbing = false
                    break
                end
            end

            if allowsClimbing then
                return collides(highCollisionShape, lowCollisionShape, climbBudget - requiredClimbing, originalPos, climbingPos, vel)
            end
            return originalPos, block, collider
        else
            return originalPos, block, collider
        end
    end

    if not coliding then
        currentPos = movedPos
    end

    return currentPos, coliding, shape
end



function Tank:init(controlRepo, managers)
    self.pos = vec(0, 0, 0)
    self.angle = 0
    self.nozzle = vec(0, 0)

    self:flushLerps()

    self.vel = vec(0, 0, 0)
    self.anglevel = 0

    self.health = 100
    self.fire = -1

    self.charge = 1
    self.dash = 1
    self.dashing = false

    self.controlRepo = controlRepo
    self.controller = Control:new(controlRepo)

    self.onDeath = Event:new()
    self.onDash = Event:new()
    self.onEffectsModified = Event:new()
    self.onDamage = Event:new()

    self.effects = {}
    self.tankManagers = {}

    for _, manager in pairs(managers) do
        local r = util.callOn(manager, "specifyTank", self)
        if r ~= nil then
            table.insert(self.tankManagers, r)
        end
    end
end
---@param vid integer
---@param effect Effect
function Tank:addEffect(vid, effect)
    util.callOn(effect, "beforeApply", self)
    self.effects[vid] = effect
    util.callOn(effect, "afterApply", self)
    self.onEffectsModified:fire(vid, effect)
    print("adding effect")
end

function Tank:hasEffect(vid)
    return self.effects[vid] ~= nil
end

function Tank:hasEffectByName(name)
    return not not self:getEffectByName(name)
end

function Tank:getEffectByName(name)
    for id, effect in pairs(self.effects) do
        if name == effect.name then
            return id
        end
    end
end

function Tank:removeEffect(vid)
    util.callOn(self.effects[vid], "dispose")
    self.onEffectsModified:fire(vid, effect)
    self.effects[vid] = nil
    print("removing effect")
end

function Tank:takeDamage(damage)
    self.health = self.health - damage
    if self.health < 0 then
        self.health = 0
    end
end

function Tank:isDead()
    return self.health <= 0
end

function Tank:flushLerps()
    self.oldpos = self.pos:copy()
    self.oldangle = self.angle
    self.oldnozzle = self.nozzle
end

function Tank:moveVertically()
    local highCollisionShape, lowCollisionShape = self:getCollisionShape()

    local friction, speedMultiplier, ground

    local old = self.pos
    local block, shape
    self.pos, block, shape = collides(highCollisionShape, lowCollisionShape, 0, self.pos, self.pos, self.vel._y_)

    if block then
        friction = block:getFriction()
        speedMultiplier = overrideVelocityMultiplier[block.id] or block:getVelocityMultiplier()
        ground = block

        if self.vel.y < 0 then
            self.pos.y = shape[2].y + block:getPos().y
            if collision.collidesWithWorld(self.pos + highCollisionShape, self.pos + lowCollisionShape) then
                self.pos = old
            end
        else
            self.pos = old
        end
        self.health = self.health + math.min(0, (self.vel.y + 1) * 100)
        self.vel.y = 0
    else
        friction = 1
        speedMultiplier = 1
    end

    return self:invokeInterested("MoveVertically", friction, speedMultiplier, ground)
end

function Tank:moveHorizontally()
    local highCollisionShape, lowCollisionShape = self:getCollisionShape()
    local block

    self.pos, block = collides(highCollisionShape, lowCollisionShape, 1.2, self.pos, self.pos, self.vel.x__)
    if block then
        self.vel.x = 0
    end

    self.pos, block = collides(highCollisionShape, lowCollisionShape, 1.2, self.pos, self.pos, self.vel.__z)
    if block then
        self.vel.z = 0
    end

    self:invokeInterested("MoveHorizontally")
end

function Tank:takeDamageFromBlocks()
    if self:collidesWithWorld(blocksWithFluid("minecraft:water")) then
        self.vel = self.vel * 0.4
        self.health = self.health - 1
        self.fire = math.max(self.fire - 10, -1)
    elseif self:collidesWithWorld(blocksWithFluid("minecraft:lava")) then
        self.vel = self.vel * 0.01
        self.health = self.health - 2
        self.fire = self.fire + 5
    end

    if self:collidesWithWorld(function(block)
        if block.id == "minecraft:fire" then
            return block:getOutlineShape()
        end
        return {}
    end) then
        self.fire = self.fire + 2
        self.health = self.health - 1
    end
    if self.fire > -1 then
        self.fire = self.fire - 1
        self.health = self.health - 0.5
    end

    return fluid
end

function Tank:collidesWithWorld(shapeGetter)
    local highCollisionShape, lowCollisionShape = self:getCollisionShape()
    return collision.collidesWithWorld(self.pos + highCollisionShape, self.pos + lowCollisionShape, shapeGetter)
end

function Tank:avoidSuffocation()
    if self:collidesWithWorld() then
        self.pos.y = self.pos.y + 0.1
    end
end

function Tank:takeVoidDamage()
    if self.pos.y < -70 then
        self.health = self.health - 5
    end
end

function Tank:fetchControls()
    local targetVelocity = vec(0, 0, 0)
    local targetAngleMomentum = 0
    local nozzleMomentum = vec(0, 0)

    if not self.dead then
        if self.controller:isPressed(self.controlRepo.forwards) then
            targetVelocity = targetVelocity + vectors.rotateAroundAxis(self.angle, vec(0.2, 0, 0), vec(0, 1, 0))
        end

        if self.controller:isPressed(self.controlRepo.backwards) then
            targetVelocity = targetVelocity - vectors.rotateAroundAxis(self.angle, vec(0.2, 0, 0), vec(0, 1, 0))
        end

        local direction = 1
        if settings.backwardsInvertControls and self.controller:isPressed(self.controlRepo.backwards) and not self.controller:isPressed(self.controlRepo.forwards) then
            direction = -1
        end

        if self.controller:isPressed(self.controlRepo.left) then
            targetAngleMomentum = targetAngleMomentum + 5 * direction
        end

        if self.controller:isPressed(self.controlRepo.right) then
            targetAngleMomentum = targetAngleMomentum - 5 * direction
        end
        if self.controller:isPressed(self.controlRepo.nozzleup) then
            nozzleMomentum.y = nozzleMomentum.y - 2
        end
        if self.controller:isPressed(self.controlRepo.nozzledown) then
            nozzleMomentum.y = nozzleMomentum.y + 2
        end
        if self.controller:isPressed(self.controlRepo.nozzleleft) then
            nozzleMomentum.x = nozzleMomentum.x + 2
        end
        if self.controller:isPressed(self.controlRepo.nozzleright) then
            nozzleMomentum.x = nozzleMomentum.x - 2
        end

        if self.controller:isPressed(self.controlRepo.dash) and self.dash >= 1 then
            self.dashing = true
            self.onDash:fire()
        end
    end

    return self:invokeInterested("FetchControls", targetVelocity, targetAngleMomentum, nozzleMomentum)
end

function Tank:invokeInterested(name, ...)
    return self:invokeRawInterested("tank" .. name .. "Invoked", ...)
end

function Tank:invokeRawInterested(name, ...)
    local stuff = {...}

    for _, manager in pairs(self.tankManagers) do
        if manager[name] ~= nil then
            stuff = {manager[name](manager, table.unpack(stuff))}
        end
    end
    for _, effect in pairs(self.effects) do
        if effect[name] ~= nil then
            stuff = {effect[name](effect, table.unpack(stuff))}
        end
    end

    return table.unpack(stuff)
end

function Tank:tick()
    self:flushLerps()

    self.charge = math.min(self.charge + 0.1, 1)

    self.vel.y = self.vel.y - 0.05
    local friction, speedMultiplier, ground = self:moveVertically()

    self:takeDamageFromBlocks()
    self:takeVoidDamage()
    self:avoidSuffocation()

    if self.dashing then
        speedMultiplier = speedMultiplier * (self.dash * 5 + 1)
    end

    local targetVelocity, targetAngleMomentum, nozzleMomentum = self:fetchControls()
    self:invokeRawInterested("tick")

    if speedMultiplier > 1 then
        targetVelocity = targetVelocity * speedMultiplier
        speedMultiplier = 1
    end

    if self.health < 10 then
        targetVelocity = targetVelocity * (self.health / 20 + 0.5)
    end

    if self.dashing then
        self.dash = self.dash - 0.1
        if self.dash <= 0 then
            self.dashing = false
        end
    else
        self.dash = self.dash + 0.008
    end
    self.dash = math.clamp(self.dash, 0, 1)

    local velocity = self.vel:length()
    local inverseFriction = 1 - friction
    inverseFriction = inverseFriction / math.pow(velocity + 1, 2)
    friction = 1 - inverseFriction
    local onlyFriction = math.lerp(targetVelocity * speedMultiplier, self.vel, friction)
    self.vel.x_z = onlyFriction

    self:moveHorizontally()

    self.anglevel = math.lerp(targetAngleMomentum * speedMultiplier, self.anglevel, friction)

    self.nozzle = self.nozzle + nozzleMomentum
    self.nozzle.y = math.clamp(self.nozzle.y, -80, 80)

    self.angle = self.angle + self.anglevel


    if not self.dead then
        if self.health <= 0 then
            self.dead = true
            self.onDeath:fire()
        end
    else
        self.health = 0
    end

    for vid, effect in pairs(self.effects) do
        if not util.callOn(effect, "shouldBeKept") then
            self:removeEffect(vid)
        end
    end

    return {
        friction = friction,
        speedMultiplier = speedMultiplier,
        targetVelocity = targetVelocity,
        targetAngleMomentum = targetAngleMomentum,
        ground = ground
    }
end

function Tank:serialise()
    return self.pos, self.vel, self.angle, self.anglevel, self.health, self.nozzle, self.fire
end

function Tank:serialiseCritical()
    return self.pos, self.vel, self.health, self.fire
end

function Tank:apply(pos, vel, angle, anglevel, health, nozzle, fire)
    self.pos = pos
    self.vel = vel
    self.angle = angle
    self.anglevel = anglevel
    self.health = health
    self.nozzle = nozzle
    self.fire = fire
end

function Tank:applyCritical(pos, vel, health, fire)
    self.pos = pos
    self.vel = vel
    self.health = health
    self.fire = fire
end

function Tank:getCollisionShape()
    return vec(0.3, 0.5, 0.3), vec(-0.3, 0, -0.3)
end

function Tank:dispose()
    for _, effect in pairs(self.effects) do
        util.callOn(effect, "dispose")
    end
end

return Tank