local identifier = "[_%%a][_%%w]*"

local initial =
'---@params ([^\r\n]*)\r?\n()local%s*identifier%s*=%s*class%("(identifier)"%)'
local scourColonFunctions = "()function%s*()className():(identifier)%((.-)%)()"

initial = string.gsub(initial, "identifier", identifier)
scourColonFunctions = string.gsub(scourColonFunctions, "identifier", identifier)

local function getArgs(params, thing)
    local capturedParams = {}
    for param in params:gmatch(thing) do
        table.insert(capturedParams, param)
    end
    return capturedParams
end

local function doClass(text, diffs, params, varDeclarationStart, className)
    local capturedParams = getArgs(params, "[^ ]+")
    local capturedParamNames

    for functionStart, classNameStart, classNameEnd, functionName, funcArgs, functionEnd in text:gmatch(string.gsub(scourColonFunctions, "className", className)) do
        local otherParams = {}
        if functionName == "init" then
            capturedParamNames = getArgs(funcArgs, "%w+")
            table.insert(otherParams, "")
            for i, param in ipairs(capturedParams) do
                table.insert(otherParams, "---@param " .. capturedParamNames[i] .. " " .. param)
            end
        end
        
        diffs[#diffs+1] = {
            start  = classNameStart,
            finish = classNameEnd - 1,
            text   = "InferenceHack" .. className .. "Instance",
        }
        diffs[#diffs+1] = {
            start  = functionStart,
            finish = functionStart - 1,
            text   = string.format("---@param self %s\n---@diagnostic disable-next-line\n%s.%s = function(self%s) end\n---@param self %s\n",
                className .. table.concat(otherParams, "\n"), className, functionName, string.len(funcArgs) > 0 and ", " .. funcArgs or "", className ..  table.concat(otherParams, "\n")
            ),
        }
    end

    local p = ""
    for i, param in ipairs(capturedParams) do
        p = p .. (capturedParamNames[i] or ("param" .. i)) .. ": " .. param
        if i ~= #capturedParams then
            p = p .. ", "
        end
    end
    
    local computeFields = {}
    table.insert(computeFields, "---@class className: classNamePrototype")
    table.insert(computeFields, "---@field new nil")
    table.insert(computeFields, "---@field init nil")
    table.insert(computeFields, "local InferenceHackclassNameInstance = {}")
    table.insert(computeFields, "---@class classNamePrototype")
    table.insert(computeFields, "---@field class classNamePrototype")
    table.insert(computeFields, '---@field name "className"')
    table.insert(computeFields, "---@field __index classNamePrototype")
    table.insert(computeFields, "---@field new fun(self: classNamePrototype, funcArgs): className")
    table.insert(computeFields, "---@field init fun(self: className, funcArgs): nil")
    table.insert(computeFields, "")
    diffs[#diffs+1] = {
        start  = varDeclarationStart,
        finish = varDeclarationStart - 1,
        text   = string.gsub(string.gsub(table.concat(computeFields, "\n"), "className", className), "funcArgs", p),
    }
end

function OnSetText(uri, text)
    local diffs = {}

    for params, varDeclarationStart, className in text:gmatch(initial) do
        doClass(text, diffs, params, varDeclarationStart, className)
    end

    return diffs
end