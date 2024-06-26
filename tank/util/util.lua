local nid = world.getTime()

local function intID()
    nid = nid + 1
    return nid
end

local function stringID()
    return "gen-" .. intID()
end

local function transform(a, b, ...)
    if b == nil then
        return a
    end

    return transform(b * a, ...)
end

local function createGroup()
    local e = models.dummy:newPart(stringID())
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

local function shallowCopy(t)
    local t2 = {}
    for k,v in pairs(t) do
        t2[k] = v
    end
    return t2
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

local util
util = {
    intID = intID,
    stringID = stringID,
    unitRandom = function()
        return vec(math.random(), math.random(), math.random())
    end,

    centeredUnitRandom = function()
        return vec(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
    end,

    xzCenteredUnitRandom = function()
        return vec(math.random() - 0.5, math.random(), math.random() - 0.5)
    end,

    group = createGroup,
    worldGroup = function()
        local group = createGroup()
        models.world:addChild(group)
        group:setParentType("WORLD")
        return group
    end,
    deepcopy = deepcopy,
    transform = transform,
    serialisePos = serialisePos,
    dependsOn = function(consumer, predicate)
        return function(func)
            consumer(function()
                if predicate() then
                    func()
                end
            end)
        end
    end,

    notHost = function()
        if host:isHost() then
            error({nonerror = true})
        end
    end,

    callOn = function(obj, name, ...)
        if obj == nil or obj[name] == nil then
            return
        end
        if obj.functionsUseSelf then
            return obj[name](obj, ...)
        end
        return obj[name](...)
    end,

    addSlotTexture = function(group)
        return group:newSprite("slot")
        :setRenderType("TRANSLUCENT_CULL")
        :texture(textures["textures.slot"], 22, 22)
        :pos(11, 11, 1)
    end,

    vecify = function(a, b, ...)
        if type(a) ~= "number" and b == nil then
            return a
        end
        return vec(a, b, ...)
    end,
    injectGenericCustomKeywordsRegistry = function(obj, variables)
        local modelledVariable = shallowCopy(variables)
        modelledVariable.model = false
        modelledVariable.self = false
        obj.If = {
            injectedVariables = variables
        }
        obj.Unless = {
            injectedVariables = variables
        }
        obj.Pos = {
            injectedVariables = variables
        }
        obj.Rot = {
            injectedVariables = variables
        }
        obj.Scale = {
            injectedVariables = variables
        }
        obj.Do = {
            injectedVariables = modelledVariable,
            executionStyle = "STATEMENT"
        }

        return obj
    end,
    injectGenericCustomKeywordsExecution = function(obj, variables)
        return setmetatable(obj, {__index = {
            If = function(model, args)
                model:setVisible(args(variables))
            end,
    
            Unless = function(model, args)
                model:setVisible(not args(variables))
            end,

            Pos = function(model, args)
                model:setPos(util.vecify(args(variables)))
            end,

            Rot = function(model, args)
                model:setRot(util.vecify(args(variables)))
            end,

            Scale = function(model, args)
                model:setScale(util.vecify(args(variables)))
            end,

            Do = function(model, args)
                args(variables)
            end,
        }})
    end,

    pitchYawToUnitVector = function(thing)
        local ret = vectors.rotateAroundAxis(-thing.y, vec(1, 0, 0), vec(0, 0, 1))
        return vectors.rotateAroundAxis(thing.x, ret, vec(0, 1, 0))
    end,

    displayBox = function(mat, high, low)
        particles:newParticle("minecraft:dust 0.1 0.2 1 1", mat:apply(low.___ + high.xyz))
        particles:newParticle("minecraft:dust 0.1 0.2 1 1", mat:apply(low.x__ + high._yz))
        particles:newParticle("minecraft:dust 0.1 0.2 1 1", mat:apply(low._y_ + high.x_z))
        particles:newParticle("minecraft:dust 0.1 0.2 1 1", mat:apply(low.xy_ + high.__z))
        particles:newParticle("minecraft:dust 0.1 0.2 1 1", mat:apply(low.__z + high.xy_))
        particles:newParticle("minecraft:dust 0.1 0.2 1 1", mat:apply(low.x_z + high._y_))
        particles:newParticle("minecraft:dust 0.1 0.2 1 1", mat:apply(low._yz + high.x__))
        particles:newParticle("minecraft:dust 0.1 0.2 1 1", mat:apply(low.xyz + high.___))
    end,

    ---@param tank Tank
    removeWeaponEffects = function(tank)
        local v = {}
        for vid, effect in pairs(tank.effects) do
            if effect.isWeapon then
                v[vid] = true
            end
        end
        for vid in pairs(v) do
            tank:removeEffect(vid)
        end
    end
}

return util