local class          = require("tank.class")
local TNTGunInstance = require("tank.items.default.TNTGunInstance")
local Bullet         = require("tank.items.default.Bullet")


local TNTGun = class("TNTGun")


TNTGun.name = "default:tntgun"
TNTGun.explosionAvatarPath = "__FiguraTanks_" .. TNTGun.name .. "_explosion"
TNTGun.requiredPings = {
    shoot = function(self, tank, pos, vel)
        self:_shootAfterPing(tank, pos, vel)
    end
}

function TNTGun:init(pings, state)
    self.pings = pings
    self.state = state
    self.bullets = {}
end

function TNTGun:tick()
    local explosions = {}
    local hasExplosions = false
    for bullet in pairs(self.bullets) do
        if bullet:tick() then
            explosions[bullet.pos] = true
            hasExplosions = true
            self.bullets[bullet] = nil
        end
    end
    if hasExplosions then
        avatar:store(TNTGun.explosionAvatarPath, explosions)
    else
        avatar:store(TNTGun.explosionAvatarPath, nil)
    end
end

function TNTGun:apply(tank)
    tank:setWeapon(TNTGunInstance:new(self, tank))
end

function TNTGun:shoot(tank)
    local vel = vec(2, 0, 0)
    vel = vectors.rotateAroundAxis(-tank.nozzle.y, vel, vec(0, 0, 1))
    vel = vectors.rotateAroundAxis(tank.nozzle.x + tank.angle, vel, vec(0, 1, 0))

    self.pings.shoot(tank.pos + vec(0, 0.3, 0), vel + tank.vel)
end

function TNTGun:handleWeaponDamages(hits, tank)
    local highCollisionShape, lowCollisionShape = tank:getCollisionShape()

    local middle = (tank.pos + (highCollisionShape + lowCollisionShape) / 2)
    for uuid, v in pairs(world.avatarVars()) do
        if v[TNTGun.explosionAvatarPath] ~= nil then
            for explosion in pairs(v[TNTGun.explosionAvatarPath]) do
                local diff = explosion - middle
                if diff:length() < 5 then
                    local damage = 5 * (5 - diff:length())
                    if player:getUUID() == uuid then
                        damage = damage / 2
                    end
                    tank.health = tank.health - damage
                    tank.vel = tank.vel - (diff:normalize() * (5 - diff:length())) / 5
                    self.state:markTankPositionDirty()
                    hits[uuid] = damage
                end
            end
        end
    end
end

function TNTGun:_shootAfterPing(tank, pos, vel)
    sounds:playSound("minecraft:entity.shulker.shoot", pos)
    local bullet = Bullet:new(pos, vel)
    self.bullets[bullet] = true
    tank.vel = tank.vel - vel * 0.02
end

function TNTGun:generateIconGraphics()
    
end





return TNTGun