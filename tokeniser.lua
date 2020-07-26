local view = require "debugview"

--[[

Let's talk about this tokeniser then
The tokeniser is responsible for pulling out all of the reserved patterns and packing everything else into a generic pattern.
One of the things I need to manage is that every keyword should ensure that it's not an identifier.
How am I going to represent that in a manner that isn't expensive?

I'm thinking create some sort of wrapper function that, assuming that findReserved did indeed find a reserved, will then run a "[%w_]" check.
Something else to fear is that we'll hit a symbol and it'll still look for one of those.
We can probably just make a different table and use that as a different root for searchBranch.
What's quite fun about that is it'll move the whole "keywords mustn't be identifiers" business into plugin code.

Let's put something together

I should probably make a simple fn wrapper for the iterator so I can add a peek function.
I can probably leave it as stateful as it's not meant to backtrack anyways. I just need the ability to not advance.
]]

local function arrContains(tbl, value)
  for _, item in ipairs(tbl) do
    if item == value then return true end
  end
  
  return false
end

local strMatch = string.match

function consumeIdent(readChar, askReRead, reservedPrefix)
  local charTable = {}
  local curChar = readChar()
  
  while strMatch(curChar, "[%w_]") do
    charTable[#charTable + 1] = curChar
    curChar = readChar()
  end
  
  askReRead()
  return table.concat(charTable), #charTable > 1
end

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


-- sort by "canBeIdentifier"
-- Which allows me to group into keywords & symbols
-- perhaps "reservedIdents" and "reservedStrings"

local function readString(str, consumeWhitespace, consumeIdentifier, consumeReservedString)
  local readChar, askReRead, isEmpty = newIter(str:gmatch("."))
  
  local outTokens = {}
  local canTokenise = true
  local found, succeeded
  
  repeat
    found, succeeded = consumeWhitespace()
    
    if succeeded then
      outTokens[#outTokens + 1] = found
    end
    
    found, succeeded = consumeIdentifier(readChar, askReRead)
    
    if succeeded then
      local isReserved = arrContains(reservedIdents, found)
      
      if isReserved then
        outTokens[#outTokens + 1] = found
      else
        outTokens[#outTokens + 1] = identifier(found)
      end
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

populateTree()
print(view(tokeniserTree))