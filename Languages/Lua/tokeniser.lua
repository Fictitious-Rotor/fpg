local Tokeniser = assert(dofile("../../Common/tokeniser.lua"))
local pattern = Tokeniser.pattern
local Token = Tokeniser.makeToken

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

local Identifier = Token "Identifier"
local Whitespace = Token "Whitespace"

local Keyword = Token "Keyword"
local Symbol = Token "Symbol"

local Number = Token "Number"
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

local function makeKeywordMatcher(aKeyword)
  local matcher = makeLuaPatternMatcher(anchorPattern(aKeyword))
  local token = Keyword(aKeyword)
  
  return makeBasicMatcher(matcher, function() return token end)
end



local function matchNumber(aStr, startPos)
  local readPos = startPos
  local numberOpener = strMatch(aStr, "^%d+", readPos)
  
  if numberOpener then
    readPos = readPos + #numberOpener
    local outNum = numberOpener
    
    local decimalPoint = strMatch(aStr, "^%.", readPos)
    
    if decimalPoint then
      readPos = readPos + #decimalPoint
      outNum = outNum .. decimalPoint
      
      local numberCloser = strMatch(aStr, "^%d+", readPos)
      
      if numberCloser then
        readPos = readPos + #numberCloser
        outNum = outNum .. numberCloser
      end
    end
    
    return Number(outNum), readPos
  end
  
  return false, startPos
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
  else
    local multilineOpener = strMatch(aStr, "^%[=*%[", startPos)
    
    if multilineOpener then
      local multilineCloser = gsub(multilineOpener, "%[", "]")
      local getContent = "(.-)" .. multilineCloser
      local contentStartPos = startPos + #multilineOpener + 1
      
      local content = strMatch(aStr, getContent, contentStartPos)
      
      return String(content), (contentStartPos + #content + #multilineCloser)
    end
  end
  
  return false, startPos
end

local function matchComment(aStr, startPos)
  local commentOpener = strMatch(aStr, "^%-%-", startPos)
  
  if commentOpener then
    local multilineOpener = strMatch(aStr, "^%[=*%[", startPos + #commentOpener)
    
    if multilineOpener then -- Multiline comment
      local multilineCloser = gsub(multilineOpener, "%[", "]")
      local contentStart = startPos + #commentOpener + #multilineOpener
      local getContent = "^(.-)" .. multilineCloser
      local content = strMatch(aStr, getContent, contentStart)
      
      return Comment(content), (contentStart + #content)
    else -- Inline comment
      local contentStart = startPos + #commentOpener
      local content = strMatch(aStr, "^[^\n]*", contentStart)
      
      return Comment(content), (contentStart + #content)
    end
  end
  
  return false, startPos
end

--------------------------------------------------

local reservedSymbols = {
  "]]", "[[", "]", "[", "::", "}", ")", '"', "...", "(", "\\", 
  "{", "==", "~=", ";", "..", "=", "/", "%", "^", ",", ":", 
  "-", "'", "*", "#", "+", "<=", ">=", ".", "<", ">" 
}

local reservedKeywords = { 
  "do", "if", "in", "or", "end", "for", "nil", "and", "not", 
  "else", "goto", "then", "true", "while", "until", "local", 
  "break", "false", "repeat", "elseif", "return", "function", 
}

local allPatterns = {
  pattern(matchString),
  pattern(matchNumber),
  pattern(matchComment, true),
  pattern(matchWhitespace)
}

local staticTokens = { -- Convert all strings into tokens, then into patterns, then add them to allPatterns
  { reservedSymbols, makeSymbolMatcher },
  { reservedKeywords, makeKeywordMatcher },
}

local literalMatchers = {}

for _, tokensAndMatcher in ipairs(staticTokens) do
  local tokenSet = tokensAndMatcher[1]
  local matcherMaker = tokensAndMatcher[2]

  for _, value in ipairs(tokenSet) do
    local token = matcherMaker(value)
    local madePattern = pattern(token)
    
    allPatterns[#allPatterns + 1] = madePattern
    literalMatchers[value] = function(v) return v == value end
  end
end

allPatterns[#allPatterns + 1] = pattern(matchIdentifier) -- Identifier must be checked after keywords so that they have precedence

local function makeTypeChecker(typeName)
  return function(tbl)
    return tbl 
       and type(tbl) == "table"
       and tbl.type == typeName
  end
end

local constructNames = { "String", "Comment", "Whitespace", "Number", "Identifier" }
local constructMatchers = {}

for _, name in ipairs(constructNames) do
  constructMatchers[name] = makeTypeChecker(v)
end

--------------------------------------------------

return {
  lex = function(str) 
    return Tokeniser.lex(str, allPatterns)
  end,
  constructMatchers = constructMatchers,
  literalMatchers = literalMatchers
}
