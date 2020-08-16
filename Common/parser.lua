setmetatable(_G, {
  __index = function(tbl, key)
    error(string.format("Missing global variable with key: '%s'", key))
  end,
  __newindex = function(tbl, key, val)
    rawset(tbl, key, val == true or error "Cannot reference a global without prior declaration")
  end
})

local TableReader = require "Utils.TableReader"
local List = require "Utils.SinglyLinkedList"
local view = require "debugview"

local listNull = List.null
local cons = List.cons

local definition
local definitionMeta
local globalDefinition
local repeatedDefinition
local alternation
local alternationMeta

local consumerMeta = {
  __call = function(self, reader, parsed)
    local token = reader:getValue()

    if self.matcher(token) then
      return reader:withFollowingIndex(), cons(token, parsed)
    else
      return false
    end
  end,
  __tostring = function(self) return self.debugname end
}

local function makeConsumer(matcher, name)
  return setmetatable({ matcher = matcher, debugname = name }, consumerMeta)
end

local function concatenate(priorReader, priorParsed, iter, gen, lastKey)
  local idx, def = iter(gen, lastKey)
  if not def then return priorReader, priorParsed end
  
  local reader, parsed = def(priorReader, priorParsed)
  if not reader then return false end
  
  return concatenate(reader, parsed, iter, gen, idx)
end

-----------------<| Alternation

local function makeAlternationMeta()
  return {
    __div = alternation,
    __call = function(self, priorReader, priorParsed)
      local reader, parsed = self.left(priorReader, priorParsed)
      
      if parsed then
        return reader, parsed
      else
        return self.right(priorReader, priorParsed)
      end
    end,
    __tostring = function(self)
      return string.format("(%s / %s)", self.left, self.right)
    end
  }
end

local function makeAlternationMaker(literalConsumers)
  return function(self, other)
    if type(other) == "string" then
      other = literalConsumers[other]
    end 
    
    return setmetatable({ left = self, right = other }, alternationMeta)
  end
end

-----------------<| Definition

local function makeDefinitionMeta()
  return {
    __div = alternation,
    __call = function(self, priorReader, priorParsed)
      local name = self.name
      local startingParsed = name and listNull or priorParsed
      
      local reader, parsed = concatenate(priorReader, startingParsed, ipairs(self))
      if not reader then return false end
      
      if name then
        return reader, cons({ tokens = parsed:take(), name = name }, priorParsed)
      else
        return reader, parsed
      end
    end,
    __tostring = function(self)
      local vals = {}
      for _,v in ipairs(self) do vals[#vals + 1] = tostring(v) end
      local valsStr = table.concat(vals, ",")
      local name = self.name
      
      if name then
        return string.format("(%s:(%s))", name, valsStr)
      else
        return string.format("(%s)", valsStr)
      end
    end
  }
end

local function convertLiterals(tbl, literalConsumers)
  for idx, value in ipairs(tbl) do
    if type(value) == "string" then
       tbl[idx] = literalConsumers[value]
    end
  end
  
  return setmetatable(tbl, definitionMeta)
end

local function makeDefinitionMaker(literalConsumers)
  return function(tblOrString)
    if type(tblOrString) == "string" then
      return function(defTbl)
        local tbl = convertLiterals(defTbl, literalConsumers)
        tbl.name = tblOrString
        return tbl
      end
    else
      return convertLiterals(tblOrString, literalConsumers)
    end
  end
end

-----------------<| Global definition

local globalDefinitionMeta = {
  __call = function(self, reader, parsed)
    return reader, parsed
  end
}

local function makeGlobalDefinitionMaker(grammar_ENV)
  return function(tbl)
    for name, definition in pairs(tbl) do
      grammar_ENV[name] = definition
    end

    return setmetatable(tbl, globalDefinitionMeta)
  end
end

-----------------<| Repeated definition

local function repeatDefinition(minimumCount, maximumCount, defTbl, name)
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

-----------------<| Parser

local Parser = {}

local function loadFile(address, grammar_ENV)
  local fn, message = loadfile(address, "t", grammar_ENV)
  return fn and fn() or error(message)
end

local function each(fn, tbl)
  for k,v in pairs(tbl) do
    fn(k,v)
  end
end

function Parser.loadGrammar(grammarFileAddress, constructMatchers, literalMatchers)
  local grammar_ENV = {}
  local literalConsumers = {}
  
  each(function(name, matcher) grammar_ENV[name] = makeConsumer(matcher, name) end, constructMatchers)
  each(function(name, matcher) literalConsumers[name] = makeConsumer(matcher, name) end, literalMatchers)

  definition = makeDefinitionMaker(literalConsumers)
  alternation = makeAlternationMaker(literalConsumers)
  definitionMeta = makeDefinitionMeta()
  alternationMeta = makeAlternationMeta()
  -- The way I handle string literals and alternation is pretty messy atm. Also the way I handle the passing of labels/names. Needs a rework
  globalDefinition = makeGlobalDefinitionMaker(grammar_ENV)
  
  setmetatable(grammar_ENV, { __index = function(self, key) 
    return definition {
      function(...)
        local val = rawget(self, key)
        
        if not val then error("Missing grammar key:", key) end
        if not type(val) == "table" then error("Grammar key:", key, "is of incorrect type", type(val)) end
        
        return val(...)
      end }
  end })
  
  local grammarNull = setmetatable({}, {
    __div = alternation,
    __call = function() return false end,
    __tostring = function() return "null" end
  })
  
  each(function(shorthand, func) grammar_ENV[shorthand] = func end, { 
    null = grammarNull, 
    d = definition, 
    g = globalDefinition, 
    r = repeatedDefinition, 
    c = repeatedDefinition(0, 1),
    cm = repeatedDefinition(0),
    m = repeatedDefinition()
  })
  
  local grammar = require(grammarFileAddress)(grammar_ENV)
  
  return function(tokenList)
    local reader, result = grammar(TableReader.new(tokenList), listNull)
    
    return result ~= listNull
       and result:take()
  end
end

return Parser
