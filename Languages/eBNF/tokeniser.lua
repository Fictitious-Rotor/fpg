local Tokeniser = require "elu.Common.tokeniser"
local pattern = Tokeniser.pattern
local Token = Tokeniser.makeToken
local view = require "elu.Utils.debugview"

--------------------------------------------------

local strMatch = string.match
local gsub = string.gsub

--------------------------------------------------

local function makeLuaPatternMatcher(lPat)
  return function(str, startPos)
    return strMatch(str, lPat, startPos)
  end
end

local function makeBasicMatcher(matcher, tokenMaker)
  return function(str, startPos)
    local match = matcher(str, startPos)
  
    if match then
      return tokenMaker(match), startPos + #match
    else
      return false, startPos
    end
  end
end

local function escapeSymbols(str)
  local outTbl = {}
  
  for char in str:gmatch('.') do
    outTbl[#outTbl + 1] = '%'
    outTbl[#outTbl + 1] = char
  end  
    
  return table.concat(outTbl)
end

local function anchorPattern(str)
  return '^' .. str
end

--------------------------------------------------

local Whitespace = Token "Whitespace"
local Identifier = Token "Identifier"

local Symbol = Token "Symbol"

local String = Token "String"
local Comment = Token "Comment"

--------------------------------------------------

local matchWhitespace = makeBasicMatcher(makeLuaPatternMatcher("^%s+"), Whitespace)
local matchIdentifier = makeBasicMatcher(makeLuaPatternMatcher("^[%a_][%w_]*"), Identifier)


local function makeSymbolMatcher(aSymbol)
  local escapedSymbols = escapeSymbols(aSymbol)
  local matcher = makeLuaPatternMatcher(anchorPattern(escapedSymbols))
  local token = Symbol(aSymbol)
  
  return makeBasicMatcher(matcher, function() return token end)
end

local function matchString(aStr, startPos)
  local stringOpener = strMatch(aStr, "^['\"]", startPos)
  
  if stringOpener then
    local getContent = "^[^\n" .. stringOpener .. "]*"
    local contentStartPos = startPos + #stringOpener
  
    local content = strMatch(aStr, getContent, contentStartPos)
    
    if not strMatch(aStr, stringOpener, contentStartPos + #content) then
      error("Unterminated string!")
    end
    
    return String(content), (startPos + #stringOpener + #content + #stringOpener)
  end
  
  return false, startPos
end

local function matchComment(aStr, startPos)
  local commentOpener = strMatch(aStr, "^%(%*", startPos)
  
  if commentOpener then
    local contentStart = startPos + #commentOpener
    local content = strMatch(aStr, "^.-%*%)", contentStart)
    
    return Comment(content), (contentStart + #content)
  end
  
  return false, startPos
end

--------------------------------------------------

local reservedSymbols = {
  "]", "[", "}", ")", "(", "{", ";", "=", ",", "-", "|"
}


local allPatterns = {
  pattern(matchWhitespace),
  pattern(matchString),
  pattern(matchComment, true),
  pattern(matchIdentifier)
}

local literalMatchers = {}

for _, value in ipairs(reservedSymbols) do
  local token = makeSymbolMatcher(value)
  local madePattern = pattern(token)
  
  allPatterns[#allPatterns + 1] = madePattern
  literalMatchers[value] = function(token) 
    return token 
       and type(token) == "table"
       and token.content == value
  end
end

local function makeTypeChecker(typeName)
  return function(tbl)
    local output = tbl 
       and type(tbl) == "table"
       and tbl.type == typeName
       
    return output
  end
end

local constructNames = { "String", "Comment", "Whitespace", "Identifier" }
local constructMatchers = {}

for _, name in ipairs(constructNames) do
  constructMatchers[name] = makeTypeChecker(name)
end

--------------------------------------------------

return {
  lex = function(str)
    return Tokeniser.lex(str, allPatterns)
  end,
  constructMatchers = constructMatchers,
  literalMatchers = literalMatchers
}
