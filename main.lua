local util = require "tank.util.util"

local function isString(thing)
    local success = pcall(string.len, thing)
    return success
end

local function onPet(uuid)

end

local click = keybinds:newKeybind("Petpet", "key.mouse.right")
local cooldown = 0
local knownDislikers = {}

local personPetting = nil
local petsForHyper = 0
local currentPets = 0
local hyperSize = 0
local time = 0



local hyperPets = {}

local avatarVarValue = nil

function pings.__ApplePetPet_pet(uuid)
    local entity = world.getEntity(uuid)
    avatarVarValue = uuid

    if entity == nil then
        return
    end

    local bounding = entity:getBoundingBox()

    for i = 0, 5 do
        local unitRandom = util.unitRandom() - vec(0.5, 0, 0.5)

        particles["heart"]
            :pos(unitRandom * bounding + entity:getPos())
            :scale(0.5, 0.5, 0.5)
            :spawn()
    end
end


function pings.__ApplePetPet_hyperPet(uuid, ammount)
    table.insert(hyperPets,{
        left = ammount,
        initial = ammount,
        time = time,
        uuid = uuid
    })
end

click:onPress(function()
    if player:isSneaking() then
        local entity = user:getTargetedEntity(host:getReachDistance())
        if entity ~= nil then
            return true
        end
    end
end)

events.TICK:register(function()
    time = time + 1
    avatar:store("__ApplePetPet_petting", avatarVarValue)
    avatarVarValue = nil

    for uuid, data in pairs(world.avatarVars()) do
        if isString(data.__ApplePetPet_petting) and player:getUUID() == data.__ApplePetPet_petting then
            onPet(uuid)
        end
    end

    if not click:isPressed() then
        personPetting = nil
    end

    if cooldown == 0 and click:isPressed() and player:isSneaking() then
        local entity = user:getTargetedEntity(host:getReachDistance())
        
        if entity ~= nil then
            if entity:hasAvatar() and entity:getVariable("__ApplePetPet_nopet") ~= nil then
                if knownDislikers[entity:getUUID()] == nil then
                    knownDislikers[entity:getUUID()] = 100
                    host:setActionbar(string.format('[{"text":"I don\'t think "}, {"text":%q, "color": "#ff8844"}, {"text":" likes pets"}]', entity:getName()))
                end
            else
                if personPetting == nil or entity:getUUID() ~= personPetting then
                    personPetting = entity:getUUID()
                    petsForHyper = 10
                    currentPets = 0
                    hyperSize = 0
                end
                host:swingArm()
                pings.__ApplePetPet_pet(entity:getUUID())
                cooldown = 5
                currentPets = currentPets + 1
                petsForHyper = math.max(petsForHyper * 0.99, 1)
                if currentPets >= math.ceil(petsForHyper) then
                    pings.__ApplePetPet_hyperPet(entity:getUUID(), math.min(hyperSize, 200))
                    hyperSize = hyperSize + 1
                    currentPets = 0
                end
            end
        end
    end

    local index = 1
    while index <= #hyperPets do
        local info = hyperPets[index]
        local done = info.initial - info.left
        info.left = info.left - 1

        local entity = world.getEntity(info.uuid)
    
        if entity ~= nil then
            local bounding = (entity:getBoundingBox().xx / 2):length()

            local relativePos = vectors.rotateAroundAxis(done * 20 + info.time * 10, vec(bounding, done / 10, 0), vec(0, 1, 0))

            particles["heart"]
                :pos(relativePos + entity:getPos())
                :scale(0.5, 0.5, 0.5)
                :velocity(vectors.rotateAroundAxis(90, relativePos.x_z / 5, vec(0, 1, 0)))
                :spawn()
        end

        if info.left < 0 then
            table.remove(hyperPets, index)
            index = index - 1
        end
        index = index + 1
    end

    for uuid, n in pairs(knownDislikers) do
        knownDislikers[uuid] = n - 1
        if knownDislikers[uuid] < 0 then
            knownDislikers[uuid] = nil
        end
    end

    if cooldown > 0 then
        cooldown = cooldown - 1
    end
end)

---@param o number
---@return number
local function e(o)
    return
end

---@type {t:fun(o:number):number}
local chees = {
    t = function (o)
        return "e"
    end
}