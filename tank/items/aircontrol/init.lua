local class             = require("tank.class")
local util              = require("tank.util.util")
local collision         = require("tank.collision")
local Event             = require("tank.events.Event")


---@params PingChannel State
local AirControl             = class("AirControl")
---@params AirControl Tank number integer
local AirControlInstance     = class("AirControlInstance")

AirControl.id = "default:aircontrol"

local texture = textures:fromVanilla(AirControl.id .. "--aircontrol", "textures/mob_effect/slow_falling.png")

function AirControl:init(pings, state)
    self.pings = pings
    self.state = state

    self.speedPing = pings:register{
        name = "equip",
        arguments = {"tank", "default", "default"},
        func = function(tank, lifespan, id)
            if not tank:hasEffect(id) then
                tank:addEffect(id, AirControlInstance:new(self, tank, lifespan, id))
            end
        end
    }
end

function AirControl:render() end
function AirControl:tick() end

function AirControl:apply(tank)
    self.speedPing(tank, 1000, util.intID())
end

function AirControl:handleWeaponDamages(hits, tank)

end

function AirControl:generateIconGraphics(group)
    group:newSprite("e"):texture(texture):pos(8, 8, 0):setRenderType("TRANSLUCENT_CULL")
end


function AirControlInstance:init(owner, tank, lifespan, id)
    self.owner = owner
    self.tank = tank
    self.lifespan = lifespan
    self.id = id

    self.slowDownEvent = Event:new()
    self.breakingEvent = Event:new()
end

function AirControlInstance:tankMoveVerticallyInvoked(a, b, c)
    if not c then

        return 0, b, c
    end
    return a, b, c
end

function AirControlInstance:shouldBeKept()
    return self.lifespan > 0
end

function AirControlInstance:tick()
    if self.tank.vel.y < -0.9 then
        local highCol, lowCol = self.tank:getCollisionShape()
        if collision.collidesWithWorld(highCol + self.tank.pos, lowCol + vec(0, self.tank.vel.y * 10, 0) + self.tank.pos) then
            local toRemove = -self.tank.vel.y * 0.1
            local cost = toRemove * 40

            if cost >= self.lifespan then
                cost = self.lifespan
                self.breakingEvent:fire()
            end

            toRemove = cost / 40

            self.tank.vel.y = self.tank.vel.y + toRemove
            self.lifespan = self.lifespan - cost
            self.slowDownEvent:fire(toRemove)
        end
    end
    self.lifespan = self.lifespan - 1
end

function AirControlInstance:populateSyncQueue(consumer)
    consumer(function()
        if self.tank:hasEffect(self.id) then
            self.owner.speedPing(self.tank, self.lifespan, self.id)
        end
    end)
end

function AirControlInstance:generateIconGraphics(group)
    group:newSprite("e"):texture(texture):pos(9, 9, 0):setRenderType("TRANSLUCENT_CULL")
    local bar = group:newBlock("bar"):block("redstone_block"):setPos(-8, -8, 0.5)
    return {
        tick = function()
            bar:setScale(1, self.lifespan / 1000, 0.01)
        end
    }
end

function AirControlInstance:specifyModel(model)
    if model.isHUD then
        return
    end

    local slowDownSubscription = self.slowDownEvent:register(function(removal)
        sounds["block.fire.extinguish"]:pos(self.tank.pos):volume(removal):pitch(removal):play()
        for i = 0, 359, 10 do
            particles["dust 1 1 1 1"]:lifetime(100):scale(removal * 5):pos(self.tank.pos):velocity(vectors.rotateAroundAxis(i, vec(removal / 100, 0, 0), vec(0, 1, 0))):spawn()
        end
    end)
    local breakingSubscription = self.breakingEvent:register(function()
        sounds["entity.item.break"]:pos(self.tank.pos):play()
    end)

    return {
        tick = function()
        end,
        dispose = function ()
            slowDownSubscription:remove()
            breakingSubscription:remove()
        end
    }
end


return AirControl