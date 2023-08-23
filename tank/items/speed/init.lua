local class          = require("tank.class")
local util        = require("tank.util")


local Speed = class("Speed")
local SpeedInstance = class("SpeedInstance")


Speed.name = "default:speed"
Speed.requiredPings = {
    speed = function(self, tank, lifespan, id)
        if not tank:hasEffect(id) then
            tank:addEffect(id, SpeedInstance:new(self, tank, lifespan, id))
        end
    end
}


function Speed:init(pings, state)
    self.pings = pings
    self.state = state
end

function Speed:tick() end

function Speed:apply(tank)
    self.pings.speed(200, math.random())
end

function Speed:handleWeaponDamages(hits, tank)

end

function Speed:generateIconGraphics()
    local group = util.group()
    local rt = group:newBlock("e")
    rt:setBlock("red_concrete")
    rt:setMatrix(util.transform(
        matrices.scale4(0.25, 1, 0.01),
        matrices.translate4(-0.125 * 16, -8, 0)
    ))
    return group
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




return Speed