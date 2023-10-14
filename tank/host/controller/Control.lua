local class       = require("tank.class")


---@params ControlRepo
local Control = class("Control")


function Control:init(repo)
    self.repo = repo

    self.clickedTimes = {}
    self.pressed = {}
end

function Control:_isValidToken(token)
   return not not self.repo.availableKeys[token]
end

function Control:click(token)
    if self:_isValidToken(token) then
        self.clickedTimes[token] = (self.clickedTimes[token] or 0) + 1
    end
end

function Control:press(token)
    if self:_isValidToken(token) then
        self.pressed[token] = true
    end
end

function Control:release(token)
    if self:_isValidToken(token) then
        self.pressed[token] = false
    end
end

function Control:isPressed(token)
    if not self:_isValidToken(token) then
        return false
    end
    return not not self.pressed[token]
end


function Control:wasClicked(token)
    if not self:_isValidToken(token) then
        return false
    end
    if self.clickedTimes[token] == nil or self.clickedTimes[token] == 0 then
        return false
    end
    self.clickedTimes[token] = self.clickedTimes[token] - 1
    return true
end

function Control:resetClick(token)
    if not self:_isValidToken(token) then
        return
    end
    self.clickedTimes[token] = 0
end

function Control:forClick(token)
    return function(o)
        if self:wasClicked(o) then
            return true
        end
    end, token
end

return Control