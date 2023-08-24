local class          = require("tank.class")
local util        = require("tank.util")


local Friction = class("Friction")
local FrictionInstance = class("FrictionInstance")


Friction.name = "default:friction"
Friction.requiredPings = {
    friction = function(self, tank, lifespan, id)
        if not tank:hasEffect(id) then
            tank:addEffect(id, FrictionInstance:new(self, tank, lifespan, id))
        end
    end
}


function Friction:init(pings, state)
    self.pings = pings
    self.state = state
end

function Friction:tick() end

function Friction:apply(tank)
    self.pings.friction(1000, math.random())
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


function FrictionInstance:init(owner, tank, lifespan, id)
    self.owner = owner
    self.tank = tank
    self.id = id
    self.lifespan = lifespan
end

function FrictionInstance:tankMoveVerticallyInvoked(a, b, c)
    if self.lifespan <= 0 then
        return a, b, c
    end
    return a * 0.9, b, c
end

function FrictionInstance:tick()
    self.lifespan = self.lifespan - 1
    return self.lifespan > 0
end

function FrictionInstance:populateSyncQueue(consumer)
    consumer(function()
        if self.tank:hasEffect(self.id) then
            self.owner.pings.friction(self.lifespan, self.id)
        end
    end)
end




return Friction