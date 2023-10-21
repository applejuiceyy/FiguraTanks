local class       = require("tank.class")
local util        = require("tank.util.util")
local CrateCompass = class("CrateCompass")

function CrateCompass:init(opt)
    self.group = opt.group

    self.dequeueing = {}
    self.enqueueing = {}
end

function CrateCompass:update(pos)
    local State = require("tank.state.State")

    local floorPos = pos:copy():floor()
    for uuid, crateid, data in State.crateSpawner.sharedWorldState:iterateAllEntities() do
        local location = data.location
        local conc
        local i = uuid .. ":" .. crateid
        if self.dequeueing[i] == nil then
            local id = util.stringID()
            local task = self.group:newBlock(id)
                :block("redstone_block")
            
            local icon
            if State.itemManagers[data.kind] ~= nil then
                icon = util.group()
                State.itemManagers[data.kind]:generateIconGraphics(icon)
                self.group:addChild(icon)
            end

            conc = {
                id = id,
                task = task,
                icon = icon,
                molting = 1,
                flashing = 0
            }
            self.enqueueing[i] = conc
        else
            conc = self.dequeueing[i]
            self.enqueueing[i] = conc
            self.dequeueing[i] = nil
        end
        
        local relative = location - floorPos
        local isInView = relative.x >= -3 and relative.x <= 3 and relative.z >= -3 and relative.z <= 3

        local targetMolting = 1
        if isInView then
            targetMolting = 0
        end

        conc.molting = math.lerp(conc.molting, targetMolting, 0.1)

        if data.timeGone ~= 0 and data.timeGone ~= nil then
            if data.timeGone == world.getTime() then
                conc.flashing = conc.flashing + 1
            else
                conc.flashing = conc.flashing + math.min(1, 10 / (data.timeGone -  world.getTime()))
            end
        end

        if conc.flashing % 2 > 1 then
            conc.task:block("white_concrete")
        elseif conc.molting > 0.5 then
            conc.task:block(data.golden and "gold_block" or "redstone_block")
        elseif world.getTime() % 20 < 10 then
            conc.task:block("white_concrete")
        else
            conc.task:block("barrel[facing=up]")
        end

        local diff = (location + vec(0.5, 0, 0.5)) - pos

        conc.task:matrix(
            math.lerp(
                util.transform(
                    matrices.translate4(-8, 0, -8),
                    matrices.scale4(0.6, 0.8, 0.6),
                    matrices.translate4(location * 16)
                ),
                util.transform(
                    matrices.scale4(10 * math.pow(0.5, diff:length() / 4), 0.2, 0.4),
                    matrices.translate4(5 * 16, 0, 0),
                    matrices.rotation4(0, math.deg(math.atan2(diff.x, diff.z)) - 90, 0),
                    matrices.translate4(pos * 16)
                ),
                conc.molting
            )
        )

        if conc.icon ~= nil then
            conc.icon:matrix(
                math.lerp(
                    util.transform(
                        matrices.scale4(0.6, 0.6, 10),
                        matrices.xRotation4(90),
                        --matrices.translate4(8, 0, 8),
                        matrices.translate4(location * 16),
                        matrices.translate4(0, 0.85 * 16, 0)
                    ),
                    util.transform(
                        matrices.scale4(1.3, 1.3, 10),
                        matrices.xRotation4(90),
                        matrices.translate4((5 + 10 * math.pow(0.5, diff:length() / 4) + 1) * 16, 0.3 * 16, 0.2 * 16),
                        matrices.rotation4(0, math.deg(math.atan2(diff.x, diff.z)) - 90, 0),
                        matrices.translate4(pos * 16)
                    ),
                    conc.molting
                )
            )
        end
    end

    for i, v in pairs(self.dequeueing) do
        self.group:removeTask(v.id)
        if v.icon ~= nil then
            self.group:removeChild(v.icon)
        end
    end

    self.dequeueing = self.enqueueing
    self.enqueueing = {}
end


return CrateCompass