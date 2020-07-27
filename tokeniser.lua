local view = require "debugview"

local sMatch = string.match

local function makeMatcher(lPat)
  return function(str) return sMatch(str, lPat) end
end

local function arrContains(tbl, value)
  for _, item in ipairs(tbl) do
    if item == value then return true end
  end
  
  return false
end

local function arrPartition(tbl, pred)
  local trues, falses = {}, {}
  local selectedTable

  for _, val in ipairs(tbl) do
    selectedTable = pred(val) and trues or falses
    
    selectedTable[#selectedTable + 1] = val
  end
  
  return trues, falses
end

---------

local stringableMeta = { __tostring = function(tbl) return tbl.value end }

local function stringableMaker(type)
  return function(value)
    return setmetatable({ value = value, type = type }, stringableMeta)
  end
end

local whitespace = stringableMaker "whitespace"
local identifier = stringableMaker "ident"

function newIter(fn) -- Returns readFn & shouldReRead
  local lastRead
  local shouldReRead = false
  
  local function readFn()
    if not shouldReRead then
      lastRead = fn()
      return lastRead
    else
      shouldReRead = false
      return lastRead
    end
  end
  
  local function askReRead()
    shouldReRead = true
  end
  
  local function isEmpty()
    return lastRead == nil
  end
  
  return readFn, askReRead, isEmpty
end

-----------

function consumeIdent(readChar, askReRead, canBeIdentifier)
  local charTable = {}
  local curChar = readChar()
  
  while canBeIdentifier(curChar)  do
    charTable[#charTable + 1] = curChar
    curChar = readChar()
  end
  
  askReRead()
  return table.concat(charTable), #charTable > 1
end

function consumeReservedStrings(readChar, askReRead, reservedStrings)
  
end

local function makeMappingMatcher(mapping, elementKey)
  return function(value)
    for k,v in pairs(mapping) do
      if v[elementKey](value) then
        return true
      end
    end
    
    return false
  end
end

-- sort by "canBeIdentifier"
-- Which allows me to group into keywords & symbols
-- perhaps "reservedIdents" and "reservedStrings"



-- YOU FORGOT ABOUT STRINGS!!

local Tokeniser = {}
Tokeniser.__index = Tokeniser

-- Put "LPat corresponds to Lua's patterns" in the documentation somewhere appropriate
-- Put something about shortening "language construct" to LC
local function Tokeniser.new(isWhitespaceLPat, languageConstructMapping, allReserved)
  local reservedLCs, reservedStrings = arrPartition(allReserved, makeMappingMatcher(languageConstructMapping, "isMatch"))
  local sortedReserved = table.sort(reservedStrings)

  return setmetatable({ 
    isWhitespaceChar = isWhitespaceChar, 
    reservedLCs = reservedLCs,
    reservedStrings = sortedReserved
  }, Tokeniser)
end

function Tokeniser.readString(inputString, isWhitespaceChar, isIdentifierChar, reservedLCs, reservedStrings)
  local readChar, askReRead, isEmpty = newIter(inputString:gmatch("."))
  
  local outTokens = {}
  local canTokenise = true
  local found, succeeded, isReserved
  
  repeat
    found, succeeded = consumeWhitespace()
    
    if succeeded then
      outTokens[#outTokens + 1] = found
    end
    
    found, succeeded = consumeIdentifier(readChar, askReRead)
    
    if succeeded then
      isReserved = arrContains(reservedLCs, found)
      
      outTokens[#outTokens + 1] = isReserved and found or identifier(found)
    else
      found, succeeded = consumeReservedString(readChar, askReRead)
      
      if succeeded then
        outTokens[#outTokens + 1] = found
      else
        canTokenise = false
      end
    end
  until not canTokenise or isEmpty()
  
  if not canTokenise and isEmpty() then
    error(string.format("Tokeniser error: failed to tokenise the entire string.\nSuccessfully lexed tokens are as follows:\n%s", view(outTokens)))
  end
  
  return outTokens
end

return Tokeniser.new