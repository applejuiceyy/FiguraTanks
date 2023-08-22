local class          = require("tank.class")
local util        = require("tank.util")


local Speed = class("Speed")


Speed.name = "default:speed"
Speed.requiredPings = {
    health = function(self, tank)
        tank.health = tank.health + 20
        tank.health = math.min(tank.health, 100)
    end
}


function Speed:init(pings, getTanks)
    self.pings = pings
    self.getTanks = getTanks
    self.bullets = {}
end

function Speed:tick() end

function Speed:apply(tank)
    self.pings.health()
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

    rt = group:newBlock("ee")
    rt:setBlock("red_concrete")
    rt:setMatrix(util.transform(
        matrices.scale4(1, 0.25, 0.01),
        matrices.translate4(-8, -0.125 * 16, 0)
    ))
    return group
end





return Speed