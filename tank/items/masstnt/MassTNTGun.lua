local class          = require("tank.class")
local MassTNTGunInstance = require("tank.items.masstnt.MassTNTGunInstance")
local Bullet         = require("tank.items.masstnt.Bullet")


local MassTNTGun = class("MassTNTGun")


MassTNTGun.name = "default:masstntgun"
MassTNTGun.explosionAvatarPath = "__FiguraTanks_" .. MassTNTGun.name .. "_explosion"
MassTNTGun.requiredPings = {
    shoot = function(self, tank, pos, vel)
        self:_shootAfterPing(tank, pos, vel)
    end
}

function MassTNTGun:init(pings, getTanks)
    self.pings = pings
    self.getTanks = getTanks
    self.bullets = {}
    self.queuedRemoval = {}
end

function MassTNTGun:tick()
    local explosions = {}
    local hasExplosions = false
    for bullet in pairs(self.bullets) do

        if bullet:tick() then
            table.insert(self.queuedRemoval, bullet)
            self.bullets[bullet] = nil
        end
    end

    for i = 1, 2 do
        if #self.queuedRemoval == 0 then
            break
        end
        local bullet = table.remove(self.queuedRemoval, 1)
        local pos = bullet.pos
        particles:newParticle("minecraft:explosion", pos)
        sounds:playSound("minecraft:entity.generic.explode", pos, 0.5)
        if bullet.times > 0 then
            local newbullet = Bullet:new(pos, vec(-0.5, 1, 0), bullet.times - 1)
            self.bullets[newbullet] = true
            newbullet = Bullet:new(pos, vec(0.5, 1, 0), bullet.times - 1)
            self.bullets[newbullet] = true
            newbullet = Bullet:new(pos, vec(0, 1, 0.5), bullet.times - 1)
            self.bullets[newbullet] = true
            newbullet = Bullet:new(pos, vec(0, 1, -0.5), bullet.times - 1)
            self.bullets[newbullet] = true
        end

        explosions[bullet.pos] = true
        hasExplosions = true
    end

    if hasExplosions then
        avatar:store(MassTNTGun.explosionAvatarPath, explosions)
    else
        avatar:store(MassTNTGun.explosionAvatarPath, nil)
    end
end

function MassTNTGun:apply(tank)
    tank:setWeapon(MassTNTGunInstance:new(self, tank))
end

function MassTNTGun:shoot(tank)
    local vel = vec(2, 0, 0)
    vel = vectors.rotateAroundAxis(-tank.nozzle.y, vel, vec(0, 0, 1))
    vel = vectors.rotateAroundAxis(tank.nozzle.x + tank.angle, vel, vec(0, 1, 0))

    self.pings.shoot(tank.pos + vec(0, 0.3, 0), vel + tank.vel)
end

function MassTNTGun:handleWeaponDamages(hits, tank)
    local highCollisionShape, lowCollisionShape = tank:getCollisionShape()

    local middle = (tank.pos + (highCollisionShape + lowCollisionShape) / 2)
    for uuid, v in pairs(world.avatarVars()) do
        if v[MassTNTGun.explosionAvatarPath] ~= nil then
            for explosion in pairs(v[MassTNTGun.explosionAvatarPath]) do
                local diff = explosion - middle
                if diff:length() < 5 then
                    local damage = 5 * (5 - diff:length())
                    if player:getUUID() == uuid then
                        damage = damage / 2
                    end
                    tank.health = tank.health - damage
                    tank.vel = tank.vel - (diff:normalize() * (5 - diff:length())) / 5
                    hits[uuid] = damage
                end
            end
        end
    end
end

function MassTNTGun:_shootAfterPing(tank, pos, vel)
    sounds:playSound("minecraft:entity.shulker.shoot", pos)
    local bullet = Bullet:new(pos, vel, 5)
    self.bullets[bullet] = true
    tank.vel = tank.vel - vel * 0.02
end

function MassTNTGun:generateIconGraphics()
    
end





return MassTNTGun