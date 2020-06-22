local index_G = { __index = _G }
local _ENV = setmetatable({ _G = _G}, index_G) -- Declare sandbox

local view = require "debugview"
local StringIndexer = require "StringIndexer"
local list = require "SinglyLinkedList"

local null = list.null
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

local function _logOptional(msg1, pat, msg2, strIdx, msg3, parsed)
  local stringValue = tostring(pat)

  if (not (stringValue == "ignore" and type(pat) == "table")) then
    if msg2 then
      print(msg1, stringValue, msg2, strIdx, msg3, parsed and table.concat(parsed:take(35)))
    else
      print(msg1, pat)
    end
  end
end


local function stub() end

-- Exchange print and indentedPrint to 'stub' to disable logging.
local _print = print
local print = _print

local logOptional = _logOptional

--[=====================]--
--|Higher Order Patterns|-------------------------------------------------------------------------------------
--[=====================]--

-- Advance pointer if contents of table matches eluChars at idx
local function kwCompare(keyword, strIdx, parsed)
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
local function patternIntersection(left, right)
  if not left then error("Missing left pattern") end
  if not right then error("Missing right pattern") end
  
  return pattern(function(_, strIdx, parsed)
    logOptional("About to run intersection left:", left)
    local leftStrIdx, leftParsed = left(strIdx, parsed)
    logOptional("INTERSECTION LEFT PATTERN", left, "LEFT STR IDX", leftStrIdx, "PRODUCED", leftParsed)
    
    if leftStrIdx then
      logOptional("About to run intersection right:", right)
      local rightStrIdx, rightParsed = right(leftStrIdx, leftParsed)
      logOptional("INTERSECTION RIGHT PATTERN", right, "RIGHT STR IDX", rightStrIdx, "PRODUCED", rightParsed)
      
      if rightStrIdx then        
        return rightStrIdx, rightParsed
      end
    end
    
    return false
  end) * ("(" .. tostring(left) .. " + " .. tostring(right) .. ")")
end

-- Pattern OR operator
local function patternUnion(left, right)
  if not left then error("Missing left pattern") end
  if not right then error("Missing right pattern") end
  
  return pattern(function(_, strIdx, parsed)
    logOptional("Union about to run left:", left)
    local leftStrIdx, leftParsed = left(strIdx, parsed)
    logOptional("UNION LEFT PATTERN", left, "LEFT STR IDX", leftStrIdx, "PRODUCED", leftParsed)
    
    if leftStrIdx then
      return leftStrIdx, leftParsed 
    end
    
    logOptional("\nUnion about to run right:", right)
    local rightStrIdx, rightParsed = right(strIdx, parsed)
    logOptional("UNION RIGHT PATTERN", right, "RIGHT STR IDX", rightStrIdx, "PRODUCED", rightParsed)
    
    return rightStrIdx, rightParsed
  end) * ("(" .. tostring(left) .. " / " .. tostring(right) .. ")")
end

-- Pattern appears zero or one times. Similar to '?' in regex
function maybe(childPattern)
  if not childPattern then error("Missing child pattern") end
  
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
function many(childPattern)
  if not childPattern then error("Missing child pattern") end
  
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
function maybemany(childPattern)
  return maybe(many(childPattern))
end

-- Variables cannot share a name with a keyword. This rule clears up otherwise ambiguous syntax
-- Also packs variable names (see packString for details)
function checkNotKeywordThenPack(childPattern)
  if not childPattern then error("Missing child pattern") end
  
  return pattern(function(_, strIdx, parsed)
    local returnedStrIdx, returnedParsed = childPattern(strIdx, null)
    
    if not returnedStrIdx then return false end
    
    local whatChildParsed = returnedParsed:take()
    local parsedIndexer = StringIndexer.new(whatChildParsed, 1)
    
    local function loop(gen, tbl, state)
      local kwName, kwParser = gen(tbl, state)
    
      return kwParser
         and ((#kwParser == #whatChildParsed and kwParser(parsedIndexer, null))
              or loop(gen, tbl, kwName))
    end
    
    local matchesAnyKeyword = loop(pairs(keywordExports))
        
    if matchesAnyKeyword then
      return false
    else
      local packed = table.concat(whatChildParsed)
      print("checkNotKeywordThenPack: packing value to be:", packed)
      return returnedStrIdx, cons(packed, parsed)
    end
  end) * ("checkNotKeywordThenPack(" .. tostring(childPattern) .. ")")
end

-- All syntax is delimited with spaces in the output.
-- A string put through this would come out as " e n d ".
-- This function packs the child patterns into a single string, which is delimited correctly.
function packString(childPattern)
  if not childPattern then error("Missing child pattern") end
  
  return pattern(function(_, strIdx, parsed)
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

Whitespace = pattern(function(_, strIdx, parsed)
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

Alphabetic = makeRxMatcher("[%a_]")
                 * "Alphabetic"

Digit = makeRxMatcher("%d")
            * "Digit"
            
Alphanumeric = makeRxMatcher("[%w_]")
                   * "Alphanumeric"

local lateinitRepo = {}
local lateinitNames = {}

-- Permit circular references using a promise stored in the 'lateinitNames' table
function lateinit(childPatternName)
  lateinitNames[childPatternName] = true
  local childPattern
  
  return pattern(function(_, strIdx, parsed)
    if not childPattern then
      childPattern = lateinitRepo[childPatternName]
      if not childPattern then error("Cannot load lateinit: " .. (childPatternName or "[No name]")) end
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


--[=======]--
--|Exports|---------------------------------------------------------------------------------------------------
--[=======]--

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
	kw_else = kw "else",
  kw_goto = kw "goto",
	kw_then = kw "then",
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


kw_multiline_close = sym "]]"
kw_multiline_open = sym "[["
kw_bracket_close = sym "]"
kw_bracket_open = sym "["
kw_label_delim = sym "::"
kw_brace_close = sym "}"
kw_paren_close = sym ")"
kw_speech_mark = sym '"'
kw_ellipsis = sym "..."
kw_paren_open = sym "("
kw_backslash = sym "\\"
kw_brace_open = sym "{"
kw_are_equal = sym "=="
kw_not_equal = sym "~="
kw_semicolon = sym ";"
kw_concat = sym ".."
kw_equals = sym "="
kw_divide = sym "/"
kw_modulo = sym "%"
kw_caret = sym "^"
kw_comma = sym ","
kw_colon = sym ":"
kw_minus = sym "-"
kw_quote = sym "'"
kw_times = sym "*"
kw_hash = sym "#"
kw_plus = sym "+"
kw_lte = sym "<="
kw_gte = sym ">="
kw_dot = sym "."
kw_lt = sym "<"
kw_gt = sym ">"


setmetatable(_ENV, { __index = keywordExports }) -- Add keywords to environment
_G.setmetatable(keywordExports, index_G) -- Ensure that _G is still accessible

local fn, message = loadfile("ebnf.lua", "t", _ENV) -- Declare lua eBNF. Entrypoint is 'block'


if fn then fn() else error(message) end

local function parseChars(chars)
  local _, parsedStrs = block(StringIndexer.new(chars, 1), null)
  return tostring(parsedStrs)
end

local function parseString(str)
  return parseChars(toChars(str))
end

return { parseString = parseString, parseChars = parseChars }
