local class = require "tank/command/commands/class"

local StringReader = class("StringReader")

function StringReader:init(str)
    self._str = str
    self._pos = 1
end

function StringReader:peek()
    return string.sub(self._str, self._pos, self._pos)
end

function StringReader:getCursor()
    return self._pos
end

function StringReader:move(pos)
    self._pos = pos
end

function StringReader:read(length)
    local v = self._pos
    local s = string.sub(self._str , self._pos, self._pos + length - 1)
    self:skip(length)
    return s
end

function StringReader:skip(length)
    self._pos = self._pos + (length or 1)
end

function StringReader:canRead(length)
    return self._pos + (length or 1) <= string.len(self._str) + 1
end

function StringReader:readString()
    local quoted = self:peek() == '"'
    local terminator = quoted and '"' or ' '

    if quoted then
        self:read(1)
    end

    local ret = ""
    while self:peek() ~= terminator and self:canRead() do
        ret = ret .. self:read(1)
    end

    if not self:canRead() and quoted then
        return nil
    end

    if quoted then
        self:read(1)
    end

    return string.len(ret) > 0 and ret or nil
end

function StringReader:readInteger()
    local ret = ""
    local v = true
    if self:peek() == "-" then
        ret = ret .. self:read(1)
    end
    while self:peek() ~= " " and self:canRead() do
        local char = self:read(1)
        if char:match("%d") then
            ret = ret .. char
        elseif char == "." and v then
            v = false
            ret = ret .. char
        else
            return
        end
    end
    return string.len(ret) > 0 and tonumber(ret) or nil
end


return StringReader