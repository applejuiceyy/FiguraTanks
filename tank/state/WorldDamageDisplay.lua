local class              = require("tank.class")
local util               = require("tank.util")

local WorldDamageDisplay = class("WorldDamageDisplay")
local DamageCreator      = class("DamageCreator")
local BlockDamage        = class("BlockDamage")


local blockstateCache = {}
local damageTextures = {}


for i = 0, 9 do
    table.insert(damageTextures, textures:fromVanilla("block-breaking-" .. i, "minecraft:textures/block/destroy_stage_" .. math.floor(i) .. ".png"))
end

local function graduallyConvertTextures()
    local currentTexture = 1
    local currentX = 0
    local currentY = 0

    return function()
        currentX = currentX + 1
        if currentX >= 16 then
            currentX = 0
            currentY = currentY + 1
            if currentY >= 16 then
                currentY = 0
                damageTextures[currentTexture]:update()
                currentTexture = currentTexture + 1
                if currentTexture > #damageTextures then
                    return true
                end
            end
        end
        local texture = damageTextures[currentTexture]
        local pixel = texture:getPixel(currentX, currentY)
        texture:setPixel(currentX, currentY, vec(0, 0, 0, (1 - (pixel.x + pixel.y + pixel.z) / 3)))
    end
end

local task = graduallyConvertTextures()

events.TICK:register(function()
    if task() then
        return events.TICK:remove("convert-textures")
    end
    if task() then
        return events.TICK:remove("convert-textures")
    end
    if task() then
        return events.TICK:remove("convert-textures")
    end
end, "convert-textures")

local function destroyBlock(pos)
    host:sendChatCommand("setblock " .. pos.x .. " " .. pos.y .. " " .. pos.z .. " air destroy")
end

local function addCacheEntry(matrix, highShape, lowShape, invertX, invertY, cullingOrder, isCulled, cache)
    if invertX then
        highShape.x = 1 - highShape.x
        lowShape.x = 1 - lowShape.x
        local t = highShape.x
        highShape.x = lowShape.x
        lowShape.x = t
    end
    if invertY then
        highShape.y = 1 - highShape.y
        lowShape.y = 1 - lowShape.y
        local t = highShape.y
        highShape.y = lowShape.y
        lowShape.y = t
    end

    local place = "NONE"
    if isCulled then
        place = cullingOrder
    end

    if cache[place] == nil then
        cache[place] = {}
    end

    table.insert(cache[place], {
        matrix = matrix,
        lowShape = lowShape,
        highShape = highShape
    })
end

local function generateCache(blockstate, cache)
    for _, collision in ipairs(blockstate:getOutlineShape()) do
        local highCollisionShape, lowCollisionShape = collision[2], collision[1]

        addCacheEntry(util.transform(
            matrices.rotation4(90,0, 0),
            matrices.scale4(1,1,-1),
            matrices.translate4(16, 0, 0),
            matrices.translate4(lowCollisionShape._y_ * 16 - 0.01)
        ), highCollisionShape.xz, lowCollisionShape.xz, true, false, "BOTTOM", lowCollisionShape.y == 0, cache)
        
        addCacheEntry(util.transform(
            matrices.rotation4(0, 180, 0),
            matrices.rotation4(-90,0, 0),
            matrices.translate4(highCollisionShape._y_ * 16 + 0.01),
            matrices.translate4(0, 0, 0)
        ), highCollisionShape.xz, lowCollisionShape.xz, false, false, "TOP", highCollisionShape.y == 1, cache)
        
        addCacheEntry(util.transform(
            matrices.scale4(1, -1, 1),
            matrices.translate4(highCollisionShape.__z * 16 + 0.01),
            matrices.translate4(16, 0, 0)
        ), highCollisionShape.xy, lowCollisionShape.xy, true, false, "SOUTH", highCollisionShape.z == 1, cache)

        addCacheEntry(util.transform(
            matrices.scale4(-1, -1, 1),
            matrices.translate4(lowCollisionShape.__z * 16 - 0.01),
            matrices.translate4(0, 0, 0)
        ), highCollisionShape.xy, lowCollisionShape.xy, false, false, "NORTH", lowCollisionShape.z == 0, cache)

        addCacheEntry(util.transform(
            matrices.rotation4(0, 90, 0),
            matrices.translate4(lowCollisionShape.x__ * 16 - 0.01),
            matrices.translate4(0, 16, 0)
        ), highCollisionShape.zy, lowCollisionShape.zy, false, true, "WEST", lowCollisionShape.x == 0, cache)

        addCacheEntry(util.transform(
            matrices.rotation4(0, 90, 0),
            matrices.translate4(highCollisionShape.x__ * 16 + 0.01),
            matrices.scale4(1, -1, 1)
        ), highCollisionShape.zy, lowCollisionShape.zy, false, false, "EAST", highCollisionShape.x == 1, cache)
    end
