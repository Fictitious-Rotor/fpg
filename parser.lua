local index_G = { __index = _G }
local _ENV = setmetatable({ _G = _G}, index_G) -- Declare sandbox

local view = require "debugview"
local StringIndexer = require "StringIndexer"
local list = require "SinglyLinkedList"

null = list.null
cons = list.cons

pattern, patternNoWhitespace, kw, keywordExports, Name, Number, Whitespace, Alphanumeric = true, true, true, true, true, true, true, true
 -- Declared here as they are referenced in the higher order patterns

local function toChars(str)
  local out = {}
  
  for c in str:gmatch(".") do
    out[#out + 1] = c
  end
  
  return out
end

local function getterSetter(key)
  return function(tbl) return tbl[key] end, 
         function(tbl, value) tbl[key] = value return tbl end
end

local getRefuseBacktrack, setRefuseBacktrack = getterSetter("refuseBacktrack")
getNeedsWhitespace, setNeedsWhitespace = getterSetter("needsWhitespace")

local parsedLogCharLimit = 35
local parsedErrorCharLimit = 300

local function _logOptional(pat, parsed, ...)
  local stringValue = tostring(pat)

  if (not (stringValue == "ignore" and type(pat) == "table")) then
    for _, v in pairs({...}) do
      io.write(tostring(v), "\t")
    end
    
    io.write("with pattern:\t", tostring(pat), "\n")
    
    if parsed then
      print("and parsed:", table.concat(parsed:take(parsedLogCharLimit)), "\n")
    end
  end
end


local function stub() end

-- Exchange print and indentedPrint to 'stub' to disable logging.
local _print = print
local print = stub --_print

local logOptional = stub --_logOptional

--[========]--
--|Lateinit|--------------------------------------------------------------------------------------------------
--[========]--

local lateinitRepo = {}
local lateinitNames = {}

-- Permit circular references using a promise stored in the 'lateinitNames' table
function lateinit(childPatternName)
  lateinitNames[childPatternName] = true
  local childPattern
  
  return pattern(function(strIdx, parsed)
    if not childPattern then
      childPattern = lateinitRepo[childPatternName]
      if not childPattern then error(string.format("Cannot load lateinit: %s", (childPatternName or "[No name]"))) end
    end
    
    return childPattern(strIdx, parsed)
  end) * childPatternName
end

-- Initialise all promised references by drawing them from the provided table
function initialiseLateInitRepo()
  for name, _ in pairs(lateinitNames) do
    lateinitRepo[name] = _ENV[name]
  end
end

--[=====================]--
--|Higher Order Patterns|-------------------------------------------------------------------------------------
--[=====================]--

local function symCompare(symbol, strIdx, parsed)
  local pos = strIdx:getIndex()

  for _, c in ipairs(symbol) do
    if c ~= strIdx:getValue(pos) then
      return false
    end
    pos = pos + 1
  end
  
  return strIdx:withIndex(pos), cons(tostring(symbol), parsed)
end

-- Advance pointer if contents of table matches eluChars at idx
local function kwCompare(keyword, strIdx, parsed)
  local symStrIdx, symParsed = symCompare(keyword, strIdx, parsed)
  
  if not symStrIdx then return false end
  
  -- Ensure that the keyword has now stopped.
  if Alphanumeric(symStrIdx, null) then 
    print("IDENTIFIED BAD KEYWORD:", keyword, "AT STRIDX:", symStrIdx, "WITH PARSED", symParsed) 
    return false
  end
  
  return symStrIdx, symParsed
end

local function concatenationNoWhitespace(left, right)
  if not left then error("Missing left pattern") end
  if not right then error("Missing right pattern") end
  
  return patternNoWhitespace(function(strIdx, parsed)
    logOptional(left, parsed, "About to run intersection left with strIdx of:", strIdx)
    local leftStrIdx, leftParsed = left(strIdx, parsed)
    logOptional(left, leftParsed, "INTERSECTION LEFT PATTERN LEFT STR IDX", leftStrIdx)
    
    if leftStrIdx then
      logOptional(right, nil, "About to run intersection right:")
      local rightStrIdx, rightParsed = right(leftStrIdx, leftParsed)
      logOptional(right, rightParsed, "INTERSECTION RIGHT PATTERN RIGHT STR IDX", rightStrIdx)
      
      if rightStrIdx then        
        return rightStrIdx, rightParsed
      end
    end
    
    return false
  end) * ("(" .. tostring(left) .. " + " .. tostring(right) .. ")")
end

-- Pattern AND operator
-- This one's getting a bit stout and is beginning to smell. Review this once you get it working.
local function patternConcatenation(left, right)
  if not left then error("Missing left pattern") end
  if not right then error("Missing right pattern") end
  
  local leftRefusesBacktrack = getRefuseBacktrack(left)
  local enforceWhitespace = getNeedsWhitespace(left) and getNeedsWhitespace(right)
  
  if enforceWhitespace then print("Enforcing whitespace for keys of ", left, "and", right) end
  
  local concatenatedPattern = pattern(function(strIdx, parsed)
    logOptional(left, parsed, "About to run intersection left with strIdx of:", strIdx)
    local leftStrIdx, leftParsed = left(strIdx, parsed)
    logOptional(left, leftParsed, "INTERSECTION LEFT PATTERN LEFT STR IDX", leftStrIdx)
    
    if leftStrIdx then
      logOptional(Whitespace, nil, "About to run whitespace:")
      local whitespaceStrIdx, whitespaceParsed = many(Whitespace)(leftStrIdx, leftParsed)
      logOptional(right, whitespaceParsed, "INTERSECTION WHITESPACE STR IDX", whitespaceStrIdx)
      
      if not whitespaceStrIdx then
        if enforceWhitespace then
          error(string.format("Missing whitespace between patterns '%s' and '%s':\n\tAt position: %s\n\tWith parsed of %s\n", left, leftStrIdx, table.concat(leftParsed:take(parsedErrorCharLimit))))
        else
          whitespaceStrIdx, whitespaceParsed = leftStrIdx, leftParsed
        end
      end
      
      logOptional(right, nil, "About to run intersection right:")
      local rightStrIdx, rightParsed = right(whitespaceStrIdx, whitespaceParsed)
      logOptional(right, rightParsed, "INTERSECTION RIGHT PATTERN RIGHT STR IDX", rightStrIdx)
      
      if not rightStrIdx and leftRefusesBacktrack then -- A hanging keyword is invalid syntax. Time to crash out.
        error(string.format("Unable to parse after keyword: %s\nAt position: %s\nWith parsed of %s\n", left, leftStrIdx, table.concat(leftParsed:take(parsedErrorCharLimit))))
      end
      
      return rightStrIdx, rightParsed
    end
    
    return false
  end) * ("(" .. tostring(left) .. " + " .. tostring(right) .. ")")
  
  return setRefuseBacktrack(concatenatedPattern, getRefuseBacktrack(right))
end

-- Pattern OR operator
local function patternAlternation(left, right)
  if not left then error("Missing left pattern") end
  if not right then error("Missing right pattern") end
  
  return pattern(function(strIdx, parsed)
    logOptional(left, nil, "Union about to run left:")
    local leftStrIdx, leftParsed = left(strIdx, parsed)
    logOptional(left, leftParsed, "UNION LEFT PATTERN LEFT STR IDX", leftStrIdx)
    
    if leftStrIdx then
      return leftStrIdx, leftParsed 
    end
    
    logOptional(right, nil, "\nUnion about to run right:")
    local rightStrIdx, rightParsed = right(strIdx, parsed)
    logOptional(right, rightParsed, "UNION RIGHT PATTERN RIGHT STR IDX", rightStrIdx)
    
    return rightStrIdx, rightParsed
  end) * ("(" .. tostring(left) .. " / " .. tostring(right) .. ")")
end

-- Pattern appears zero or one times. Similar to '?' in regex
function maybe(childPattern)
  if not childPattern then error("Missing child pattern") end
  
  return pattern(function(strIdx, parsed)
    logOptional(childPattern, parsed, "Executing maybe with strIdx:", strIdx)
    local childStrIdx, childParsed = childPattern(strIdx, parsed)
    
    if childStrIdx then
      return childStrIdx, childParsed
    else
      return strIdx, parsed
    end
  end) * ("maybe(" .. tostring(childPattern) .. ")")
end

-- Pattern appears one or more times. Similar to '+' in regex
function many(childPattern)
	if not childPattern then error("Missing child pattern") end
  
  return pattern(function(strIdx, parsed)
    logOptional(childPattern, parsed, "Executing many with strIdx:", strIdx)
    return (childPattern + maybe(many(childPattern)))(strIdx, parsed)
  end) * ("many(" .. tostring(childPattern) .. ")")
end

-- Pattern appears zero or more times. Similar to '*' in regex
function maybemany(childPattern)
  return maybe(many(childPattern))
end

-- Variables cannot share a name with a keyword. This rule clears up otherwise ambiguous syntax
-- Also packs variable names (see packString for details)
function checkNotKeywordThenPack(childPattern)
  if not childPattern then error("Missing child pattern") end
  
  return pattern(function(strIdx, parsed)
    local returnedStrIdx, returnedParsed = childPattern(strIdx, null)
    
    if not returnedStrIdx then return false end
    
    local whatChildParsed = returnedParsed:take()
    print("checkNotKeywordThenPack: whatChildParsed:", table.concat(whatChildParsed))
    local parsedIndexer = StringIndexer.new(whatChildParsed, 1)
    
    local function loop(gen, tbl, state)
      local kwName, kwParser = gen(tbl, state)
    
      return kwParser
         and ((#kwParser == #whatChildParsed and kwParser(parsedIndexer, null))
              or loop(gen, tbl, kwName))
    end
    
    local matchesAnyKeyword = loop(pairs(keywordExports))
        
    if matchesAnyKeyword then
      print("checkNotKeywordThenPack: That's a keyword!")
      return false
    else
      local packed = table.concat(whatChildParsed)
      print("checkNotKeywordThenPack: packing value to be:", packed)
      return returnedStrIdx, cons(packed, parsed)
    end
  end) * ("checkNotKeywordThenPack(" .. tostring(childPattern) .. ")")
end

-- MANAGEMENT OF WHITESPACE HAS BEEN IMPROVED SO THAT THIS IS NO LONGER THE CASE. PACKING WILL STILL BE USEFUL FOR MACROS, THOUGH. UPDATE THE COMMENTS.
-- All syntax is delimited with spaces in the output.
-- A string put through this would come out as " e n d ".
-- This function packs the child patterns into a single string, which is delimited correctly.
function packString(childPattern)
  if not childPattern then error("Missing child pattern") end
  
  return pattern(function(strIdx, parsed)
    local returnedStrIdx, returnedParsed = childPattern(strIdx, null)
    
    if not returnedStrIdx then return false end
    
    local packed = tostring(returnedParsed)
    print("packString: packing value to be:", packed)
    return returnedStrIdx, cons(packed, parsed)
  end) * ("packString(" .. tostring(childPattern) .. ")")
end

-- Consumes a single character given that childPattern fails to match.
function notPattern(childPattern)
  if not childPattern then error("Missing child pattern") end
  
  return pattern(function(strIdx, parsed)
    local value = strIdx:getValue()
  
    return value
       and not childPattern(strIdx, parsed)
       and strIdx:withFollowingIndex(), cons(value, parsed)
  end) * ("notPattern(" .. tostring(childPattern) .. ")")
end

function notToBeConfusedWith(childPattern, ...)
  local otherPatterns = {...}

  return pattern(function(strIdx, parsed)
    for _, otherPattern in pairs(otherPatterns) do
      if otherPattern(strIdx, parsed) then return false end
    end
    
    return childPattern(strIdx, parsed)
  end)
end

--[==========]--
--|Metatables|------------------------------------------------------------------------------------------------
--[==========]--

--- The value of tostring may not be clear when the pattern is initially constructed. This function lets you bind tostring at a later point.
local function attachLabel(tbl, name)
  getmetatable(tbl).__tostring = function() return name end
  return tbl
end

pattern = function(fn)
  return setmetatable({}, { 
    __call = function(_, strIdx, parsed)
               return fn(strIdx, parsed)
             end,
    __add = patternConcatenation, 
    __div = patternAlternation, 
    __mul = attachLabel
  })
end

patternNoWhitespace = function(fn)
  return setmetatable({}, {
    __call = function(tbl, strIdx, parsed)
               return fn(strIdx, parsed)
             end,
    __add = concatenationNoWhitespace,
    __div = patternAlternation,
    __mul = attachLabel
  })
end

kw = function(str)
  local charTable = setNeedsWhitespace(setRefuseBacktrack(toChars(str), true), true)
  
  return setmetatable(charTable, {
    __call = kwCompare,
    __add = patternConcatenation, 
    __div = patternAlternation,
    __len = function() return #str end,
    __tostring = function() return str end
  })
end

sym = function(str)
  local charTable = setRefuseBacktrack(toChars(str), true)
  
  return setmetatable(charTable, {
    __call = symCompare,
    __add = patternConcatenation, 
    __div = patternAlternation,
    __len = function() return #str end,
    __tostring = function() return str end
  })
end

--[===================]--
--|Loading and exports|---------------------------------------------------------------------------------------
--[===================]--

local function loadFile(address)
  local fn, message = loadfile(address, "t", _ENV)
  return fn and fn() or error(message)
end

-- Load terminals
keywordExports = loadFile("terminals.lua")

setmetatable(_ENV, { __index = keywordExports }) -- Add keywords to environment
_G.setmetatable(keywordExports, index_G) -- Ensure that _G is still accessible

local entrypoint = loadFile("ebnf.lua") -- Declare lua eBNF. Entrypoint is 'block'

local function parseChars(chars)
  local _, parsedStrs = entrypoint(StringIndexer.new(chars, 1), null)
  return tostring(parsedStrs)
end

local function parseString(str)
  return parseChars(toChars(str))
end

return { parseString = parseString, parseChars = parseChars }
