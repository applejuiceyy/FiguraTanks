local State = require "tank.state.State"

models.world:setParentType("WORLD")

models.models.tank:setVisible(false)
models.models.hud:setParentType("HUD")
models.models.tablet:setVisible(false)
models.models.tablet:setPrimaryTexture("SKIN")
models.models.tablet.Tablet:setPrimaryTexture("PRIMARY")

function events.entity_init()
    local slim = player:getModelType()
    models.models.tablet.Person._SlimLeftArm:setVisible(slim)
    models.models.tablet.Person._SlimRightArm:setVisible(slim)
    models.models.tablet.Person._LeftArm:setVisible(not slim)
    models.models.tablet.Person._RightArm:setVisible(not slim)
end

function events.tick()
    State:tick()
end

function events.render()
    State:render()
end

function events.MOUSE_MOVE(...)
    return State:mouseMove(...)
end