local d -- Definition
local l -- Labeled definition
local r -- Repeat definition

--- Definition

local function concat(priorReader, priorParsed, iter, gen, lastKey)
  local def = iter(gen, lastKey)
  if not def then return priorReader, priorParsed end
  
  local reader, parsed = def(priorReader, priorParsed)
  if not reader then return false end
  
  return concat(reader, parsed, iter, gen, def)
end

local definitionMeta = {
  __call = function(self, reader, parsed)
    return concat(reader, parsed, ipairs(self))
  end
}

local function makeDefinitionMaker(literalConsumers)
  return function(tbl)
    for idx, value in ipairs(tbl) do
      if type(value) == "string" then
         tbl[idx] = literalConsumers[value]
      end
    end
    
    return setmetatable(tbl, definitionMeta)
  end
end

---
--
--- Labeled definition

local labeledDefinitionMatcher = {
  __call = function(self, reader, parsed)
    return reader, parsed
  end
}

local function makeLabeledDefinitionMatcher(_ENV)
  return function(tbl)
    for name, definition in pairs(tbl) do
      _ENV[name] = definition
    end

    return setmetatable(tbl, labeledDefinitionMeta)
  end
end

---
--
--- Repeated definition

local function makeConsumer(matcher)
  return function(priorReader, priorParsed)
    local token = priorReader:getValue()

    if matcher(token) then
      return priorReader:withFollowingIndex(), cons(token, priorParsed)
    else
      return false
    end
  end
end

r = function(minimumCount, maximumCount)
  local minimumCount = minimumCount or 1
  local maximumCount = maximumCount or math.huge

  return function(defTbl)
    local def = d(defTbl)

    local function loop(priorReader, priorParsed, count)
      local reader, parsed = def(priorReader, priorParsed)

      if reader then
        if count <= maximumCount then
          return loop(reader, parsed, count + 1)
        end
      else
        if count >= minimumCount then
          return priorReader, priorParsed 
        end
      end 

      return false
    end

    return function(priorReader, priorParsed)
      return loop(priorReader, priorParsed, 1)
    end
  end
end

--- Parser

local Parser = {}

local function loadFile(address)
  local fn, message = loadfile(address, "t", _ENV)
  return fn and fn() or error(message)
end

function Parser.loadGrammar(grammarFileAddress, constructMatchers, literalMatchers)
  local _ENV = setmetatable({ _G = _G }, { __index = _G })

  for name, matcher in pairs(constructMatchers) do
    _ENV[name] = makeConsumer(matcher)
  end

  local literalConsumers = {}

  for name, matcher in pairs(literalMatchers) do
    literalConsumers[name] = makeConsumer(matcher)
  end

  d = makeDefinitionMatcher(literalConsumers)
  l = makeLabeledDefinitionMatcher(_ENV)

  local grammar = loadFile(grammarFileAddress, _ENV)

  return function(tokenList)
    return grammar(TableReader.new(tokenList), null)
  end
end

return Parser
