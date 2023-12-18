local function collidesWithRectangle(highpos, lowpos, highthat, lowthat)
    
    --[[particles:newParticle("minecraft:dust 1 1 1 1", lowthat.___ + highthat.xyz)
    particles:newParticle("minecraft:dust 1 1 1 1", lowthat.x__ + highthat._yz)
    particles:newParticle("minecraft:dust 1 1 1 1", lowthat._y_ + highthat.x_z)
    particles:newParticle("minecraft:dust 1 1 1 1", lowthat.xy_ + highthat.__z)
    particles:newParticle("minecraft:dust 1 1 1 1", lowthat.__z + highthat.xy_)
    particles:newParticle("minecraft:dust 1 1 1 1", lowthat.x_z + highthat._y_)
    particles:newParticle("minecraft:dust 1 1 1 1", lowthat._yz + highthat.x__)
    particles:newParticle("minecraft:dust 1 1 1 1", lowthat.xyz + highthat.___)
]]

    local e = highpos.x > lowthat.x and highpos.y > lowthat.y and highpos.z > lowthat.z
    and lowpos.x < highthat.x and lowpos.y < highthat.y and lowpos.z < highthat.z

    return e
end

local function collidesWithBlock (block, highpos, lowpos, shapeGetter)
    for _, collider in pairs((shapeGetter or block.getCollisionShape)(block)) do
        local blockpos = block:getPos()

        local colliding = collidesWithRectangle(highpos, lowpos, blockpos + collider[2], blockpos + collider[1])

        if colliding then
            return collider
        end
    end


    return false
end

local collision
collision = {
    collidesWithBlock = collidesWithBlock,

    collidesWithRectangle = collidesWithRectangle,

    collidesWithWorld = function (highshape, lowshape, shapeGetter, highmargin, lowmargin)
        if highmargin == nil and lowmargin == nil then
            highmargin = vec(0, 0, 0)
            lowmargin = vec(0, -0.5, 0)
        end
        local highwithmargin, lowwithmargin = highshape + highmargin, lowshape + lowmargin
        for x = math.floor(lowwithmargin.x), math.floor(highwithmargin.x) do
            for y = math.floor(lowwithmargin.y), math.floor(highwithmargin.y) do
                for z = math.floor(lowwithmargin.z), math.floor(highwithmargin.z) do
                    local block = world.getBlockState(x, y, z)
                    local collider = collidesWithBlock(block, highshape, lowshape, shapeGetter)

                    if collider then
                        return block, collider
                    end
                end
            end
        end
        return false
    end
}

return collision