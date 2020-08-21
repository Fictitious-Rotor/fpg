local tokeniser = require "elu.Languages.eBNF.tokeniser"
local parser = require "elu.Common.Parser"
local view = require "elu.Utils.debugview"

local function readAll(file)
    local f = assert(io.open(file, "rb"))
    local content = f:read("*all")
    f:close()
    return content
end

--readAll("path/to/address/file.lua")
local aString = [[
letter = "A" | "B" | "C" | "D" | "E" | "F" | "G"
       | "H" | "I" | "J" | "K" | "L" | "M" | "N"
       | "O" | "P" | "Q" | "R" | "S" | "T" | "U"
       | "V" | "W" | "X" | "Y" | "Z" | "a" | "b"
       | "c" | "d" | "e" | "f" | "g" | "h" | "i"
       | "j" | "k" | "l" | "m" | "n" | "o" | "p"
       | "q" | "r" | "s" | "t" | "u" | "v" | "w"
       | "x" | "y" | "z" ;
digit = "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" ;
symbol = "[" | "]" | "{" | "}" | "(" | ")" | "<" | ">"
       | "QUOTE" | "SPEECH" | "=" | "|" | "." | "," | ";" ;
character = letter | digit | symbol | "_" ;
 
identifier = letter , { letter | digit | "_" } ;
terminal = "QUOTE" , character , { character } , "QUOTE" 
         | "SPEECH" , character , { character } , "SPEECH" ;
 
lhs = identifier ;
rhs = identifier
     | terminal
     | "[" , rhs , "]"
     | "{" , rhs , "}"
     | "(" , rhs , ")"
     | rhs , "|" , rhs
     | rhs , "," , rhs ;

rule = lhs , "=" , rhs , ";" ;
grammar = { rule } ;
]]
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

local filteredTokens = {}

for _, val in ipairs(lexed) do
  if isForGrammar(val) then
    filteredTokens[#filteredTokens + 1] = val
  end
end

local ebnfParser = parser.loadGrammar("Languages.eBNF.grammar", tokeniser.constructMatchers, tokeniser.literalMatchers)

local parsedEbnf = ebnfParser(filteredTokens)
print("Parsed:\n", view(parsedEbnf))