local class          = require("tank.class")
local util           = require("tank.util")
local EffectDisplay  = require("tank.model.EffectDisplay")
local settings       = require("tank.settings")
local TankRetexturer = require("tank.model.TankRetexturer")
local CustomKeywords = require("tank.model.CustomKeywords")

local TankModelController = class("TankModelController")

function TankModelController:init(opt)
    self.opt = opt
    self.tank = opt.tank
    self.model = opt.model
    self.isHud = opt.isHUD

    self.focused = false

    self.currentWeapon = nil
    self.currentWeaponLifecycle = nil

    self.oldHealth = self.tank.health

    self.oldvel = vec(0, 0, 0)
    self.oldTargetVelocity = vec(0, 0, 0)

    self.soundPower = 1
    self.sounds = {}
    self.stress = 0
    self.oldMonitor = 0

    self.model:setVisible(true)

    self.ratank = self.model:newItem("e"):item('minecraft:player_head{SkullOwner:{Id:[I;-821169205,-1606269462,-2074908078,-1417990738],Properties:{textures:[{Value:"eyJ0ZXh0dXJlcyI6eyJTS0lOIjp7InVybCI6Imh0dHA6Ly90ZXh0dXJlcy5taW5lY3JhZnQubmV0L3RleHR1cmUvNzhkNmMzNDk5ZGRkNzgxN2NiMWQ3NzRhM2Q2NGIzMThkZWVlNWY3Zjc4NzcwNWZhNGEwOGRkMDkzYjUzYWIxMiJ9fX0="}]}}}'):setPos(0, 16, 0):setScale(1,1,1):setRot(0,90,0)
    self.ratank:setVisible(settings.ratank)

    self.retexturer = TankRetexturer:new(self.model)

    self.keywords = CustomKeywords:new(self.model, util.injectGenericCustomKeywordsRegistry({
        Turret = {},
        Nozzle = {},

        EffectAnchor = {
            injectedVariables = {
                UPWARDS = vec(0, 0, 0),
                DOWNWARDS = vec(0, 0, 0),
                LEFTWARDS = vec(0, 0, 0),
                RIGHTWARDS = vec(0, 0, 0),

                totalEffects = 0,
                currentEffectIndex = 0
            }
        }
    }, {
        tank = false,
        modelManager = false,
        happenings = false
    }))

    self.currentEffectsGroups = {}
    for model, args in self.keywords:iterate("EffectAnchor") do
        self.currentEffectsGroups[model] = EffectDisplay:new{
            tank = self.tank,
            group = model,
            positioner = function(i, t)
                local l = util.vecify(args{
                    totalEffects = t,
                    currentEffectIndex = i,
                    UPWARDS = vec(0, (i - 1) * 22, 0),
                    DOWNWARDS = vec(0, (i - 1) * -22, 0),
                    LEFTWARDS = vec((i - 1) * 22, 0, 0),
                    RIGHTWARDS = vec((i - 1) * -22, 0, 0)
                })
                return l + model:getPivot()
            end
        }
    end
end

function TankModelController:beforeTankTick(oldHappenings)
    self.oldvel = self.tank.vel:copy()
    if oldHappenings ~= nil then
        self.oldTargetVelocity = oldHappenings.targetVelocity
    end
end
function TankModelController:afterTankTick(happenings)
    if not self.opt.isHUD then
        if happenings.targetVelocity:length() < 0.1 then
            self.soundPower = self.soundPower - 0.005
        else
            self.soundPower = self.soundPower + 0.1
        end
        self.soundPower = math.max(0, math.min(self.soundPower, 0.7))
        if self.soundPower > 0 and (not self.tank.dead) then
            self:spawnTankEngineNoises()
        end

        self.model:setLight(world.getBlockLightLevel(self.tank.pos), world.getSkyLightLevel(self.tank.pos))
        
        if self.oldHealth > self.tank.health then
            if self.tank.health <= 0 then
                particles["explosion"]
                    :pos(self.tank.pos)
                    :spawn()
                if settings.tankMakesSound then
                    sounds:playSound("minecraft:entity.generic.explode", self.tank.pos, 0.5)
                end
            end
            local d = (self.oldHealth - self.tank.health) / 50
            if settings.tankMakesSound then
                sounds:playSound("entity.iron_golem.damage", self.tank.pos, d)
                sounds:playSound("entity.iron_golem.repair", self.tank.pos, d, 0.6)
            end
        end

        self.oldHealth = self.tank.health
    end

    if self.currentWeapon ~= self.tank.currentWeapon then
        util.callOn(self.currentWeaponLifecycle, "dispose")
        self.currentWeaponLifecycle = self.tank.currentWeapon:generateTankModelGraphics(self)
        self.currentWeapon = self.tank.currentWeapon
    else
        util.callOn(self.currentWeaponLifecycle, "tick")
    end

    if math.random() > self.tank.health / 100 then
        particles["smoke"]
            :pos(vectors.rotateAroundAxis(self.tank.angle, vec(-0.4, 0.4, 0), vec(0, 1, 0)) + self.tank.pos)
            :velocity(vec(0, 0.01, 0) + util.unitRandom() / 100)
            :spawn()

        if math.random() > self.tank.health / 30 then
            particles["flame"]
                :pos(vectors.rotateAroundAxis(self.tank.angle, vec(-0.4, 0.4, 0), vec(0, 1, 0)) + self.tank.pos)
                :velocity(vec(0, 0.02, 0) + util.unitRandom() / 100)
                :spawn()
        end
    end

    for model, args in self.keywords:iterate("EffectAnchor") do
        self.currentEffectsGroups[model]:tick()
    end

    self.retexturer:setHealthPercentage(self.tank.health / 100)
