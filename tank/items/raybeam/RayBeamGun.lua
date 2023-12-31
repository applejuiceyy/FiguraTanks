local class          = require("tank.class")
local RayBeamGunInstance = require("tank.items.raybeam.RayBeamGunEffect")
local util        = require("tank.util.util")
local collision = require("tank.collision")
local settings       = require("tank.settings")


---@params PingChannel State
local RayBeamGun = class("RayBeamGun")


RayBeamGun.id = "default:raybeam"
RayBeamGun.rayAvatarPath = "__FiguraTanks_" .. RayBeamGun.id .. "_rays"

function RayBeamGun:init(pings, state)
    self.pings = pings
    self.state = state

    self.startShootingPing = pings:register{
        name = "startShooting",
        arguments = {"tank", "default"},
        func = function(tank, id)
            self:_startShootingAfterPing(tank, id)
        end
    }

    self.shootPing = pings:register{
        name = "shoot",
        arguments = {"tank", "default", "default"},
        func = function(tank, pos, dir)
            self:_shootAfterPing(tank, pos, dir)
        end
    }

    self.equipPing = pings:register{
        name = "equip",
        arguments = {"tank", "default", "default"},
        func = function(tank, bullets, id)
            if not tank:hasEffect(id) then
                return self:_applyAfterPing(tank, bullets, id)
            end
            tank.effects[id].bulletsRemaining = bullets
        end
    }


    self.rays = {}
    self.avatarVars = {}

    self.knownRays = {}
end

function RayBeamGun:render()
    for ray in pairs(self.rays) do
        local since = (world.getTime(client.getFrameTime()) - ray.at) / 20
        ray.railParticle
        :scale((1 - since) * 20, (1 - since) * 20, (1 - since) * 20)
        :pos(ray.pos + util.pitchYawToUnitVector(ray.dir) * since * 100)

        ray.task:setMatrix(
            util.transform(
                matrices.translate4(0, -8, -8),
                matrices.scale4(since * 100, (1 - since) * 0.1, (1 - since) * 0.1),
                matrices.zRotation4(-ray.dir.y),
                matrices.yRotation4(ray.dir.x),
                matrices.translate4(ray.pos * 16)
            )
        )

        particles["firework"]
        :color(0, 1, 0)
        :pos(ray.mat:apply((util.unitRandom() - vec(0, 0.5, 0.5)) * vec(0, 1, 1) + vec(since * 100, 0, 0)))
        :velocity(ray.mat:applyDir(vec(1, 0, 0)))
        :gravity(0)
        :physics(false)
        :spawn()
    end
end

function RayBeamGun:tick()
    for ray in pairs(self.rays) do
        local since = (world.getTime() - ray.at) / 20
        for i = 0, 1, 0.25 do
            local s = since - (i / 20)
            local position = (ray.pos + util.pitchYawToUnitVector(ray.dir) * 100 * s):floor()
            local g = util.serialisePos(position)
            if ray.damageCreated[g] == nil then
                local damage = self.state.worldDamageDisplay:createDamageCreator(position, 20):canPenetrateBlocks()
                damage:runOut():apply()
                ray.damageCreated[g] = true
            end
        end

        if since >= 1 then
            ray.railParticle:remove()
            models.world:removeTask(ray.id)
            self.rays[ray] = nil
            self.avatarVars[ray.id] = nil
        end
    end

    if next(self.avatarVars) == nil then
        avatar:store(RayBeamGun.rayAvatarPath, nil)
    else
        avatar:store(RayBeamGun.rayAvatarPath, self.avatarVars)
    end
end

function RayBeamGun:apply(tank)
    self.equipPing(tank, 4, util.intID())
end


function RayBeamGun:_applyAfterPing(tank, bulletsRemaining, id)
    util.removeWeaponEffects(tank)
    id = id or util.intID()
    tank:addEffect(id, RayBeamGunInstance:new(self, tank, bulletsRemaining, id))
end

function RayBeamGun:startShooting(tank, id)
    self.startShootingPing(tank, id)
end

function RayBeamGun:shoot(tank)
    self.shootPing(tank, tank.pos + vec(0, 0.3, 0), tank.nozzle + vec(tank.angle, 0))
end


function RayBeamGun:handleWeaponDamages(hits, tank)
    for uuid, v in pairs(world.avatarVars()) do
        if uuid ~= player:getUUID() and v[RayBeamGun.rayAvatarPath] ~= nil then
            for id, ray in pairs(v[RayBeamGun.rayAvatarPath]) do
                if self.knownRays[uuid .. id] == nil then
                    local mat = util.transform(
                        matrices.zRotation4(-ray.dir.y),
                        matrices.yRotation4(ray.dir.x),
                        matrices.translate4(ray.pos)
                    )

                    local localPos = mat:invert():apply(tank.pos)

                    if collision.collidesWithRectangle(localPos, localPos, vec(100, 2, 2), vec(0, -2, -2)) then
                        self.knownRays[uuid .. id] = true
                        tank.health = tank.health - 30
                        tank.vel = tank.vel + util.pitchYawToUnitVector(ray.dir)
                        hits[uuid] = 30
                    end
                end
            end
        end
    end
end

function RayBeamGun:_startShootingAfterPing(tank, id)
    if tank:hasEffect(id) then
        tank.effects[id]:startShooting()
    end
end

function RayBeamGun:_shootAfterPing(tank, pos, dir)
    sounds:playSound("block.respawn_anchor.deplete", pos, 1, 2)

    tank.vel = tank.vel - util.pitchYawToUnitVector(dir) / 2

    local id = util.stringID()
    local task = models.world:newBlock(id)
    task:setBlock("white_concrete")
    task:setLight(15, 15)

    local localMatrix = util.transform(
        matrices.zRotation4(-dir.y),
        matrices.yRotation4(dir.x),
        matrices.translate4(pos)
    )

    local railParticle = particles["flash"]
    :color(0, 1, 0)
    :pos(pos)
    :gravity(0)
    :scale(50, 50, 50)
    :lifetime(9999)
    :physics(false)
    :spawn()

    self.rays[{
        pos = pos,
        dir = dir,
        id = id,
        task = task,
        mat = localMatrix,
        railParticle = railParticle,
        at = world.getTime(),
        damageCreated = {}
    }] = true

    self.avatarVars[id] = {
        at = world.getTime(),
        pos = pos,
        dir = dir
    }
end

function RayBeamGun:generateIconGraphics(group)
    group:newBlock("ee"):setBlock("amethyst_cluster"):setMatrix(util.transform(
        matrices.translate4(-8, -8, -8),
        matrices.rotation4(0, 0, 0),
        matrices.rotation4(-45, 0, 0),
        matrices.scale4(0.8, 0.8, 0.001)
    ))
end





return RayBeamGun