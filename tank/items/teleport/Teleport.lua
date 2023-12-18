local class          = require("tank.class")
local TeleportEffect = require("tank.items.teleport.TeleportEffect")
local util           = require("tank.util.util")


---@params PingChannel State ControlRepo
local Teleport = class("Teleport")

Teleport.id = "default:teleport"

function Teleport:init(pings, state, controls)
    self.pings = pings
    self.rangeUp = controls:defineKey("teleport range up", false, "key.keyboard.r")
    self.rangeDown = controls:defineKey("teleport range down", false, "key.keyboard.f")

    self.teleportPosition = pings:register{
        name = "teleportPosition",
        arguments = {"tank", "default", "default"},
        func = function(tank, pos, id)
            if tank:hasEffect(id) then
                tank.effects[id].publicTeleportLocation = pos
            end
        end
    }

    self.teleport = pings:register{
        name = "shoot",
        arguments = {"tank", "default", "default"},
        func = function(tank, pos, id)
            if tank:hasEffect(id) then
                tank.effects[id].cooldown = 1
                tank.effects[id].charges = tank.effects[id].charges - 1

                if tank.effects[id].charges == 0 then
                    tank:removeEffect(id)
                end
            end

            sounds:playSound("minecraft:entity.enderman.teleport", tank.pos)
            sounds:playSound("minecraft:entity.enderman.teleport", pos)

            tank.pos = pos
        end
    }

    self.equip = pings:register{
        name = "equip",
        arguments = {"tank", "default", "default"},
        func = function(tank, charges, id)
            if not tank:hasEffect(id) then
                if tank:hasEffectByName("TeleportEffect") then
                    tank:removeEffect(tank:getEffectByName("TeleportEffect"))
                end
                tank:addEffect(id, TeleportEffect:new(self, tank, charges, id))
            else
                tank.effects[id].charges = charges
            end
        end
    }

    self.state = state
    self.bullets = {}
end

function Teleport:_applyAfterPing(tank, charges, id)
    util.removeWeaponEffects(tank)
    id = id or util.intID()
    tank:addEffect(id, TeleportEffect:new(self, tank, charges, id))
end

function Teleport:render()
    
end

function Teleport:tick()

end

function Teleport:apply(tank)
    self.equip(tank, 4, util.intID())
end

function Teleport:generateIconGraphics(group)
    group:newItem("ee"):setItem("ender_pearl")
end

return Teleport