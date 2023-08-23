local class          = require("tank.class")
local util        = require("tank.util")


local Friction = class("Friction")
local FrictionInstance = class("FrictionInstance")


Friction.name = "default:friction"
Friction.requiredPings = {
    speed = function(self, tank)
        tank:addEffect(FrictionInstance:new(tank))
    end
}


function Friction:init(pings, getTanks)
    self.pings = pings
    self.getTanks = getTanks
    self.bullets = {}
end

function Friction:tick() end

function Friction:apply(tank)
    self.pings.speed()
end

function Friction:handleWeaponDamages(hits, tank)

end

function Friction:generateIconGraphics()
    local group = util.group()
    local rt = group:newBlock("e")
    rt:setBlock("red_concrete")
    rt:setMatrix(util.transform(
        matrices.scale4(0.25, 1, 0.01),
        matrices.translate4(-0.125 * 16, -8, 0)
    ))
    return group
end


function FrictionInstance:init(tank)
    self.tank = tank
    self.lifespan = 1000
end

function FrictionInstance:tankMoveVerticallyInvoked(a, b, c)
    if self.lifespan <= 0 then
        return a, b, c
    end
    return world.newBlock("minecraft:dirt"):getFriction(), b, c
end

function FrictionInstance:tick()
    self.lifespan = self.lifespan - 1
    return self.lifespan > 0
end




return Friction