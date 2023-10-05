local class       = require("tank.class")
local util        = require("tank.util")

local CustomKeywords = class("CustomKeywords")

local function loadScript(obj, name)
    return load(table.concat(obj, "\n"), name)
end

local function generateFunction(model, data, thing)
    if data.executionStyle == "STRING" then
        return function() return thing end
    else
        local generation = {}
        if data.injectedVariables ~= nil then
            for variable, defaultValue in pairs(data.injectedVariables) do
                table.insert(generation, "local " .. variable)
            end
            table.insert(generation, "do")
            table.insert(generation, "local _ = ...")
            for variable, defaultValue in pairs(data.injectedVariables) do
                table.insert(generation, variable .. " = _[\"" .. variable .. "\"]")
            end
            table.insert(generation, "end")
        end
        if data.executionStyle == "STATEMENT" then
            table.insert(generation, thing)
        else
            table.insert(generation, "return " .. thing)
        end

        local original, message = loadScript(generation, thing)
        if message ~= nil or original == nil then
            if data.executionStyle ~= "STATEMENT" then
                table.remove(generation)
                table.insert(generation, thing)

                local thisTime = loadScript(generation, thing)

                if thisTime ~= nil then
                    original = thisTime
                    goto happy
                end
            end
            return error(message, 0)
        end

        ::happy::

        return function(args)

            if args == nil then
                return original({self = model}, data.injectedVariables)
            end
            args.self = model
            return original(setmetatable(args, {__index = data.injectedVariables}))
        end
    end
end

function CustomKeywords:init(model, keywordInformation)
    self.indexed = {}
    self.keywordInformation = keywordInformation

    for k in pairs(self.keywordInformation) do
        self.indexed[k] = {}
    end

    self:collect(model)
end

-- code looks garbage, it was retrofitted
function CustomKeywords:collect(model)
    for _, v in pairs(model:getChildren()) do
        self:collect(v)
    end
    local name = model:getName()
    for k, data in pairs(self.keywordInformation) do
        local n = 1
        for stuff, after in string.gmatch(name, "(.+);()") do
            n = after
            self:parseName(k, stuff, model, data)
        end
        self:parseName(k, string.sub(name, n), model, data)
    end
end

function CustomKeywords:parseName(k, name, model, data)
    if string.sub(name, 1, string.len(k)) == k then
        local start, _, thing = string.find(name, "%[(.+)%]", string.len(k))
        if start ~= nil then
            self.indexed[k][model] = generateFunction(model, data, thing)
        else
            self.indexed[k][model] = function() end
        end
    end
end

function CustomKeywords:with(keywords, ...)
    for k, v in pairs(self.indexed) do
        if keywords[k] ~= nil then
            for model, thing in pairs(v) do
                keywords[k](model, thing, ...)
            end
        end
    end
end

function CustomKeywords:iterate(keyword)
    return pairs(self.indexed[keyword])
end

return CustomKeywords