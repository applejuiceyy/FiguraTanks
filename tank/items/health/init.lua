local class          = require("tank.class")
local util        = require("tank.util.util")

---@params PingChannel State
local Health = class("Health")


Health.id = "default:health"

local texture = textures:fromVanilla(Health.id .. "--health", "textures/mob_effect/instant_health.png")


function Health:init(pings, state)
    self.pings = pings
    self.state = state

    self.healthPing = pings:register{
        name = "friction",
        arguments = {"tank"},
        func = function(tank)
            sounds:playSound("minecraft:entity.illusioner.prepare_mirror", tank.pos)
            tank.health = tank.health + 20
            tank.health = math.min(tank.health, 100)
            for i = 1, 5 do
                particles:newParticle("minecraft:happy_villager", tank.pos + (util.unitRandom() - vec(0.5, 0, 0.5)) * vec(0.7, 0.5, 0.7))
            end
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
    group:newSprite("e"):texture(texture, 16, 16):pos(9, 9, 0):setRenderType("TRANSLUCENT_CULL")
end





return Health