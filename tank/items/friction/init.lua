local class          = require("tank.class")
local util        = require("tank.util.util")

---@params PingChannel State
local Friction = class("Friction")
---@params Friction Tank number number
local FrictionInstance = class("FrictionInstance")


Friction.id = "default:friction"


function Friction:init(pings, state)
    self.pings = pings
    self.state = state

    self.frictionPing = pings:register{
        name = "friction",
        arguments = {"tank", "default", "default"},
        func = function(tank, lifespan, id)
            if not tank:hasEffect(id) then
                tank:addEffect(id, FrictionInstance:new(self, tank, lifespan, id))
            end
        end
    }
end

function Friction:render() end
function Friction:tick() end

function Friction:apply(tank)
    self.frictionPing(tank, 800, util.intID())
end

function Friction:handleWeaponDamages(hits, tank)

end

function Friction:generateIconGraphics(group)
    group:newBlock("e"):setBlock("ice"):setMatrix(util.transform(
        matrices.translate4(-8, -8, -8),
        matrices.rotation4(0, 45, 0),
        matrices.rotation4(30, 0, 0),
        matrices.scale4(0.6, 0.6, 0.001)
    ))
    group:newBlock("ee"):setBlock("coal_block"):setMatrix(util.transform(
        matrices.translate4(-8, -8, -8),
        matrices.rotation4(0, 45, 0),
        matrices.rotation4(30, 0, 0),
        matrices.scale4(0.4, 0.4, 0.001),
        matrices.translate4(0, 0, -0.02)
    ))
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

    return a * 0.9, b * (math.max(a - 0.8, 0) * 4 + 1), c
end

function FrictionInstance:shouldBeKept()
    return self.lifespan > 0
end

function FrictionInstance:tick()
    self.lifespan = self.lifespan - 1
end

function FrictionInstance:populateSyncQueue(consumer)
    consumer(function()
        if self.tank:hasEffect(self.id) then
            self.owner.frictionPing(self.tank, self.lifespan, self.id)
        end
    end)
end

function FrictionInstance:generateIconGraphics(group)
    self.owner:generateIconGraphics(group)
    local bar = group:newBlock("bar"):block("redstone_block"):setPos(-8, -8, 0.5)
    return {
        tick = function()
            bar:setScale(1, self.lifespan / 800, 0.01)
        end
    }
end



return Friction