end

local cullingOffset = {
    NONE = vec(8, 8, 8),
    TOP = vec(8, 8 + 16, 8),
    BOTTOM = vec(8, 8 - 16, 8),

    SOUTH = vec(8, 8, 8 + 16),
    NORTH = vec(8, 8, 8 - 16),

    WEST = vec(8 - 16, 8, 8),
    EAST = vec(8 + 16, 8, 8)
}

local blockThatCulls = {
    NONE = nil,
    TOP = vec(0, 1, 0),
    BOTTOM = vec(0, -1, 0),

    SOUTH = vec(0, 0, 1),
    NORTH = vec(0, 0, -1),

    WEST = vec(-1, 0, 0),
    EAST = vec(1, 0, 0)
}


function WorldDamageDisplay:init(state)
    self.activeCreators = {}
    self.blockDamagePos = {}
    self.numberOfDamages = 0
    
    self.currentDamagePos = nil
    self.shouldRemove = false
end

function WorldDamageDisplay:tick()
    for creator in pairs(self.activeCreators) do
        for i = 0, 3 do
            if creator:update() then
                self.activeCreators[creator] = nil
            end
        end
        break
    end
    local times = math.floor(self.numberOfDamages / 100)

    if times == 0 and world.getTime() % 100 > self.numberOfDamages then
        return
    end

    for i = 0, times do
        local key, value = next(self.blockDamagePos, self.currentDamagePos)

        if self.shouldRemove then
            self.blockDamagePos[self.currentDamagePos] = nil
            self.shouldRemove = false
        end

        if key == nil then
            self.currentDamagePos = nil
            return
        end
        self.currentDamagePos = key

        local damage = self.blockDamagePos[self.currentDamagePos]
        local block = world.getBlockState(damage.holder.pos)

        if damage.holder.working and damage.holder.lastDamage + 100 < world.getTime() then
            if damage.holder.originalBlockStateString ~= block:toStateString() then
                damage.holder:deactivate()
                self.shouldRemove = true
                self.numberOfDamages = self.numberOfDamages - 1
            else
                local repair = math.max(1, damage.holder.resistance / 2)
                if damage.damage < repair and damage.holder.keepAlive == 0 then
                    damage.holder:spawnParticles()
                    damage.holder:spawnStepSounds("Block magically repairs")
                    damage.holder:deactivate()
                    self.shouldRemove = true
                    self.numberOfDamages = self.numberOfDamages - 1
    
                elseif damage.damage >= repair then
                    damage.damage = damage.damage - repair
                    damage.holder:setDamage(damage.damage / damage.holder.resistance)
                    damage.holder:spawnParticles()
                    damage.holder:spawnStepSounds("Block magically repairs")
                    damage.holder:updateCullGroups()
                end
            end
        end
    end
end

function WorldDamageDisplay:createDamageCreator(origin, damage)
    local creator = DamageCreator:new(self, origin, damage or 9)
    self.activeCreators[creator] = true
    return creator
end

