local Json = {}

local function sortedKeys(tbl)
    local keys = {}
    for key in pairs(tbl) do
        table.insert(keys, key)
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)
    return keys
end

local function isArray(tbl)
    local count = 0
    local max = 0

    for key in pairs(tbl) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false
        end

        count = count + 1
        if key > max then
            max = key
        end
    end

    return max == count
end

local function encodeString(value)
    value = value:gsub("\\", "\\\\")
    value = value:gsub("\"", "\\\"")
    value = value:gsub("\b", "\\b")
    value = value:gsub("\f", "\\f")
    value = value:gsub("\n", "\\n")
    value = value:gsub("\r", "\\r")
    value = value:gsub("\t", "\\t")
    return "\"" .. value .. "\""
end

local function encodeJson(value, indent)
    indent = indent or 0
    local valueType = type(value)

    if valueType == "nil" then
        return "null"
    end

    if valueType == "boolean" or valueType == "number" then
        return tostring(value)
    end

    if valueType == "string" then
        return encodeString(value)
    end

    if valueType ~= "table" then
        error("Cannot encode value of type " .. valueType)
    end

    local nextIndent = indent + 2
    local prefix = string.rep(" ", nextIndent)
    local suffix = string.rep(" ", indent)
    local parts = {}

    if next(value) ~= nil and isArray(value) then
        for index = 1, #value do
            table.insert(parts, prefix .. encodeJson(value[index], nextIndent))
        end
        return "[\n" .. table.concat(parts, ",\n") .. "\n" .. suffix .. "]"
    end

    for _, key in ipairs(sortedKeys(value)) do
        table.insert(parts, prefix .. encodeString(tostring(key)) .. ": " .. encodeJson(value[key], nextIndent))
    end

    if #parts == 0 then
        return "{}"
    end

    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. suffix .. "}"
end

function Json.encode(value)
    return encodeJson(value)
end

local Decoder = {}
Decoder.__index = Decoder

function Decoder.new(input)
    return setmetatable({
        input = input,
        index = 1,
    }, Decoder)
end

function Decoder:peek()
    return self.input:sub(self.index, self.index)
end

function Decoder:next()
    local char = self:peek()
    self.index = self.index + 1
    return char
end

function Decoder:error(message)
    error(string.format("JSON parse error at byte %d: %s", self.index, message), 0)
end

function Decoder:skipWhitespace()
    while true do
        local char = self:peek()
        if char ~= " " and char ~= "\n" and char ~= "\r" and char ~= "\t" then
            return
        end
        self.index = self.index + 1
    end
end

function Decoder:parseString()
    if self:next() ~= "\"" then
        self:error("expected string")
    end

    local parts = {}
    while true do
        local char = self:next()
        if char == "" then
            self:error("unterminated string")
        elseif char == "\"" then
            return table.concat(parts)
        elseif char == "\\" then
            local escaped = self:next()
            if escaped == "\"" or escaped == "\\" or escaped == "/" then
                table.insert(parts, escaped)
            elseif escaped == "b" then
                table.insert(parts, "\b")
            elseif escaped == "f" then
                table.insert(parts, "\f")
            elseif escaped == "n" then
                table.insert(parts, "\n")
            elseif escaped == "r" then
                table.insert(parts, "\r")
            elseif escaped == "t" then
                table.insert(parts, "\t")
            elseif escaped == "u" then
                self:error("\\u escapes are not supported")
            else
                self:error("invalid escape")
            end
        else
            table.insert(parts, char)
        end
    end
end

function Decoder:parseNumber()
    local start = self.index

    if self:peek() == "-" then
        self.index = self.index + 1
    end

    while self:peek():match("%d") do
        self.index = self.index + 1
    end

    if self:peek() == "." then
        self.index = self.index + 1
        while self:peek():match("%d") do
            self.index = self.index + 1
        end
    end

    local char = self:peek()
    if char == "e" or char == "E" then
        self.index = self.index + 1
        char = self:peek()
        if char == "+" or char == "-" then
            self.index = self.index + 1
        end
        while self:peek():match("%d") do
            self.index = self.index + 1
        end
    end

    local value = tonumber(self.input:sub(start, self.index - 1))
    if not value then
        self:error("invalid number")
    end

    return value
end

function Decoder:parseLiteral(literal, value)
    if self.input:sub(self.index, self.index + #literal - 1) ~= literal then
        self:error("expected " .. literal)
    end

    self.index = self.index + #literal
    return value
end

function Decoder:parseArray()
    self:next()
    local result = {}
    self:skipWhitespace()

    if self:peek() == "]" then
        self:next()
        return result
    end

    while true do
        table.insert(result, self:parseValue())
        self:skipWhitespace()

        local char = self:next()
        if char == "]" then
            return result
        elseif char ~= "," then
            self:error("expected , or ]")
        end
    end
end

function Decoder:parseObject()
    self:next()
    local result = {}
    self:skipWhitespace()

    if self:peek() == "}" then
        self:next()
        return result
    end

    while true do
        self:skipWhitespace()
        local key = self:parseString()
        self:skipWhitespace()
        if self:next() ~= ":" then
            self:error("expected :")
        end
        result[key] = self:parseValue()
        self:skipWhitespace()

        local char = self:next()
        if char == "}" then
            return result
        elseif char ~= "," then
            self:error("expected , or }")
        end
    end
end

function Decoder:parseValue()
    self:skipWhitespace()
    local char = self:peek()

    if char == "\"" then
        return self:parseString()
    elseif char == "{" then
        return self:parseObject()
    elseif char == "[" then
        return self:parseArray()
    elseif char == "t" then
        return self:parseLiteral("true", true)
    elseif char == "f" then
        return self:parseLiteral("false", false)
    elseif char == "n" then
        return self:parseLiteral("null", nil)
    elseif char == "-" or char:match("%d") then
        return self:parseNumber()
    end

    self:error("unexpected character " .. tostring(char))
end

function Json.decode(input)
    local decoder = Decoder.new(input)
    local result = decoder:parseValue()
    decoder:skipWhitespace()

    if decoder:peek() ~= "" then
        decoder:error("trailing input")
    end

    return result
end

function Json.read(path)
    local file, err = io.open(path, "r")
    if not file then
        return nil, err
    end

    local content = file:read("*a")
    file:close()
    return Json.decode(content)
end

function Json.write(path, value)
    local file, err = io.open(path, "w")
    if not file then
        return nil, err
    end

    file:write(Json.encode(value))
    file:write("\n")
    file:close()
    return true
end

return Json
