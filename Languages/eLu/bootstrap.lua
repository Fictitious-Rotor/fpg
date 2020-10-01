require("fpg.Utils.RestrictGlobals").enable()

local tokeniser = require "fpg.Languages.eLu.tokens"
local lexer = tokeniser.lex
local eLuParser = require("fpg.Common.Parser").loadGrammar(
  "fpg.Languages.eLu.grammar", 
  tokeniser.constructMatchers, 
  tokeniser.literalMatchers
)
local evaluate = require("fpg.Languages.eLu.evaluator").evaluate

local function isForGrammar(val)
  local theType = val.type
  return theType ~= "Whitespace"
     and theType ~= "Comment"
end

return function(inputString)
  local lexed = lexer(inputString)
  
  local woWhitespace = {}

  for _, val in ipairs(lexed) do
    if isForGrammar(val) then
      woWhitespace[#woWhitespace + 1] = val
    end
  end
  
  local parsed = eLuParser(woWhitespace)
  
  return evaluate(parsed)
end