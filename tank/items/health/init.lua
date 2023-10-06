local class          = require("tank.class")
local util        = require("tank.util")

---@params PingChannel State
local Health = class("Health")


Health.name = "default:health"
Health.requiredPings = {
    health = function(self, tank)
    end
}

local texture = textures:fromVanilla(Health.name .. "--health", "textures/mob_effect/instant_health.png")


function Health:init(pings, state)
    self.pings = pings
    self.state = state

    self.healthPing = pings:register{
        name = "friction",
        arguments = {"tank"},
        func = function(tank)
            tank.health = tank.health + 20
            tank.health = math.min(tank.health, 100)
        end
    }
end
function Health:render() end
function Health:tick() end

function Health:apply(tank)
    self.healthPing(tank)
end

function Health:handleWeaponDamages(hits, tank)

end

function Health:generateIconGraphics(group)
    group:newSprite("e"):texture(texture):pos(9, 9, 0):setRenderType("TRANSLUCENT_CULL")
end





return Health