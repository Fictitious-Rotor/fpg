view = require "debugview"
StringIndexer = require "StringIndexer"
local list = require "SinglyLinkedList"
null = list.null
local cons = list.cons

local pattern, kw, keywordExports -- Declared here as they are referenced in the higher order patterns

local function toChars(str)
  local out = {}
  
  for c in str:gmatch(".") do
    out[#out + 1] = c
  end
  
  return out
end

local function skipWhitespace(strIdx)
  local idx = strIdx:getIndex() - 1
  local value
  
  repeat
    idx = idx + 1
    value = strIdx:getValue(idx)
  until not (value == ' ' or value == '\r' or value == '\n')
  
  return idx
end

local function skipComments(strIdx)
  local idx = strIndex:getIdx()

  if  (strIdx:getValue(idx) == '-') 
  and (strIdx:getValue(idx + 1) == '-') 
  then
    local multiline = strIdx:getValue(idx + 2) == '[' 
                  and strIdx:getValue(idx + 3) == '['
    idx = idx + (multiline and 4 or 2)
    
    if multiline then
      repeat
        idx = idx + 1
      until (strIdx:getValue(idx) == ']' 
        and  strIdx:getValue(idx - 1) == ']')
    else
      while not (strIdx:getValue(idx) == '\n') do
        idx = idx + 1
      end
    end
    
    return idx + 1
  else
    return idx
  end
end

local function setValue(tbl, val, idx)
  tbl[idx] = val
  return tbl
end

local function indentedPrint(parsed, message, ...)
  local function getSpaces(count)
    return count == 0 
       and {}
        or setValue(getSpaces(count - 1), "  ", count)    
  end
  
  local prefixSpaces = table.concat(getSpaces(parsed:getLength()))
  
  print(prefixSpaces .. message, ...)
end


--[=====================]--
--|Higher Order Patterns|-------------------------------------------------------------------------------------
--[=====================]--

-- Advance pointer if contents of table matches eluChars at idx
local kwCompare = function(keyword, strIdx, parsed)
  local pos = skipWhitespace(strIdx)

  for _, c in ipairs(keyword) do
    if c ~= strIdx:getValue(pos) then
      return false
    end
    pos = pos + 1
  end
  
  return strIdx:withIndex(pos), cons(tostring(keyword), parsed)
end

-- Pattern AND operator
local patternIntersection = function(left, right)
  return pattern(function(_, strIdx, parsed)
    indentedPrint(parsed, "About to run left fn:", left)
    local leftStrIdx, leftParsed = left(strIdx, parsed)
    indentedPrint(parsed, "Intersection left pattern", left, "leftStrIdx", leftStrIdx, "produced", leftParsed)
    
    if leftStrIdx then
      indentedPrint(parsed, "About to run right fn:", right)
      local rightStrIdx, rightParsed = right(leftStrIdx, leftParsed)
      indentedPrint(parsed, "Intersection right pattern", right, "rightStrIdx", rightStrIdx, "produced", rightParsed)
      
      if rightStrIdx then        
        return rightStrIdx, rightParsed
      end
    end
    
    return false
  end) * ("(" .. tostring(left) .. " + " .. tostring(right) .. ")")
end

-- Pattern OR operator
local patternUnion = function(left, right)
  return pattern(function(_, strIdx, parsed)
    local leftStrIdx, leftParsed = left(strIdx, parsed)
    indentedPrint(parsed, "Union left pattern", left, "leftStrIdx", leftStrIdx, "produced", leftParsed)
    
    if leftStrIdx then
      return leftStrIdx, leftParsed 
    end
    
    local rightStrIdx, rightParsed = right(strIdx, parsed)
    indentedPrint(parsed, "Union right pattern", right, "rightStrIdx", rightStrIdx, "produced", rightParsed)
    
    return rightStrIdx, rightParsed
  end) * ("(" .. tostring(left) .. " / " .. tostring(right) .. ")")
end

-- Pattern appears zero or one times. Similar to '?' in regex
local function maybe(childPattern)
  return pattern(function(_, strIdx, parsed)
    local childStrIdx, childParsed = childPattern(strIdx, parsed)
    
    if childStrIdx then
      return childStrIdx, childParsed
    else
      return strIdx, parsed
    end
  end) * ("maybe(" .. tostring(childPattern) .. ")")
end 

-- Pattern appears one or more times. Similar to '+' in regex
local function many(childPattern)
  return pattern(function(_, strIdx, parsed)
    local function unpackReturn(packed)
      if packed then
        return packed[1], packed[2]
      else
        return false
      end
    end
  
    local function matchChildPattern(strIdx, parsed)
      local childStrIdx, childParsed = childPattern(strIdx, parsed)
      
      return childStrIdx
         and (matchChildPattern(childStrIdx, childParsed)
              or { childStrIdx, childParsed })
    end
    
    return unpackReturn(matchChildPattern(strIdx, parsed))
  end) * ("many(" .. tostring(childPattern) .. ")")
end

-- Pattern appears zero or more times. Similar to '*' in regex
local function maybemany(childPattern)
  return maybe(many(childPattern))
end

-- Variables cannot share a name with a keyword. This rule clears up otherwise ambiguous syntax
-- Also packs variable names (see packString for details)
local function checkNotKeywordThenPack(childPattern)
  return pattern(function(_, strIdx, parsed)
    local returnedStrIdx, returnedParsed = childPattern(strIdx, null)
    
    if not returnedStrIdx then return false end
    
    local whatChildParsed = returnedParsed:take()
    local parsedIndexer = StringIndexer.new(whatChildParsed, 1)
    
    local function loop(gen, tbl, state)
      local kwName, kwParser = gen(tbl, state)
      indentedPrint(parsed, "Checking against parser:", kwParser, "with name of:", kwName)
    
      return kwParser
         and ((#kwParser == #whatChildParsed and kwParser(parsedIndexer, null))
              or loop(gen, tbl, kwName))
    end
    
    local matchesAnyKeyword = loop(pairs(keywordExports))
    indentedPrint(parsed, "Checking keywords...", "matchesAnyKeyword", table.concat(whatChildParsed), "matchesAnyKeyword", matchesAnyKeyword)
    
    if matchesAnyKeyword then
      return false
    else
      local packed = table.concat(whatChildParsed)
      indentedPrint(parsed, "checkNotKeywordThenPack: packing value to be:", packed)
      return returnedStrIdx, cons(packed, parsed)
    end
  end) * ("checkNotKeywordThenPack(" .. tostring(childPattern) .. ")")
end

-- All syntax is delimited with spaces in the output.
-- A string put through this would come out as " e n d ".
-- This function packs the child patterns into a single string, which is delimited correctly.
local function packString(childPattern)
  return pattern(function(_, strIdx, parsed)
    local returnedStrIdx, returnedParsed = childPattern(strIdx, null)
    
    if not returnedStrIdx then return false end
    
    local packed = tostring(returnedParsed)
    indentedPrint(parsed, "packString: packing value to be:", packed)
    return returnedStrIdx, cons(packed, parsed)
  end) * ("packString(" .. tostring(childPattern) .. ")")
end

-- Consumes a single character given that childPattern fails to match.
local function notPattern(childPattern)
  return pattern(function(_, strIdx, parsed)
    local value = strIdx:getValue()
  
    return value
       and not childPattern(strIdx, parsed)
       and strIdx:withFollowingIndex(), cons(value, parsed)
  end) * ("notPattern(" .. tostring(childPattern) .. ")")
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
    __call = fn, 
    __add = patternIntersection, 
    __div = patternUnion, 
    __mul = attachLabel 
  })
