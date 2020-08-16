local tokeniser = require "Languages.Lua.tokeniser"
local parser = require "Common.Parser"
local view = require "debugview"

local aString = "+"

local lexed = tokeniser.lex(aString)
print("Lexed string:", view(lexed))

local woWhitespace = {}

for _, val in ipairs(lexed) do
  if val.type ~= "Whitespace" then
    woWhitespace[#woWhitespace + 1] = val
  end
end

print("Removed whitespace:", view(woWhitespace))
local luaParser = parser.loadGrammar("Languages.Lua.grammar", tokeniser.constructMatchers, tokeniser.literalMatchers)

local parsedLua = luaParser(woWhitespace)
print("Parsed lua:", view(parsedLua))