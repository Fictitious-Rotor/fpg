local view = require "debugview"

local Tokeniser = {}

function Struct(propertyNames)
  return function(...)
    local theStruct = {}
    local args = { ... }
    
    for idx, propertyName in ipairs(propertyNames) do
      theStruct[propertyName] = args[idx]
    end
    
    return theStruct
  end
end

Tokeniser.pattern = Struct { "match", "isPriority" }

local token = Struct { "type", "content" }

function Tokeniser.makeToken(type)
  return function(content)
    return token(type, content)
  end
end

local function scan(str, startPos, patterns)
  local bestMatch, furthestPos = false, startPos

  for _, pattern in pairs(patterns) do
    local match, endPos = pattern.match(str, startPos)
    
    if match then
      if endPos > furthestPos then
        bestMatch = match
        furthestPos = endPos
      elseif pattern.isPriority then
        return match, endPos
      end 
    end
  end
  
  return bestMatch, furthestPos
end

function Tokeniser.lex(str, patterns)
  local foundTokens, pos, token = {}, 1, false
  
  while pos <= #str do
    token, pos = scan(str, pos, patterns)
    
    if token then
      foundTokens[#foundTokens + 1] = token
    else
      error(string.format("Tokeniser error: failed to tokenise the entire string.\nSuccessfully lexed tokens are as follows:\n%s", view(foundTokens)))
    end
  end
  
  return foundTokens
end

return Tokeniser