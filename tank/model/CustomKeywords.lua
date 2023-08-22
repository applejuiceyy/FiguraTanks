local class       = require("tank.class")
local util        = require("tank.util")

local CustomKeywords = class("CustomKeywords")

function CustomKeywords:init(model, keywords)
    self.indexed = {}
    self.keywords = keywords

    for k in pairs(self.keywords) do
        self.indexed[k] = {}
    end

    self:collect(model)
end

function CustomKeywords:collect(model)
    for _, v in pairs(model:getChildren()) do
        self:collect(v)
    end

    for k in pairs(self.keywords) do
        if string.sub(model:getName(), 1, string.len(k)) == k then
            self.indexed[k][model] = true
        end
    end
end

function CustomKeywords:render(delta)
    return self:with(delta, self.keywords)
end

function CustomKeywords:with(delta, keywords)
    for k, v in pairs(self.indexed) do
        local func = keywords[k] or function(_, _) end

        for model in pairs(v) do
            func(delta, model)
        end
    end
end

function CustomKeywords:iterate(keyword)
    return pairs(self.indexed[keyword])
end

return CustomKeywords