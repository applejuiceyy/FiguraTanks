local class          = require("tank.class")
local collision      = require("tank.collision")

local Bullet = class("Bullet")

function Bullet:init(pos, vel, times)
    self.pos = pos
    self.vel = vel

    self.times = times

    self.id = math.random()
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

            return true
        end
    end
    return false
end

return Bullet