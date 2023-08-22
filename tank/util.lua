local function transform(a, b, ...)
    if b == nil then
        return a
    end

    return transform(b * a, ...)
end

local function createGroup()
    local e = models.dummy:newPart("gen-" .. math.random())
    models.dummy:removeChild(e)
    return e
end

local function deepcopy(model)
    local copy = model:copy(model:getName())

    for _, child in ipairs(copy:getChildren()) do
        copy:removeChild(child)
        copy:addChild(deepcopy(child))
    end
    
    return copy
end

local function gradualFetchSerialisePos(accumulate, a, ...)
    if a == nil then
        return accumulate
    end
    return gradualFetchSerialisePos(accumulate .. ":" .. a, ...)
end

local function serialisePos(pos)
    return gradualFetchSerialisePos("", pos:unpack())
end

return {
    group = createGroup,
    deepcopy = deepcopy,
    transform = transform,
    serialisePos = serialisePos
}