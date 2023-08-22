local class       = require("tank.class")
local util        = require("tank.util")
local CustomKeywords = require("tank.model.CustomKeywords")
local TankModel      = require("tank.model.TankModel")

local WorldSlice = class("WorldSlice")

function WorldSlice:init(opt)
    self.opt = opt
    self.group = opt.group
    self.ugroup = util.group()
    self.group:addChild(self.ugroup)

    self.currentPosition = nil
    self.currentBestYaw = 0
end

local function isSolid(a, b, ...)
    local l = world.getBlockState(a)
    if not (l:isSolidBlock() or l.id:find("slab")) then
        return false
    end
    if b ~= nil then
        return isSolid(b, ...)
    end
    return true
end

function WorldSlice:update(newPosition)
    newPosition = newPosition:floor()
    local average = vec(0, 0, 0)

    if newPosition ~= self.currentPosition then
        self.currentPosition = newPosition
        
        self.ugroup:removeTask()

        for x = -2, 2 do
            for z = -2, 2 do
                for y = 1, -3, -1 do
                    local v = vec(x, y, z)
                    local cannonical = newPosition + v


                    local blockstate = world.getBlockState(cannonical)

                    
                    if blockstate:isSolidBlock() and blockstate:isFullCube() and v:length() ~= 0 then
                        if y == 1 then
                            average:add(v)
                        else
                            average:add(v / math.pow(v:length(), 4))
                        end

                    end

                    if self.opt.onBlock ~= nil then
                        self.opt.onBlock(self.ugroup, blockstate)
                    else
                        local task = self.ugroup:newBlock("gen-" .. math.random())
                            :block(blockstate)
                            :pos(cannonical * 16)

                        if self.opt.onTask ~= nil then
                            self.opt.onTask(task)
                        end
                    end

                    if isSolid(cannonical, cannonical + vec(1, 0, 0), cannonical + vec(-1, 0, 0), cannonical + vec(0, 0, 1), cannonical + vec(0, 0, -1)) then
                        break
                    end
                end
            end
        end

        self.currentBestYaw = math.deg(math.atan2(average.x, average.z))
    end

    return self.currentBestYaw
end

function WorldSlice:dispose()

end

return WorldSlice