local class       = require("tank.class")
local util        = require("tank.util")
local CustomKeywords = require("tank.model.CustomKeywords")
local TankModel      = require("tank.model.TankModel")
local WorldSlice     = require("tank.model.WorldSlice")

local CrateCompass = class("CrateCompass")

function CrateCompass:init(opt)
    self.group = opt.group

    self.dequeueing = {}
    self.enqueueing = {}
end

function CrateCompass:update(pos)
    for _, stuff in pairs(world.avatarVars()) do
        if stuff.__FiguraTanks_crates ~= nil then
            for str, data in pairs(stuff.__FiguraTanks_crates) do
                local location = data.location
                local conc
                if self.dequeueing[str] == nil then
                    local id = "gen-" .. math.random()
                    local task = self.group:newBlock(id)
                        :block("redstone_block")
                    conc = {
                        id = id,
                        task = task
                    }
                    self.enqueueing[str] = conc
                else
                    conc = self.dequeueing[str]
                    self.enqueueing[str] = conc
                    self.dequeueing[str] = nil
                end

                local diff = (location + vec(0.5, 0, 0.5)) - pos

                conc.task:matrix(
                    util.transform(
                        matrices.scale4(10 * math.pow(0.5, diff:length() / 4), 0.2, 0.4),
                        matrices.translate4(5 * 16, 0, 0),
                        matrices.rotation4(0, math.deg(math.atan2(diff.x, diff.z)) - 90, 0)
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