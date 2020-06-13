view = require "debugview"

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
kwCompare = function(keyword, strIdx)
  local pos = skipSpaces(strIdx)

  for _, c in ipairs(keyword) do
    if c ~= strIdx:getValue(pos) then
      return false
    end
    pos = pos + 1
  end
  
  return strIdx:withIndex(pos), tostring(keyword)
end

-- Intersection of two checks, returns either the index after both patterns, followed by a table of both patterns represented as strings or false
patternIntersection = function(left, right)
  return pattern(function(_, strIdx)
    local strIdxAfterLeft, leftOutput = left(strIdx)
    print("Intersection left pattern", left, "strIdxAfterLeft", strIdxAfterLeft, "produced", view(leftOutput))
    
    if strIdxAfterLeft then
      local outTable = type(leftOutput) == "table" and leftOutput or { leftOutput }
      local strIdxAfterRight, rightOutput = right(strIdxAfterLeft)
      print("Intersection right pattern", right, "strIdxAfterRight", strIdxAfterRight, "produced", view(rightOutput))
      
      if strIdxAfterRight then
        outTable[#outTable + 1] = rightOutput
        
        return strIdxAfterRight, outTable
      end
    end
    
    return false
  end) * ("(" .. tostring(left) .. " + " .. tostring(right) .. ")")
end

-- Union of two checks, returns either left or right
patternUnion = function(left, right)
  return pattern(function(_, strIdx)
    local strIdxAfterLeft, leftOutput = left(strIdx)
    print("Union left pattern", left, "strIdxAfterLeft", strIdxAfterLeft, "produced", view(leftOutput))
    
    if strIdxAfterLeft then
      return strIdxAfterLeft, leftOutput 
    end
    
    local strIdxAfterRight, rightOutput = right(strIdx)
    print("Union right pattern", right, "strIdxAfterRight", strIdxAfterRight, "produced", view(rightOutput))
    
    return strIdxAfterRight, rightOutput
  end) * ("(" .. tostring(left) .. " / " .. tostring(right) .. ")")
end

local function maybe(childPattern)
  return pattern(function(_, strIdx)
    local strIdxAfterChildPattern, childPatternOutput = childPattern(strIdx)
    
    if strIdxAfterChildPattern then
      return strIdxAfterChildPattern, childPatternOutput
    else
      return strIdx, ""
    end
  end) * ("maybe (" .. tostring(childPattern) .. ")")
end 

local function many(childPattern)
  return pattern(function(_, strIdx)
    local function matchChildPattern(strIdx, nesting)
      local strIdxAfterChildPattern, childPatternOutput = childPattern(strIdx)
      
      if strIdxAfterChildPattern then
        local strIdxAfterRecursion, recursionOutput = matchChildPattern(strIdxAfterChildPattern, nesting + 1)
        
        if strIdxAfterRecursion then
          recursionOutput[nesting] = childPatternOutput
          return strIdxAfterRecursion, recursionOutput
        else
          return strIdxAfterChildPattern, { [nesting] = childPatternOutput }
        end
      end
      
      return false
    end
    
    return matchChildPattern(strIdx, 1)
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

local Number = pattern(function(_, strIdx)
  local idx = skipSpaces(strIdx)
  
  local function consumeChar(idx, nesting)
    local number = (strIdx:getValue(idx) or ""):match("%d")
    
    if number then
      local outIdx, followingNumbers = consumeChar(idx + 1, nesting + 1)
      
      if outIdx then
        followingNumbers[nesting] = number
        return outIdx, followingNumbers
      else
        return idx, { [nesting] = number }
      end
    end
    
    return false
  end
  
  local outIdx, result = consumeChar(idx, 1)
  
  if outIdx then
    return strIdx:withIndex(outIdx), table.concat(result)
  else
    return false
  end
end) * "Number"



local Name = pattern(function(_, strIdx)
  local idx = skipSpaces(strIdx)

  local function consumeChar(idx, nesting)
    local matchedChar = (strIdx:getValue(idx) or ""):match("[%w_]")
    
    if matchedChar then
      local outIdx, followingChars = consumeChar(idx + 1, nesting + 1)
      
      if outIdx then
        followingChars[nesting] = matchedChar
        return outIdx, followingChars
      else
        return idx, { [nesting] = matchedChar }
      end
    end
    
    return false
  end
  
  local leadingChar = (strIdx:getValue(idx) or ""):match("%a")
  
  if not leadingChar then 
    return false
  else
    local outIdx, followingChars = consumeChar(idx + 1, 2)
        
    if outIdx then 
      followingChars[1] = leadingChar
      return strIdx:withIndex(outIdx), table.concat(followingChars)
    else
      return strIdx:withIndex(idx + 1), leadingChar
    end
  end
end) * "Name"



local String = pattern(function(_, strIdx)
  local idx = skipSpaces(strIdx)
  local boundaryMarker = strIdx:getValue(idx)
  
  if not (boundaryMarker == '"' or boundaryMarker == "'") then
    return false
  end

  function consumeChar(idx, nesting, escaped)
    if not escaped then
      local curChar = strIdx:getValue(idx)
      
      if not curChar then
        error("Unterminated string at position:", idx)
      elseif curChar == boundaryMarker then
        return idx + 1, { [nesting] = curChar }
      else
        local escapeNext = curChar == "\\"
        local outIdx, followingChars = consumeChar(idx + 1, nesting + 1, escapeNext)
        
        followingChars[nesting] = curChar
        
        return outIdx, followingChars
      end
    else
      local outIdx, followingChars = consumeChar(idx + 1, nesting + 1, false)
      
      followingChars[nesting] = strIdx:getValue(idx)
      return outIdx, followingChars
    end
  end 
  
  local outIdx, followingChars = consumeChar(idx + 1, 2, false)
  
  followingChars[1] = boundaryMarker
  return strIdx:withIndex(outIdx), table.concat(followingChars)
end) * "String"



local lateinitRepo = {}
local lateinitNames = {}

-- Permit circular references using a promise stored in the 'lateinitNames' table
local function lateinit(childPatternName)
  lateinitNames[childPatternName] = true
  local childPattern
  
  return pattern(function(_, strIdx)
    if not childPattern then
      childPattern = lateinitRepo[childPatternName]
    end
    
    return childPattern(strIdx)
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
  maybemany = maybemany,
  
  -- Terminators
  Number = Number,
  Name = Name,
  String = String,
  
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
	kw_paren_close = kw ")",
	kw_brace_close = kw "}",
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
	kw_comma = kw ",",
	kw_colon = kw ":",
	kw_minus = kw "-",
	kw_times = kw "*",
	kw_caret = kw "^",
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