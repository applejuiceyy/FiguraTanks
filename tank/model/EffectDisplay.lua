local class       = require("tank.class")
local util        = require("tank.util.util")

local EffectDisplay = class("EffectDisplay")

function EffectDisplay:init(opt)
    self.group = opt.group
    self.tank = opt.tank
    self.positioner = opt.positioner

    self.effect = {}
    self.effectById = {}
end

function EffectDisplay:tick()
    local idx = 1
    local needReorder = false
    while idx <= #self.effect do

        local struct = self.effect[idx]
        if self.tank:hasEffect(struct.id) then
            util.callOn(struct.lifecycle, "tick")
            idx = idx + 1
        else
            self.effectById[struct.id] = nil
            util.callOn(struct.lifecycle, "dispose")
            self.group:removeChild(struct.group)
            table.remove(self.effect, idx)
            needReorder = true
        end
    end

    for id, effect in pairs(self.tank.effects) do
        if not self.effectById[id] then
            self.effectById[id] = true
            local group = util.group()
            util.addSlotTexture(group)
            self.group:addChild(group)
            table.insert(self.effect, {
                id = id,
                group = group,
                lifecycle = effect:generateIconGraphics(group)
            })
            needReorder = true
        end
    end

    if needReorder then
        self:reorderItems()
    end
end

function EffectDisplay:reorderItems()
    for i, struct in ipairs(self.effect) do
        struct.group:setPos(self.positioner(i, #self.effect))
    end
end

function EffectDisplay:dispose()
    for i, struct in ipairs(self.effect) do
        self.group:removeChild(struct.group)
    end
end


return EffectDisplay