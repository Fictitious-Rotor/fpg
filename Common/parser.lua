local TableReader = require "Utils.TableReader"
local List = require "Utils.SinglyLinkedList"
local view = require "debugview"

local null = List.null
local cons = List.cons

local definition -- Definition
local labeledDefinition -- Labeled definition
local repeatedDefinition -- Repeat definition

----------------- Definition

local function concat(priorReader, priorParsed, iter, gen, lastKey)
  local idx, def = iter(gen, lastKey)
  if not def then return priorReader, priorParsed end
  
  local reader, parsed = def(priorReader, priorParsed)
  if not reader then return false end
  
  return concat(reader, parsed, iter, gen, idx)
end

local definitionMeta = {
  __call = function(self, reader, parsed)
    return concat(reader, parsed, ipairs(self))
  end,
  __div = function(self, other)
    return function(priorReader, priorParsed)
      local parsed, reader = self(priorReader, priorParsed)
      
      if parsed then
        return parsed, reader
      else
        return other(priorParsed, priorReader)
      end
    end
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

----------------- Labeled definition

local labeledDefinitionMatcher = {
  __call = function(self, reader, parsed)
    return reader, parsed
  end
}

local function makeLabeledDefinitionMaker(_ENV)
  return function(tbl)
    for name, definition in pairs(tbl) do
      _ENV[name] = definition
    end

    return setmetatable(tbl, labeledDefinitionMeta)
  end
end

----------------- Repeated definition

local function makeConsumer(matcher)
  return function(reader, parsed)
    print("running consumer:", matcher, view(reader:getValue()), view(parsed:getHead()))
    local token = reader:getValue()

    if matcher(token) then
      return reader:withFollowingIndex(), cons(token, parsed)
    else
      return false
    end
  end
end

repeatedDefinition = function(minimumCount, maximumCount)
  local minimumCount = minimumCount or 1
  local maximumCount = maximumCount or math.huge

  return function(defTbl)
    local def = definition(defTbl)

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

----------------- Parser

local Parser = {}

local function loadFile(address, _ENV)
  local fn, message = loadfile(address, "t", _ENV)
  return fn and fn() or error(message)
end

local function each(fn, tbl)
  for k,v in pairs(tbl) do
    fn(k,v)
  end
end

function Parser.loadGrammar(grammarFileAddress, constructMatchers, literalMatchers)
  local _ENV = setmetatable({ _G = _G }, { __index = _G })
  local literalConsumers = {}
  
  each(function(name, matcher) _ENV[name] = makeConsumer(matcher) end, constructMatchers)
  each(function(name, matcher) literalConsumers[name] = makeConsumer(matcher) end, literalMatchers)

  definition = makeDefinitionMaker(literalConsumers)
  labeledDefinition = makeLabeledDefinitionMaker(_ENV)
  
  each(function(shorthand, func) _ENV[shorthand] = func end, { d = definition, l = labeledDefinition, r = repeatedDefinition })
  --each(print, _ENV)

  local grammar = require(grammarFileAddress)(_ENV)
  
  return function(tokenList)
    return grammar(TableReader.new(tokenList), null)
  end
end

return Parser
