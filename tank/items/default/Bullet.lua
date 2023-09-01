local class          = require("tank.class")
local collision      = require("tank.collision")
local util           = require("tank.util")

local Bullet = class("Bullet")

function Bullet:init(pos, vel, onExplosion)
    self.pos = pos
    self.vel = vel

    self.onExplosion = onExplosion

    self.id = util.intID()
end

function Bullet:render(delta)

end

function Bullet:tick()
    local resolution = math.ceil(self.vel:length() * 5)
    for i = 1, resolution do
        self.vel = self.vel - vec(0, 0.1 / resolution, 0)
        self.pos = self.pos + self.vel / resolution
        particles:newParticle("minecraft:smoke", self.pos + vec(0, 1, 0))

        local pos = self.pos

        if collision.collidesWithWorld(pos, pos) then
            self.pos = self.pos - self.vel / resolution
            particles:newParticle("minecraft:explosion", self.pos)
            sounds:playSound("minecraft:entity.generic.explode", self.pos, 0.5)
            return true, pos
        end
    end
    return false
end

return Bullet