function BlockDamage:init(pos)
    self.pos = pos
    self.keepAlive = 0
    self.working = false
    self.lastDamage = 0

    self.tasksPerCull = {}
    self.cullGroups = {}
    self.cullGroupIsShowing = {}


    local block = world.getBlockState(pos)
    self.originalBlock = block
    self.resistance = block:getBlastResistance() / 0.3 + 0.3
    self.originalBlockStateString = block:toStateString()
    self:fetchOrGenerateTasks(block)
end

function BlockDamage:fetchOrGenerateTasks(blockstate)
    local s = blockstate:toStateString()

    if blockstateCache[s] == nil then
        local cache = {}
        generateCache(blockstate, cache)
        blockstateCache[s] = cache
    end

    self:generateTasksFromCache(blockstateCache[s])
end

function BlockDamage:generateTasksFromCache(cache)
    for cullingOrder, entries in pairs(cache) do
        for _, entry in ipairs(entries) do
            self:addTask(entry.matrix, entry.highShape, entry.lowShape, cullingOrder)
        end
    end
end

function BlockDamage:addTask(matrix, highShape, lowShape, cullingOrder)
    local group
    if self.cullGroups[cullingOrder] == nil then
        group = util.group()
        self.cullGroupIsShowing[cullingOrder] = false
        self.cullGroups[cullingOrder] = group
        group:setPos(self.pos * 16 + cullingOffset[cullingOrder])
    else
        group = self.cullGroups[cullingOrder]
    end

    local task = group:newSprite(util.stringID())
        :matrix(util.transform(matrices.scale4((highShape - lowShape).xy_), matrices.translate4(-lowShape.xy_ * 16), matrix, matrices.translate4(-cullingOffset[cullingOrder])))
        :setRenderType("TRANSLUCENT_CULL")

    if self.tasksPerCull[cullingOrder] == nil then
        self.tasksPerCull[cullingOrder] = {}
        
    end
    self.tasksPerCull[cullingOrder][task] = {highShape, lowShape}

    return task
end

function BlockDamage:setDamage(stage)
    for _, tasks in pairs(self.tasksPerCull) do
        for task, shape in pairs(tasks) do
            local p = (shape[1] - shape[2]) * 16
            task:texture(damageTextures[math.floor(stage) + 1])
                    :uv(shape[2])
                    :region(p)
        end
    end
    return self
end

function BlockDamage:spawnStepSounds(subtitle)
    if math.random() > 0.5 then
        sounds[self.originalBlock:getSounds().step]:pos(self.pos):subtitle(subtitle):play()
    end
    return self
end


function BlockDamage:activate()
    if self.working then
        error()
    end
    self.working = true
    self:updateCullGroups()
    self:spawnParticles()
    self:spawnStepSounds("Block takes damage")
end

function BlockDamage:updateCullGroups()
    for cullGroup, group in pairs(self.cullGroups) do
        local shouldShow = true
        if blockThatCulls[cullGroup] ~= nil then
            local pos = blockThatCulls[cullGroup] + self.pos
            shouldShow = not world.getBlockState(pos):isSolidBlock()
        end
        if shouldShow ~= self.cullGroupIsShowing[cullGroup] then
            if shouldShow then
                models.world:addChild(group)
            else
                models.world:removeChild(group)
            end
        end
        self.cullGroupIsShowing[cullGroup] = shouldShow
    end
end

function BlockDamage:deactivate()
    self.working = false
    for order, group in pairs(self.cullGroups) do
        self.cullGroupIsShowing[order] = false
        models.world:removeChild(group)
    end
end