end

function TankModelController:render(happenings)
    local delta = client.getFrameTime()
    local lerpAngle = math.lerp(self.tank.oldangle, self.tank.angle, delta)
    local lerpPos = math.lerp(self.tank.oldpos, self.tank.pos, delta)

    local rotatedVelocity = vectors.rotateAroundAxis(
        -math.lerp(self.tank.oldangle, self.tank.angle, delta),
        math.lerp(self.oldTargetVelocity - self.oldvel / 2, happenings.targetVelocity - self.tank.vel / 2, delta),
        vec(0, 1, 0)
    )
    local E = 50

    local treshhold = math.max(6 - happenings.targetVelocity:length() * 20, 1)

    local rotate = vec(0, 0, 0)
    if settings.tankRotato then
        rotate = vec(0, world.getTime(delta) * 100, 0)
    end
    self.model:setMatrix(
        util.transform(
            matrices.yRotation4(180),
            matrices.zRotation4((rotatedVelocity.x + rotatedVelocity.y * 2) * E),
            matrices.xRotation4(rotatedVelocity.z * E * 4 + (self.stress / treshhold - math.pow(self.stress / treshhold, 2)) * (2 - self.tank.health / 100)),
            matrices.yRotation4(lerpAngle),
            matrices.rotation4(rotate),
            matrices.translate4((lerpPos + vec(0, math.abs(rotatedVelocity.x) / 4, 0)) * 16)
        )
    )

    if not self.opt.isHUD and (not self.tank.dead) then
        self:spawnDragParticles(happenings)
        self:spawnTankIgnitionSound(happenings)
    end

    util.callOn(self.currentWeaponLifecycle, "render")

    
    self.keywords:with(util.injectGenericCustomKeywordsExecution({
        Turret = function(m)
            m:setRot(0, self.tank.nozzle.x, 0)
        end,
        Nozzle = function(m)
            m:setRot(0, 0, self.tank.nozzle.y)
        end
    }, {
        tank = self.tank,
        modelManager = self,
        happenings = happenings
    }), client.getFrameTime())
end

function TankModelController:spawnTankIgnitionSound(happenings)
    local time = world.getTime(client.getFrameTime())
    local diff = time - self.oldMonitor
    local currentTreshhold = math.max(6 - happenings.targetVelocity:length() * 20, 1)
    self.stress = self.stress + diff

    if self.stress > currentTreshhold then
        self.stress = self.stress - currentTreshhold
        if self.stress > currentTreshhold then
            self.stress = 0
        end
        if settings.tankMakesSound then
            table.insert(self.sounds, sounds["entity.iron_golem.repair"]
                :pos(self.tank.pos)
                :volume((0.06 + happenings.targetVelocity:length() / 20) * self.soundPower)
                :pitch(0.17 + happenings.targetVelocity:length() / 100)
                :subtitle()
                :play()
            )
        end

        particles["smoke"]
            :pos(vectors.rotateAroundAxis(self.tank.angle, vec(-0.4, 0.2, -0.3), vec(0, 1, 0)) + self.tank.pos)
            :velocity(vectors.rotateAroundAxis(self.tank.angle, vec(-0.05, 0, 0), vec(0, 1, 0)))
            :scale(0.3, 0.3, 0.3)
            :spawn()
    end

    self.oldMonitor = time
end

function TankModelController:spawnTankEngineNoises()

    if settings.tankMakesSound then
        table.insert(self.sounds, sounds["entity.iron_golem.death"]
            :pos(self.tank.pos)
            :volume(0.01 * self.soundPower)
            :pitch(0.8)
            :subtitle()
            :play()
        )
    end

    while #self.sounds > 8 do
        table.remove(self.sounds, 1):stop()
    end
end

local function spawnAt(pos, vel)
    local blockid = world.getBlockState(pos - vec(0, 0.01, 0)).id
    pcall(function()
        particles:newParticle("minecraft:block " .. blockid, pos):velocity(vel + vec(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) / 20):lifetime(math.random() * 100 + 200)
    end)
end

function TankModelController:spawnDragParticles(happenings)
    if happenings.ground ~= nil then
        local lerpTarget = math.lerp(self.oldTargetVelocity, happenings.targetVelocity, client.getFrameTime());
        local lerpVel = math.lerp(self.oldvel, self.tank.vel, client.getFrameTime())
        local wantsdifferential = (lerpVel - lerpTarget):length()
        local offset = vectors.rotateAroundAxis(self.tank.angle, vec(0, 0, 0.5), vec(0, 1, 0))
        local offsetForwards = vectors.rotateAroundAxis(self.tank.angle, vec(0.8, 0, 0), vec(0, 1, 0))
        local pos = math.lerp(self.tank.oldpos, self.tank.pos, client.getFrameTime())
        if math.random() < wantsdifferential * 10 then
            spawnAt(pos + offset + offsetForwards * (math.random() - 0.5), ((lerpVel - lerpTarget) / 10 + vec(0,0.02,0)) * wantsdifferential * 40)
            spawnAt(pos - offset + offsetForwards * (math.random() - 0.5), ((lerpVel - lerpTarget) / 10 + vec(0,0.02,0)) * wantsdifferential * 40)
        end
    end
end

function TankModelController:dispose()
end

return TankModelController