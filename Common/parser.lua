local TableReader = require "Utils.TableReader"
local List = require "Utils.SinglyLinkedList"
local view = require "debugview"

local null = List.null
local cons = List.cons

local definition -- Definition
local globalDefinition -- Global definition
local repeatedDefinition -- Repeat definition

----------------- Definition

local definitionMeta

local function concat(priorReader, priorParsed, iter, gen, lastKey)
  local idx, def = iter(gen, lastKey)
  if not def then return priorReader, priorParsed end
  
  local reader, parsed = def(priorReader, priorParsed)
  if not reader then return false end
  
  return concat(reader, parsed, iter, gen, idx)
end

definitionMeta = {
  __call = function(self, priorReader, priorParsed)
    local reader, parsed = concat(priorReader, null, ipairs(self))
    if not reader then return false end
    
    return reader, cons({ tokens = parsed:take(), name = self.name }, priorParsed)
  end,
  __div = function(self, other)
    return function(priorReader, priorParsed)
      local reader, parsed = self(priorReader, priorParsed)
      
      if parsed then
        return reader, parsed
      else
        return other(priorReader, priorParsed)
      end
    end
  end
}

local function makeDefinitionMaker(literalConsumers)
  return function(tblOrString)
    local function convertLiterals(tbl) -- Inside closure to get _ENV
      for idx, value in ipairs(tbl) do
        if type(value) == "string" then
           tbl[idx] = literalConsumers[value]
        end
      end
      
      return setmetatable(tbl, definitionMeta)
    end
  
    if type(tblOrString) == "string" then
      return function(defTbl) 
        local tbl = convertLiterals(defTbl)
        tbl.name = tblOrString
        return tbl
      end
    else
      return convertLiterals(tblOrString)
    end
  end
end

----------------- Global definition

local globalDefinitionMeta = {
  __call = function(self, reader, parsed)
    return reader, parsed
  end
}

local function makeGlobalDefinitionMaker(_ENV)
  return function(tbl)
    for name, definition in pairs(tbl) do
      _ENV[name] = definition
    end

    return setmetatable(tbl, globalDefinitionMeta)
  end
end

----------------- Repeated definition

local function makeConsumer(matcher)
  return function(reader, parsed)
    local token = reader:getValue()

    if matcher(token) then
      return reader:withFollowingIndex(), cons(token, parsed)
    else
      return false
    end
  end
end

local function repeatDefinition(minimumCount, maximumCount, defTbl, name)
  -- NAME ISN'T GOING THROUGH! FIX ME!
  local def = name and definition(name)(defTbl) or definition(defTbl)

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

repeatedDefinition = function(minimumCount, maximumCount)
  local minimumCount = minimumCount or 1
  local maximumCount = maximumCount or math.huge

  return function(defTblOrString)
    if type(defTblOrString) == "string" then 
      return function(defTbl)
        return repeatDefinition(minimumCount, maximumCount, defTbl, defTblOrString)
      end
    else
      return repeatDefinition(minimumCount, maximumCount, defTblOrString)
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
  globalDefinition = makeGlobalDefinitionMaker(_ENV)
  
  each(function(shorthand, func) _ENV[shorthand] = func end, { d = definition, g = globalDefinition, r = repeatedDefinition })

  local grammar = require(grammarFileAddress)(_ENV)
  
  return function(tokenList)
    local reader, result = grammar(TableReader.new(tokenList), null)
    
    return result
       and result:take()
  end
end

return Parser
