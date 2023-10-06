local class          = require("tank.class")
local FlameThrowerInstance = require("tank.items.flamethrower.FlameThrowerInstance")
local util        = require("tank.util")
local collision = require("tank.collision")
local settings       = require("tank.settings")


---@params PingChannel State
local FlameThrower = class("FlameThrower")


FlameThrower.name = "default:flamethrower"
FlameThrower.rayAvatarPath = "__FiguraTanks_" .. FlameThrower.name .. "_flame"

function FlameThrower:init(pings, state)
    self.pings = pings
    self.state = state

    self.setFlaming = pings:register{
        name = "setFlaming",
        arguments = {"tank", "default"},
        func = function(tank, flameState)
            self:_setFlamingAfterPing(tank, flameState)
        end
    }

    self.equip = pings:register{
        name = "equip",
        arguments = {"tank", "default"},
        func = function(tank, charge)
            if tank.currentWeapon == nil or tank.currentWeapon.class ~= FlameThrowerInstance then
                return self:_applyAfterPing(tank, charge)
            end
            tank.currentWeapon.charge = charge
        end
    }

    self.flamingTanks = {}
    self.bigParticles = {}
end

function FlameThrower:render()
    for t in pairs(self.bigParticles) do
        local time = world.getTime(client.getFrameTime()) - t.at
        local normalised = math.min(time / 10, 1)
        local s = (normalised - math.pow(normalised, 5)) * 2
        t.task:matrix(
            util.transform(
                matrices.translate4(-8, -8, -8),
                matrices.scale4(s, s, s),
                matrices.rotation4(t.rotation),
                matrices.translate4((t.pos + t.vel * client.getFrameTime()) * 16)
            )
        )
    end
end

function FlameThrower:tick()
    if next(self.flamingTanks) == nil then
        avatar:store(FlameThrower.rayAvatarPath, nil)
    else
        local t = {}
        for tank in pairs(self.flamingTanks) do
            t[{pos = tank.pos + vec(0, 0.3, 0), dir = tank.nozzle + vec(tank.angle, 0)}] = true
            for i = 1, 8 do
                self:spawnBigParticle(tank.pos + vec(0, 0.3, 0), util.pitchYawToUnitVector(tank.nozzle + vec(tank.angle, 0)) + (util.unitRandom() - 0.5) * vec(1, 0.5, 1))
            end
        end
        avatar:store(FlameThrower.rayAvatarPath, t)
    end

    for t in pairs(self.bigParticles) do
        t.pos = t.pos + t.vel
        local time = world.getTime() - t.at
        if time > 10 then
            models.world:removeTask(t.id)
            self.bigParticles[t] = nil
        end
    end
end

local colors = {"orange_wool", "yellow_wool", "red_wool", "magma_block", "gray_wool", "fire", "cobweb", "red_stained_glass", "orange_stained_glass", "yellow_stained_glass"}
function FlameThrower:spawnBigParticle(pos, vel)
    local id = util.stringID()
    local task = models.world:newBlock(id)
    task:setBlock(colors[math.random(1, #colors)])
    task:setLight(15, 15)
    self.bigParticles[{
        pos = pos,
        vel = vel,
        at = world.getTime(),
        rotation = vec(math.random() * 180 - 90, math.random() * 360, 0),
        id = id,
        task = task
    }] = true
end

function FlameThrower:apply(tank)
    self.equip(tank, 1)
end


function FlameThrower:_applyAfterPing(tank, charge)
    tank:setWeapon(FlameThrowerInstance:new(self, tank, charge))
end


function FlameThrower:handleWeaponDamages(hits, tank)
    for uuid, v in pairs(world.avatarVars()) do
        if uuid ~= player:getUUID() and v[FlameThrower.rayAvatarPath] ~= nil then
            for ray in pairs(v[FlameThrower.rayAvatarPath]) do
                local mat = util.transform(
                    matrices.zRotation4(-ray.dir.y),
                    matrices.yRotation4(ray.dir.x),
                    matrices.translate4(ray.pos)
                )

                local localPos = mat:invert():apply(tank.pos)

                if collision.collidesWithRectangle(localPos, localPos, vec(5, 1, 1.5), vec(0, -1, -1.5)) then
                    tank.health = tank.health - 5
                    tank.fire = tank.fire + 2
                    hits[uuid] = 5
                end
            end
        end
    end
end

function FlameThrower:_setFlamingAfterPing(tank, state)
    if tank.currentWeapon.class == FlameThrowerInstance then
        tank.currentWeapon.flaming = state
        if state then
            self.flamingTanks[tank] = true
        else
            self.flamingTanks[tank] = nil
        end
    end
end

function FlameThrower:generateIconGraphics(group)
    group:newBlock("ee"):setBlock("fire"):setMatrix(util.transform(
        matrices.translate4(-8, -8, -8),
        matrices.rotation4(0, 0, 0),
        matrices.rotation4(-45, 0, 0),
        matrices.scale4(0.8, 0.8, 0.001)
    ))
end





return FlameThrower