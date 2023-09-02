local Event     = require("tank.events.events")
local collision = require("tank.collision")
local class     = require("tank.class")

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
    ["minecraft:white_concrete"] = 1.3
}

local function getFluid(block, y)
    local fluids = block:getFluidTags()
    if #fluids > 0 then
        if block.properties == nil or block.properties == nil or tonumber(block.properties.level) == nil or block.properties.level == "8" or y < (1 - tonumber(block.properties.level) / 8) then
            return fluids
        end
    end
    return {}
end

local function includes(t, v)
    for _, k in pairs(t) do if k == v then return true end end return false
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

                if collision.collidesWithWorld(climbingPos + highCollisionShape, climbingPos + lowCollisionShape, vec(0, 0, 0), vec(0, 0, 0)) then
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




function Tank:init(weaponHandler)
    self.pos = vec(0, 0, 0)
    self.angle = 0
    self.nozzle = vec(0, 0)

    self:flushLerps()

    self.vel = vec(0, 0, 0)
    self.anglevel = 0

    self.health = 100
    self.fire = -1

    self.dead = false
    self.charge = 1
    self.dash = 1
    self.dashing = false

    self.controller = setmetatable({}, {__index = function() return false end})
    self.weaponHandler = weaponHandler

    self.onDeath = Event:new()
    self.onDash = Event:new()

    self.currentWeapon = nil
    self.effects = {}
end

function Tank:addEffect(vid, effect)
    self.effects[vid] = effect
end

function Tank:hasEffect(vid)
    return self.effects[vid] ~= nil
end

function Tank:setWeapon(gunFactory)
    if self.currentWeapon ~= nil then
        self.currentWeapon:tankWeaponDispose()
    end
    self.currentWeapon = gunFactory
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
        friction = 0.9
        speedMultiplier = 1
    end

    return self:invokeInterested("MoveVertically", friction, speedMultiplier, ground)
end

function Tank:moveHorizontally()
    local highCollisionShape, lowCollisionShape = self:getCollisionShape()

    self.pos, block, shape = collides(highCollisionShape, lowCollisionShape, 1.2, self.pos, self.pos, self.vel.x__)
    if block then
        self.vel.x = 0
    end

    self.pos, block, shape = collides(highCollisionShape, lowCollisionShape, 1.2, self.pos, self.pos, self.vel.__z)
    if block then
        self.vel.z = 0
    end

    self:invokeInterested("MoveHorizontally")
end

function Tank:handleWeaponDamages()
    return self:invokeInterested("HandleWeaponDamages", self.weaponHandler())
end

function Tank:takeDamageFromBlocks()
    local fluid = getFluid(world.getBlockState(self.pos), self.pos.y - math.floor(self.pos.y))
    if includes(fluid, "c:water") then
        self.vel = self.vel * 0.4
        self.health = self.health - 1
        self.fire = math.max(self.fire - 10, -1)
    elseif includes(fluid, "c:lava") then
        self.vel = self.vel * 0.01
        self.health = self.health - 2
        self.fire = self.fire + 5
    end

    if world.getBlockState(self.pos).id == "minecraft:fire" then
        self.fire = self.fire + 2
        self.health = self.health - 1
    end

    if self.fire > -1 then
        self.fire = self.fire - 1
        self.health = self.health - 0.5
    end

    return fluid
end

function Tank:avoidSuffocation()
    local highCollisionShape, lowCollisionShape = self:getCollisionShape()
    if collision.collidesWithWorld(self.pos + highCollisionShape, self.pos + lowCollisionShape) then
        self.pos.y = self.pos.y + 0.1
    end
end

function Tank:takeVoidDamage()
    if self.pos.y < -60 then
        self.health = self.health - 5
    end
end

function Tank:fetchControls()
    local targetVelocity = vec(0, 0, 0)
    local targetAngleMomentum = 0
    local nozzleMomentum = vec(0, 0)

    if not self.dead then
        if self.controller.forwards then
            targetVelocity = targetVelocity + vectors.rotateAroundAxis(self.angle, vec(0.2, 0, 0), vec(0, 1, 0))
        end

        if self.controller.backwards then
            targetVelocity = targetVelocity - vectors.rotateAroundAxis(self.angle, vec(0.2, 0, 0), vec(0, 1, 0))
        end

        if self.controller.left then
            targetAngleMomentum = targetAngleMomentum + 5
        end

        if self.controller.right then
            targetAngleMomentum = targetAngleMomentum - 5
        end
        if self.controller.nozzleup then
            nozzleMomentum.y = nozzleMomentum.y - 2
        end
        if self.controller.nozzledown then
            nozzleMomentum.y = nozzleMomentum.y + 2
        end
        if self.controller.nozzleleft then
            nozzleMomentum.x = nozzleMomentum.x + 2
        end
        if self.controller.nozzleright then
            nozzleMomentum.x = nozzleMomentum.x - 2
        end

        if self.currentWeapon ~= nil then
            self.currentWeapon:tick()
        end

        for vid, v in pairs(self.effects) do
            if not v:tick() then
                self.effects[vid] = nil
            end
        end

        if self.controller.dash and self.dash >= 1 then
            self.dashing = true
            self.onDash:fire()
        end
    end

    return self:invokeInterested("FetchControls", targetVelocity, targetAngleMomentum, nozzleMomentum)
end

function Tank:invokeInterested(name, ...)
    local stuff = {...}
    if self.currentWeapon ~= nil and self.currentWeapon["tank" .. name .. "Invoked"] ~= nil then
        stuff = {self.currentWeapon["tank" .. name .. "Invoked"](self.currentWeapon, table.unpack(stuff))}
    end
    for _, effect in pairs(self.effects) do
        if effect["tank" .. name .. "Invoked"] ~= nil then
            stuff = {effect["tank" .. name .. "Invoked"](effect, table.unpack(stuff))}
        end
    end

    return table.unpack(stuff)
end

function Tank:tick()
    self:flushLerps()

    self.charge = math.min(self.charge + 0.1, 1)


    local hits = self:handleWeaponDamages()
    self.vel.y = self.vel.y - 0.05
    local friction, speedMultiplier, ground = self:moveVertically()

    self:takeDamageFromBlocks()
    self:takeVoidDamage()
    self:avoidSuffocation()

    if self.dashing then
        speedMultiplier = speedMultiplier * (self.dash * 5 + 1)
    end

    local targetVelocity, targetAngleMomentum, nozzleMomentum = self:fetchControls()


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
    friction = friction * 0.98
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

    return {
        hits = hits,
        friction = friction,
        speedMultiplier = speedMultiplier,
        targetVelocity = targetVelocity,
        targetAngleMomentum = targetAngleMomentum,
        ground = ground
    }
end

function Tank:serialise()
    return self.pos, self.vel, self.angle, self.anglemomentum, self.health, self.nozzle, self.dead, self.fire
end

function Tank:serialiseCritical()
    return self.pos, self.vel, self.health, self.dead, self.fire
end

function Tank:apply(pos, vel, angle, anglemomentum, health, nozzle, dead, fire)
    self.pos = pos
    self.vel = vel
    self.angle = angle
    self.anglemomentum = anglemomentum
    self.health = health
    self.nozzle = nozzle
    self.dead = dead
    self.fire = fire
end

function Tank:applyCritical(pos, vel, health, dead, fire)
    self.pos = pos
    self.vel = vel
    self.health = health
    self.dead = dead
    self.fire = fire
end

function Tank:getCollisionShape()
    return vec(0.3, 0.5, 0.3), vec(-0.3, 0, -0.3)
end


return Tank