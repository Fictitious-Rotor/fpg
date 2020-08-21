local tokeniser = require "Languages.Lua.tokeniser"
local parser = require "Common.Parser"
local view = require "Utils.debugview"

local function readAll(file)
    local f = assert(io.open(file, "rb"))
    local content = f:read("*all")
    f:close()
    return content
end

local aString = readAll("path/to/address/file.lua")
-- print("String to parse:")
-- print(aString, "\n\n")

local lexed = tokeniser.lex(aString)
-- print("Lexed string:")
-- print(view(lexed))

local function isForGrammar(val)
  local theType = val.type
  return theType ~= "Whitespace"
     and theType ~= "Comment"
end

local woWhitespace = {}

for _, val in ipairs(lexed) do
  if isForGrammar(val) then
    woWhitespace[#woWhitespace + 1] = val
  end
end

local luaParser = parser.loadGrammar("Languages.Lua.grammar", tokeniser.constructMatchers, tokeniser.literalMatchers)

local parsedLua = luaParser(woWhitespace)
print("Parsed:\n", view(parsedLua))