end

kw = function(str)
  local spacedStr = " " .. str .. " "
  
  return sym(str, spacedStr)
end

sym = function(matchStr, tostringStr)
  local tostringStr = tostringStr or matchStr
  
  return setmetatable(toChars(matchStr), { 
    __call = kwCompare, 
    __add = patternIntersection, 
    __div = patternUnion,
    __len = function() return #matchStr end,
    __tostring = function() return tostringStr end
  })
end


--[===================]--
--|Terminator Patterns|---------------------------------------------------------------------------------------
--[===================]--

local Whitespace = pattern(function(_, strIdx, parsed)
  return strIdx:withIndex(skipWhitespace(strIdx)), parsed
end) * "Whitespace"

local function makeRxMatcher(regexPattern)
  return pattern(function(_, strIdx, parsed)
    local value = (strIdx:getValue() or ""):match(regexPattern)
    
    if value then
      return strIdx:withFollowingIndex(), cons(value, parsed)
    else
      return false
    end
  end)
end

local Alphabetic = makeRxMatcher("[%a_]")
                 * "Alphabetic"

local Digit = makeRxMatcher("%d")
            * "Digit"
            
local Alphanumeric = makeRxMatcher("[%w_]")
                   * "Alphanumeric"

local lateinitRepo = {}
local lateinitNames = {}

