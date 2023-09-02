local class          = require("tank.class")
local util        = require("tank.util")


local Health = class("Health")


Health.name = "default:health"
Health.requiredPings = {
    health = function(self, tank)
        tank.health = tank.health + 20
        tank.health = math.min(tank.health, 100)
    end
}

local texture = textures:fromVanilla(Health.name .. "--health", "textures/mob_effect/instant_health.png")


function Health:init(pings, state)
    self.pings = pings
    self.state = state
end
function Health:render() end
function Health:tick() end

function Health:apply(tank)
    self.pings.health()
end

function Health:handleWeaponDamages(hits, tank)

end

function Health:generateIconGraphics(group)
    group:newSprite("e"):texture(texture):pos(9, 9, 0):setRenderType("TRANSLUCENT_CULL")
end





return Health