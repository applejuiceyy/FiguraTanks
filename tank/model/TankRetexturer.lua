local class       = require("tank.class")
local util        = require("tank.util")
local Event      = require("tank.events.events")
local CustomKeywords = require("tank.model.CustomKeywords")

---@params any
local DamageRetexturer = class("DamageRetexturer")

local retexturedTextures = {}

local highPriority = {}

local accuracy = 10
local ending = "_destroyable"

local function createBaker(original, overlay, destination, damagePercentage, x, completion)
    local currentX = 0
    local currentY = 0
    local dimensions = original:getDimensions()
    return function()
        if currentX >= dimensions.x then
            currentX = 0
            currentY = currentY + 1
            if currentY >= dimensions.y then
                destination:update()
                completion()
                return true
            end
        end
        local pixel = original:getPixel(currentX, currentY)
        local overlayPixel = overlay:getPixel(currentX, currentY)

        if pixel.w < 0.1 then
            destination:setPixel(currentX + x, currentY, vec(0, 0, 0, 0))
            currentX = currentX + 1
            return
        end

        local finalPixel = pixel

        local difference = math.max(0, math.min((damagePercentage - overlayPixel.x) * (overlayPixel.z * 2 + 1), 1))

        if difference < 0.5 then
            finalPixel = math.lerp(finalPixel, vec(0, 0, 0, 1), difference * 2)
        else
            finalPixel = math.lerp(vec(0, 0, 0, 1), vec(1, 0.2, 0, 1), (difference - 0.5) * 2)
        end
        
        if damagePercentage > overlayPixel.y then
            finalPixel = vec(0, 0, 0, 0)
        end

        destination:setPixel(currentX + x, currentY, finalPixel)
        currentX = currentX + 1
    end
end

for i, v in ipairs(textures:getTextures()) do
    local name = v:getName()

    if string.sub(name, -string.len(ending)) == ending then
        local cannonical = string.sub(name, 1, -string.len(ending) - 1)

        local dimensions = v:getDimensions()
        local renderSlotTasks = {}
        local renderedSlots = {}
        local bakedTexture = textures:newTexture(name .. "-destruction-baked", dimensions.x * accuracy, dimensions.y)
        bakedTexture:fill(0, 0, dimensions.x * accuracy, dimensions.y, 0, 0, 0, 0)
        
        
        for a = 1, accuracy do
            local baker
            baker = createBaker(textures[cannonical], v, bakedTexture, (a - 1) / (accuracy - 1), (a - 1) * dimensions.x, function()
                renderedSlots[a]:fire()
                renderedSlots[a] = true
                highPriority[baker] = nil
                renderSlotTasks[a] = nil
            end)
            renderSlotTasks[a] = baker
            renderedSlots[a] = Event:new()
        end

        retexturedTextures[cannonical] = {
            accuracy = accuracy,
            renderedSlots = renderedSlots,
            renderSlotTasks = renderSlotTasks,
            texture = bakedTexture,
            slotDimensions = dimensions
        }
    end
end

local function stepBaking()
    local key, value = next(highPriority)

    if key ~= nil then
        for i = 1, 100 do
            if key() then
                return
            end
        end
        return
    end

    for name, data in pairs(retexturedTextures) do
        for _, baker in pairs(data.renderSlotTasks) do
            baker()
            return
        end
    end
end

function events.tick()
    stepBaking()
end

-- TODO: make this work with any texture after getTexture is widespread

function DamageRetexturer:init(model)
    self.model = model

    self.keywords = CustomKeywords:new(model, {
        NoRetexture = {}
    })
    
    self.unsubber = nil
    self.currentSlot = -1
end

function DamageRetexturer:gather()
    
end

function DamageRetexturer:setHealthPercentage(healthPercentage)
    local data = retexturedTextures["textures.tank"]
    local slot0 = math.floor((1 - math.min(math.max(healthPercentage, 0), 1)) * (data.accuracy - 1))
    if self.currentSlot == slot0 then
        return
    end

    if self.unsubber ~= nil then
        self.unsubber:remove()
        self.unsubber = nil

        local task = data.renderSlotTasks[self.currentSlot + 1]
        if task ~= nil and highPriority[task] ~= nil then
            highPriority[task] = highPriority[task] - 1
            if highPriority[task] == 0 then
                highPriority[task] = nil
            end
        end
    end
    self.currentSlot = slot0
    local g = data.renderedSlots[slot0 + 1]

    if type(g) == "boolean" then
        self:setTexture(data, slot0)
    else
        local task = data.renderSlotTasks[slot0 + 1]
        if highPriority[task] == nil then
            highPriority[task] = 0
        end
        highPriority[task] = highPriority[task] + 1
        self.unsubber = g:register(function()
            self:setTexture(data, slot0)
        end)
    end
end

function DamageRetexturer:setTexture(data, slot0)
    local u = util.transform(
        matrices.scale3(1 / data.accuracy, 1),
        matrices.translate3(slot0, 0)
    )
    self.model:setPrimaryTexture("CUSTOM", retexturedTextures["textures.tank"].texture)
    self.model:uvMatrix(u)
    for model in self.keywords:iterate("NoRetexture") do
        -- again improve this when getTextures
        model:setPrimaryTexture("CUSTOM", textures["textures.hud"])
        model:uvMatrix(u:inverted())
    end
end



return DamageRetexturer