function BlockDamage:spawnParticles(particle)
    local collisionShape = self.originalBlock:getCollisionShape()
    if #collisionShape > 0 then
        pcall(function()
            for i = 0, 10 do
                local shape = collisionShape[math.random(1, #collisionShape)]
                particles:newParticle(particle or ("block " .. self.originalBlock.id), self.pos + vec(math.lerp(shape[1].x, shape[2].x, math.random()), math.lerp(shape[1].y, shape[2].y, math.random()), math.lerp(shape[1].z, shape[2].z, math.random())))
            end
        end)
    end

    return self
end

function BlockDamage:markLastDamaged()
    self.lastDamage = world.getTime()
end





function DamageCreator:init(owner, origin, damage)
    self.toIncrement = {}
    self.toActivate = {}
    self.visited = {}
    self.toExpand = {}

    self:expandTo(origin, damage)

    self.destroyBlocks = false
    self.penetrateBlocks = false

    self.applying = false

    self.owner = owner
end

function DamageCreator:canDestroyBlocks()
    self.destroyBlocks = true
    return self
end

function DamageCreator:canPenetrateBlocks()
    self.penetrateBlocks = true
    return self
end

function DamageCreator:update()
    if #self.toExpand <= 0 then
        return true
    end

    local cell = table.remove(self.toExpand, 1)
    local s = util.serialisePos(cell.origin)
    local origin = cell.origin

    if self.owner.blockDamagePos[s] ~= nil then
        local data = self.owner.blockDamagePos[s]
        data.holder.keepAlive = data.holder.keepAlive + 1
        if self.applying then
            self:incrementDamage(data, cell.damage)
        else
            self.toIncrement[data] = cell.damage
        end
    else
        local struct = {
            holder = BlockDamage:new(cell.origin),
            damage = cell.damage
        }
        self.owner.blockDamagePos[s] = struct
        self.owner.numberOfDamages = self.owner.numberOfDamages + 1
        if self.applying then
            self:activateDamage(struct)
        else
            self.toActivate[struct] = true
        end
    end

    self:expandTo(origin + vec(0, 1, 0), cell.damage)
    self:expandTo(origin + vec(0, -1, 0), cell.damage)
    self:expandTo(origin + vec(1, 0, 0), cell.damage)
    self:expandTo(origin + vec(-1, 0, 0), cell.damage)
    self:expandTo(origin + vec(0, 0, 1), cell.damage)
    self:expandTo(origin + vec(0, 0, -1), cell.damage)

    return false
end

function DamageCreator:runOut()
    while not self:update() do end
    return self
end

function DamageCreator:apply()
    self.applying = true

    for data, damage in pairs(self.toIncrement) do
        self:incrementDamage(data, damage)
    end

    for data in pairs(self.toActivate) do
        self:activateDamage(data)
    end
end

function DamageCreator:incrementDamage(data, damage)
    data.holder.keepAlive = data.holder.keepAlive - 1
    local newDamage = data.damage + damage
    self:setDamage(data, newDamage)
end

function DamageCreator:activateDamage(data)
    if not self:setDamage(data, data.damage) then
        data.holder:activate()
    end
end

function DamageCreator:setDamage(data, damage)
    if damage > 9 * data.holder.resistance and host:isHost() and self.destroyBlocks then
        destroyBlock(data.holder.pos)
        data.holder:deactivate()
        self.owner.numberOfDamages = self.owner.numberOfDamages - 1
        self.owner.blockDamagePos[util.serialisePos(data.holder.pos)] = nil
        return true
    end
    data.damage = math.min(damage, 9 * data.holder.resistance)
    data.holder:setDamage(data.damage / data.holder.resistance)
    data.holder:spawnParticles()
    data.holder:spawnStepSounds()
    data.holder:markLastDamaged()
    return false
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

function DamageCreator:expandTo(pos, damage)
    local s = util.serialisePos(pos)
    if self.visited[s] then
        return
    end
    self.visited[s] = true
    local block = world.getBlockState(pos)

    if not block:hasCollision() then
        return
    end

    if (not self.penetrateBlocks) and isSolid(pos, pos + vec(0, 1, 0), pos + vec(0, -1, 0), pos + vec(1, 0, 0), pos + vec(-1, 0, 0), pos + vec(0, 0, 1), pos + vec(0, 0, -1)) then
        return
    end

    local falloff = self:computeDamageFalloff(block, damage)

    if falloff >= 0 then
        table.insert(self.toExpand, {origin = pos, damage = falloff})
    end
end

function DamageCreator:computeDamageFalloff(block, damage)
    return damage - 10
end

return WorldDamageDisplay