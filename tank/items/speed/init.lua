local class             = require("tank.class")
local util              = require("tank.util.util")


---@params PingChannel State
local Speed             = class("Speed")
---@params Speed Tank number integer
local SpeedInstance     = class("SpeedInstance")

Speed.id = "default:speed"

local texture = textures:fromVanilla(Speed.id .. "--speed", "textures/mob_effect/speed.png")

function Speed:init(pings, state)
    self.pings = pings
    self.state = state

    self.speedPing = pings:register{
        name = "equip",
        arguments = {"tank", "default", "default"},
        func = function(tank, lifespan, id)
            if not tank:hasEffect(id) then
                tank:addEffect(id, SpeedInstance:new(self, tank, lifespan, id))
            end
        end
    }
end

function Speed:render() end
function Speed:tick() end

function Speed:apply(tank)
    self.speedPing(tank, 200, util.intID())
end

function Speed:handleWeaponDamages(hits, tank)

end

function Speed:generateIconGraphics(group)
    group:newSprite("e"):texture(texture, 16, 16):pos(8, 8, 0):setRenderType("TRANSLUCENT_CULL")
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

function SpeedInstance:shouldBeKept()
    return self.lifespan > 0
end

function SpeedInstance:tick()
    self.lifespan = self.lifespan - 1
end

function SpeedInstance:populateSyncQueue(consumer)
    consumer(function()
        if self.tank:hasEffect(self.id) then
            self.owner.speedPing(self.tank, self.lifespan, self.id)
        end
    end)
end

function SpeedInstance:generateIconGraphics(group)
    group:newSprite("e"):texture(texture, 16, 16):pos(9, 9, 0):setRenderType("TRANSLUCENT_CULL")
    local bar = group:newBlock("bar"):block("redstone_block"):setPos(-8, -8, 0.5)
    return {
        tick = function()
            bar:setScale(1, self.lifespan / 200, 0.01)
        end
    }
end


return Speed