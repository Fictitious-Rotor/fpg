view = require "debugview"
local list = require "SinglyLinkedList"
null = list.null
local cons = list.cons

local patternIntersection, patternUnion
local kwCompare

local pattern, kw -- Declared here as they are referenced in the higher order patterns

local function toChars(str)
  local out = {}
  
  for c in str:gmatch(".") do
    out[#out + 1] = c
  end
  
  return out
end

local function skipSpaces(strIdx)
  local idx = strIdx:getIndex()
  while strIdx:getValue(idx) == ' ' do
    idx = idx + 1
  end
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


--[=====================]--
--|Higher Order Patterns|-------------------------------------------------------------------------------------
--[=====================]--

-- Advance pointer if contents of table matches eluChars at idx
kwCompare = function(keyword, strIdx, parsed)
  local pos = skipSpaces(strIdx)

  for _, c in ipairs(keyword) do
    if c ~= strIdx:getValue(pos) then
      return false
    end
    pos = pos + 1
  end
  
  return strIdx:withIndex(pos), cons(tostring(keyword), parsed)
end

-- Intersection of two checks, returns either the index after both patterns, followed by a table of both patterns represented as strings or false
patternIntersection = function(left, right)
  return pattern(function(_, strIdx, parsed)
    print("About to run left fn:", left)
    local strIdxAfterLeft, leftParsed = left(strIdx, parsed)
    print("Intersection left pattern", left, "strIdxAfterLeft", strIdxAfterLeft, "produced", leftParsed)
    
    if strIdxAfterLeft then
      local strIdxAfterRight, rightParsed = right(strIdxAfterLeft, leftParsed)
      print("Intersection right pattern", right, "strIdxAfterRight", strIdxAfterRight, "produced", rightParsed)
      
      if strIdxAfterRight then        
        return strIdxAfterRight, rightParsed
      end
    end
    
    return false
  end) * ("(" .. tostring(left) .. " + " .. tostring(right) .. ")")
end

-- Union of two checks, returns either left or right
patternUnion = function(left, right)
  return pattern(function(_, strIdx, parsed)
    local strIdxAfterLeft, leftParsed = left(strIdx, parsed)
    print("Union left pattern", left, "strIdxAfterLeft", strIdxAfterLeft, "produced", leftParsed)
    
    if strIdxAfterLeft then
      return strIdxAfterLeft, leftParsed 
    end
    
    local strIdxAfterRight, rightParsed = right(strIdx, parsed)
    print("Union right pattern", right, "strIdxAfterRight", strIdxAfterRight, "produced", rightParsed)
    
    return strIdxAfterRight, rightParsed
  end) * ("(" .. tostring(left) .. " / " .. tostring(right) .. ")")
end

local function maybe(childPattern)
  return pattern(function(_, strIdx, parsed)
    local strIdxAfterChildPattern, childPatternParsed = childPattern(strIdx, parsed)
    
    if strIdxAfterChildPattern then
      return strIdxAfterChildPattern, childPatternParsed
    else
      return strIdx, parsed
    end
  end) * ("maybe (" .. tostring(childPattern) .. ")")
end 


-- Vulnerable to stack overflow. Might need to convert to for loop.
local function many(childPattern)
  return pattern(function(_, strIdx, parsed)
    local function matchChildPattern(strIdx, parsed, nesting)
      local strIdxAfterChildPattern, childPatternParsed = childPattern(strIdx, parsed)
      
      if strIdxAfterChildPattern then
        local strIdxAfterRecursion, recursionParsed = matchChildPattern(strIdxAfterChildPattern, childPatternParsed, nesting + 1)
        
        if strIdxAfterRecursion then
          return strIdxAfterRecursion, recursionParsed
        else
          return strIdxAfterChildPattern, childPatternParsed
        end
      end
      
      return false
    end
    
    return matchChildPattern(strIdx, parsed, 1)
  end) * ("many (" .. tostring(childPattern) .. ")")
end

local function maybemany(childPattern)
  return maybe(many(childPattern))
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
  return setmetatable(toChars(str), { 
    __call = kwCompare, 
    __add = patternIntersection, 
    __div = patternUnion, 
    __tostring = function() return "'" .. str .. "'" end 
  })
end


--[===================]--
--|Terminator Patterns|---------------------------------------------------------------------------------------
--[===================]--

local Whitespace = pattern(function(_, strIdx, parsed)
  local idx = strIdx:getIndex()
  
  while strIdx:getValue(idx) == ' ' do
    idx = idx + 1
  end
  
  return strIdx:withIndex(idx), parsed
end)

local function makeRxMatcher(regexPattern)
  return pattern(function(_, strIdx, parsed)
    local value = strIdx:getValue():match(regexPattern)
    
    if value then
      return strIdx:withFollowingIndex(), cons(value, parsed)
    else
      return false
    end
  end)
end

local Alphabetic = makeRxMatcher("%a") 
                 * "Alphabetic"

local Digit = makeRxMatcher("%d")
            * "Digit"

local EscapableChar = pattern(function(_, strIdx, parsed)
  local value = strIdx:getValue()
  local escaped = value == '\\'
  
  if escaped then
    local idx = strIdx:getIndex()
    local value = strIdx:getValue(idx + 1)
    
    if not value then
      error("Unterminated string at position:", idx)
    end
    
    return strIdx:withIndex(idx + 2), cons(value, cons('\\', parsed))
  end
  
  local isStringBoundary = value == '"' or value == "'"
  
  if not isStringBoundary then
    return strIdx:withFollowingIndex(), cons(value, parsed)
  else
    return false
  end
end) * "EscapableChar"


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

local exports = {
  -- Utilities
  toChars = toChars,

  -- Functions
  maybe = maybe,
  many = many,
  maybemany = maybemany,
  
  -- Terminators
  Whitespace = Whitespace,
  Alphabetic = Alphabetic,
  EscapableChar = EscapableChar,
  Digit = Digit,
  
  -- Workarounds
  lateinit = lateinit,
  initialiseLateInitRepo = initialiseLateInitRepo,

  -- Keywords
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
	kw_function = kw "function",

	kw_bracket_close = kw "]",
	kw_bracket_open = kw "[",
	kw_brace_close = kw "}",
	kw_paren_close = kw ")",
  kw_speech_mark = kw '"',
	kw_ellipsis = kw "...",
	kw_paren_open = kw "(",
	kw_brace_open = kw "{",
	kw_are_equal = kw "==",
	kw_not_equal = kw "~=",
	kw_semicolon = kw ";",
	kw_concat = kw "..",
	kw_equals = kw "=",
	kw_divide = kw "/",
	kw_modulo = kw "%",
	kw_length = kw "#",
	kw_caret = kw "^",
	kw_comma = kw ",",
	kw_colon = kw ":",
	kw_minus = kw "-",
  kw_quote = kw "'",
	kw_times = kw "*",
	kw_plus = kw "+",
	kw_lte = kw "<=",
	kw_gte = kw ">=",
	kw_dot = kw ".",
	kw_lt = kw "<",
	kw_gt = kw ">"
}

setmetatable(exports, {
  __call = function(t)
    for k, v in pairs(t) do
      rawset(_G, k, v)
    end
  end,
})

return exports