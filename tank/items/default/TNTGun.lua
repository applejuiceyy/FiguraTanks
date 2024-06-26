local class          = require("tank.class")
local TNTGunEffect = require("tank.items.default.TNTGunEffect")
local Bullet         = require("tank.items.default.Bullet")
local settings       = require("tank.settings")
local util           = require("tank.util.util")


---@params PingChannel State
local TNTGun = class("TNTGun")


TNTGun.id = "default:tntgun"
TNTGun.explosionAvatarPath = "__FiguraTanks_" .. TNTGun.id .. "_explosion"

function TNTGun:init(pings, state)
    self.pings = pings

    self.shoot = pings:register{
        name = "shoot",
        arguments = {"tank", "default", "default"},
        func = function(tank, pos, vel)
            self:_shootAfterPing(tank, pos, vel)
        end
    }

    self.equip = pings:register{
        name = "equip",
        arguments = {"tank", "default"},
        func = function(tank, id)
            if not tank:hasEffect(id) then
                return self:_applyAfterPing(tank, id)
            end
        end
    }

    self.state = state
    self.bullets = {}
end

function TNTGun:_applyAfterPing(tank, id)
    util.removeWeaponEffects(tank)
    id = id or util.intID()
    tank:addEffect(id, TNTGunEffect:new(self, tank, id))
end

function TNTGun:render()
    
end

function TNTGun:tick()
    local explosions = {}
    local hasExplosions = false
    for bullet in pairs(self.bullets) do
        local hit, pos = bullet:tick()
        if hit then
            explosions[bullet.pos] = true
            hasExplosions = true
            self.bullets[bullet] = nil
            local damage = self.state.worldDamageDisplay:createDamageCreator(pos:floor(), 30):canPenetrateBlocks()
            
            if settings.bulletsCanBreakBlocks then
                damage:canDestroyBlocks()
            end

            damage:apply()
        end
    end
    for _, tankComplex in pairs(self.state.loadedTanks) do
        self:handleWeaponDamages(tankComplex.tank)
    end
    if hasExplosions then
        avatar:store(TNTGun.explosionAvatarPath, explosions)
    else
        avatar:store(TNTGun.explosionAvatarPath, nil)
    end
end

function TNTGun:apply(tank)
    self.equip(tank, util.intID())
end

function TNTGun:handleWeaponDamages(tank)
    local highCollisionShape, lowCollisionShape = tank:getCollisionShape()

    local middle = (tank.pos + (highCollisionShape + lowCollisionShape) / 2)
    for uuid, v in pairs(world.avatarVars()) do
        if v[TNTGun.explosionAvatarPath] ~= nil then
            for explosion in pairs(v[TNTGun.explosionAvatarPath]) do
                local diff = explosion - middle
                if diff:length() < 3 then
                    local damage = 5 * (5 - diff:length())
                    if player:getUUID() == uuid then
                        damage = damage / 2
                    end
                    tank.health = tank.health - damage
                    tank.vel = tank.vel - (diff:normalize() * (5 - diff:length())) / 5
                    self.state:markTankPositionDirty()
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

function TNTGun:generateIconGraphics(group)
    group:newBlock("ee"):setBlock("tnt"):setMatrix(util.transform(
        matrices.translate4(-8, -8, -8),
        matrices.rotation4(0, 45, 0),
        matrices.rotation4(-30, 0, 0),
        matrices.scale4(0.6, 0.6, 0.001)
    ))
end

return TNTGun