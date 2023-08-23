local class          = require("tank.class")
local util        = require("tank.util")


local Speed = class("Speed")
local SpeedInstance = class("SpeedInstance")


Speed.name = "default:speed"
Speed.requiredPings = {
    speed = function(self, tank)
        tank:addEffect(SpeedInstance:new(tank))
    end
}


function Speed:init(pings, getTanks)
    self.pings = pings
    self.getTanks = getTanks
    self.bullets = {}
end

function Speed:tick() end

function Speed:apply(tank)
    self.pings.speed()
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


function SpeedInstance:init(tank)
    self.tank = tank
    self.lifespan = 200
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




return Speed