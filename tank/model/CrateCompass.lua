local class       = require("tank.class")
local util        = require("tank.util")
local CrateCompass = class("CrateCompass")

function CrateCompass:init(opt)
    self.group = opt.group

    self.dequeueing = {}
    self.enqueueing = {}
end

function CrateCompass:update(pos)
    local floorPos = pos:copy():floor()
    for _, stuff in pairs(world.avatarVars()) do
        if stuff.__FiguraTanks_crates ~= nil then
            for str, data in pairs(stuff.__FiguraTanks_crates) do
                local location = data.location
                local conc
                if self.dequeueing[str] == nil then
                    local id = util.stringID()
                    local task = self.group:newBlock(id)
                        :block("redstone_block")
                    conc = {
                        id = id,
                        task = task,
                        molting = 1
                    }
                    self.enqueueing[str] = conc
                else
                    conc = self.dequeueing[str]
                    self.enqueueing[str] = conc
                    self.dequeueing[str] = nil
                end
                
                local relative = location - floorPos
                local isInView = relative.x >= -3 and relative.x <= 3 and relative.z >= -3 and relative.z <= 3

                local targetMolting = 1
                if isInView then
                    targetMolting = 0
                end

                conc.molting = math.lerp(conc.molting, targetMolting, 0.1)

                if conc.molting > 0.5 then
                    conc.task:block("redstone_block")
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
                            matrices.translate4(location * 16),
                            matrices.translate4(8, 0, 8)
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
            end
        end
    end

    for i, v in pairs(self.dequeueing) do
        self.group:removeTask(v.id)
    end

    self.dequeueing = self.enqueueing
    self.enqueueing = {}
end


return CrateCompass