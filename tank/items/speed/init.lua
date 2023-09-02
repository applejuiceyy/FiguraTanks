local class             = require("tank.class")
local util              = require("tank.util")


local Speed             = class("Speed")
local SpeedInstance     = class("SpeedInstance")
local SpeedInstanceIcon = class("SpeedInstanceIcon")

Speed.name = "default:speed"
Speed.requiredPings = {
    speed = function(self, tank, lifespan, id)
        if not tank:hasEffect(id) then
            tank:addEffect(id, SpeedInstance:new(self, tank, lifespan, id))
        end
    end
}

local texture = textures:fromVanilla(Speed.name .. "--speed", "textures/mob_effect/speed.png")

function Speed:init(pings, state)
    self.pings = pings
    self.state = state
end

function Speed:render() end
function Speed:tick() end

function Speed:apply(tank)
    self.pings.speed(200, util.intID())
end

function Speed:handleWeaponDamages(hits, tank)

end

function Speed:generateIconGraphics(group)
    group:newSprite("e"):texture(texture):pos(8, 8, 0):setRenderType("TRANSLUCENT_CULL")
end


function SpeedInstance:init(owner, tank, lifespan, id)
    self.owner = owner
    self.tank = tank
    self.lifespan = lifespan
    self.id = id
end

function SpeedInstance:tankMoveVerticallyInvoked(a, b, c)
    if self.lifespan <= 0 then
        return a, b, c
    end
    return a, b * 1.5, c
end

function SpeedInstance:tick()
    self.lifespan = self.lifespan - 1
    return self.lifespan > 0
end

function SpeedInstance:populateSyncQueue(consumer)
    consumer(function()
        if self.tank:hasEffect(self.id) then
            self.owner.pings.speed(self.lifespan, self.id)
        end
    end)
end

function SpeedInstance:generateIconGraphics(group)
    group:newSprite("e"):texture(texture):pos(9, 9, 0):setRenderType("TRANSLUCENT_CULL")
    local bar = group:newBlock("bar"):block("redstone_block"):setPos(-8, -8, 0.5)
    return {
        tick = function()
            bar:setScale(1, self.lifespan / 200, 0.01)
        end
    }
end


return Speed