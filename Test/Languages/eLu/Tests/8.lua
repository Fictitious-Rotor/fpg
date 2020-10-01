
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