-- Permit circular references using a promise stored in the 'lateinitNames' table
local function lateinit(childPatternName)
  lateinitNames[childPatternName] = true
  local childPattern
  
  return pattern(function(_, strIdx, parsed)
    if not childPattern then
      childPattern = lateinitRepo[childPatternName]
    end
    
    return childPattern(strIdx, parsed)
  end) * childPatternName
end

-- Initialise all promised references by drawing them from the provided table
local function initialiseLateInitRepo(tbl)
  for name, _ in pairs(lateinitNames) do
    lateinitRepo[name] = tbl[name]
  end
end


--[=======]--
--|Exports|---------------------------------------------------------------------------------------------------
--[=======]--

local functionExports = {
  -- Utilities
  toChars = toChars,

  -- Functions
  maybe = maybe,
  many = many,
  maybemany = maybemany,
  checkNotKeywordThenPack = checkNotKeywordThenPack,
  packString = packString,
  notPattern = notPattern,
  
  -- Terminators
  Whitespace = Whitespace,
  Alphabetic = Alphabetic,
  Alphanumeric = Alphanumeric,
  Digit = Digit,
  EscapableChar = EscapableChar,
  
  -- Workarounds
  lateinit = lateinit,
  initialiseLateInitRepo = initialiseLateInitRepo
}

keywordExports = {
  kw_do = kw "do",
	kw_if = kw "if",
	kw_in = kw "in",
	kw_or = kw "or",
	kw_end = kw "end",
	kw_for = kw "for",
	kw_nil = kw "nil",
	kw_and = kw "and",
	kw_not = kw "not",
	kw_then = kw "then",
	kw_else = kw "else",
	kw_true = kw "true",
	kw_while = kw "while",
	kw_until = kw "until",
	kw_local = kw "local",
	kw_break = kw "break",
	kw_false = kw "false",
	kw_repeat = kw "repeat",
	kw_elseif = kw "elseif",
	kw_return = kw "return",
	kw_function = kw "function"
}

local symbolExports = {
  kw_multiline_close = sym "]]",
  kw_multiline_open = sym "[[",
  kw_bracket_close = sym "]",
	kw_bracket_open = sym "[",
	kw_brace_close = sym "}",
	kw_paren_close = sym ")",
  kw_speech_mark = sym '"',
	kw_ellipsis = sym "...",
	kw_paren_open = sym "(",
  kw_backslash = sym "\\",
	kw_brace_open = sym "{",
	kw_are_equal = sym "==",
	kw_not_equal = sym "~=",
	kw_semicolon = sym ";",
	kw_concat = sym "..",
	kw_equals = sym "=",
	kw_divide = sym "/",
	kw_modulo = sym "%",
	kw_length = sym "#",
	kw_caret = sym "^",
	kw_comma = sym ",",
	kw_colon = sym ":",
	kw_minus = sym "-",
  kw_quote = sym "'",
	kw_times = sym "*",
	kw_plus = sym "+",
	kw_lte = sym "<=",
	kw_gte = sym ">=",
	kw_dot = sym ".",
	kw_lt = sym "<",
	kw_gt = sym ">"
}

local exports = {
  functionExports,
  keywordExports,
  symbolExports
}

setmetatable(exports, {
  __call = function(exportTable) -- I've hard coded usage of two layers as patterns & keywords cannot be cleanly differentiated from export tables
    for idx, subTable in pairs(exportTable) do
      for k, v in pairs(subTable) do
        rawset(_G, k, v)
      end
    end
  end,
})

return exports
