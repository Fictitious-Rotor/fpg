require("fpg.Utils.RestrictGlobals").enable()

local tokeniser = require "elu.Languages.Lua.tokeniser"
local genericParser = require "elu.Common.Parser"
local luaParser = genericParser.loadGrammar("elu.Languages.Lua.grammar", tokeniser.constructMatchers, tokeniser.literalMatchers)

local function isForGrammar(val)
  local theType = val.type
  return theType ~= "Whitespace"
     and theType ~= "Comment"
end

return function(inputString)
  local lexed = tokeniser.lex(inputString)
  
  local woWhitespace = {}

  for _, val in ipairs(lexed) do
    if isForGrammar(val) then
      woWhitespace[#woWhitespace + 1] = val
    end
  end
  
  return luaParser(woWhitespace)
end