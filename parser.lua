view = require "debugview"

local eluCode = "if true then print(true) else print(nil) end" --"local myString = \"This is a string\" for pos = 1, 10 do if pos % 2 == 0 then print(myString, pos) end end"

local function toChars(str)
  local out = {}
  
  for c in str:gmatch(".") do
    out[#out + 1] = c
  end
  
  return out
end

local eluChars = toChars(eluCode)

local patternIntersection, patternUnion
local kwCompare

local pattern, kw -- Declared here as they are referenced in the higher order patterns

local function getChar(idx)
  return eluChars[idx]
end

local function skipSpaces(idx)
  while getChar(idx) == ' ' do
    idx = idx + 1
  end
  return idx
end

local function skipComments(idx)
  if (getChar(idx) == '-') and (getChar(idx + 1) == '-') then
    local multiline = getChar(idx + 2) == '[' and getChar(idx + 3) == '['
    local pos = idx + (multiline and 4 or 2)
    
    if multiline then
      repeat
        pos = pos + 1
      until (getChar(pos) == ']' and eluChars[pos - 1] == ']')
    else
      while not (getChar(pos) == '\n') do
        pos = pos + 1
      end
    end
    
    return pos + 1
  else
    return idx
  end
end

--[=====================]--
--|Higher Order Patterns|--------------------------------------------------------------------------------------------------------------------
--[=====================]--

-- Advance pointer if contents of table matches eluChars at idx
kwCompare = function(tbl, idx)
  local pos = skipSpaces(idx)

  for _, c in ipairs(tbl) do  
    if c ~= getChar(pos) then
      return false
    end
    pos = pos + 1
  end
  
  return pos, tostring(tbl)
end

-- Intersection of two checks, returns either the index after both patterns, followed by a table of both patterns represented as strings or false
patternIntersection = function(left, right)
  return pattern(function(_, idx)
    local idxAfterLeft, leftOutput = left(idx)
    print("Intersection left pattern", left, "idxAfterLeft", idxAfterLeft, "produced", view(leftOutput))
    
    if idxAfterLeft then
      local outTable = type(leftOutput) == "table" and leftOutput or { leftOutput }
      local idxAfterRight, rightOutput = right(idxAfterLeft)
      print("Intersection right pattern", right, "idxAfterRight", idxAfterRight, "produced", view(rightOutput))
      
      if idxAfterRight then
        outTable[#outTable + 1] = rightOutput
        
        return idxAfterRight, outTable
      end
    end
    
    return false
  end) * ("(" .. tostring(left) .. " + " .. tostring(right) .. ")")
end

-- Union of two checks, returns either left or right
patternUnion = function(left, right)
  return pattern(function(_, idx)
    local idxAfterLeft, leftOutput = left(idx)
    
    if idxAfterLeft then
      return idxAfterLeft, leftOutput 
    end
    
    local idxAfterRight, rightOutput = right(idx)
    
    return idxAfterRight, rightOutput
  end) * ("(" .. tostring(left) .. " / " .. tostring(right) .. ")")
end

local function maybe(childPattern)
  return pattern(function(_, idx)
    local idxAfterChildPattern, childPatternOutput = childPattern(idx)
    
    if idxAfterChildPattern then
      return idxAfterChildPattern, childPatternOutput
    else
      return idx, ""
    end
  end) * ("maybe (" .. tostring(childPattern) .. ")")
end 

local function many(childPattern)
  return pattern(function(_, idx)
    local function matchChildPattern(idx, nesting)
      local idxAfterChildPattern, childPatternOutput = childPattern(idx)
      
      if idxAfterChildPattern then
        local idxAfterRecursion, recursionOutput = matchChildPattern(idxAfterChildPattern, nesting + 1)
        
        if idxAfterRecursion then
          recursionOutput[nesting] = childPatternOutput
          return idxAfterRecursion, recursionOutput
        else
          return idxAfterChildPattern, { [nesting] = childPatternOutput }
        end
      end
      
      return false
    end
    
    return matchChildPattern(idx, 1)
  end) * ("many (" .. tostring(childPattern) .. ")")
end

local function maybemany(fn)
  return maybe(many(fn))
end

--[==========]--
--|Metatables|-------------------------------------------------------------------------------------------------------------------------------
--[==========]--

--- The value of tostring may not be clear when the pattern is initially constructed. This function lets you bind tostring at a later point.
local function attachLabel(tbl, name)
  getmetatable(tbl).__tostring = function() return name end
  return tbl
end

pattern = function(fn)
  return setmetatable({}, { 
    __add = patternIntersection, 
    __div = patternUnion, 
    __call = fn, 
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
--|Terminator Patterns|----------------------------------------------------------------------------------------------------------------------
--[===================]--

local Number = pattern(function(_, idx)
  local idx = skipSpaces(idx)
  
  local function consumeChar(idx, nesting)
    local number = (getChar(idx) or ""):match("%d")
    
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
  
  return outIdx or idx, (result and table.concat(result))
end) * "Number"



local Name = pattern(function(_, idx)
  local idx = skipSpaces(idx)

  local function consumeChar(idx, nesting)
    local matchedChar = (getChar(idx) or ""):match("[%w_]")
    
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
  
  local leadingChar = (getChar(idx) or ""):match("%a")
  
  if not leadingChar then 
    return false
  else
    local outIdx, followingChars = consumeChar(idx + 1, 2)
        
    if outIdx then 
      followingChars[1] = leadingChar
      return outIdx, table.concat(followingChars)
    else
      return idx + 1, leadingChar
    end
  end
end) * "Name"



local String = pattern(function(_, idx)
  local idx = skipSpaces(idx)
  local boundaryMarker = getChar(idx)
  
  if not (boundaryMarker == '"' or boundaryMarker == "'") then
    return false
  end

  function consumeChar(idx, nesting, escaped)
    if not escaped then
      local curChar = getChar(idx)
      
      if not curChar then
        error("Unterminated string at position:", idx)
      elseif curChar == boundaryMarker then
        return idx + 1, { [nesting] = curChar }
      else
        local escapeNext = curChar == "\\"
        local outIdx, followingChars = consumeChar(idx + 1, nesting + 1, escapeNext)
        
        followingChars[nesting] = getChar(idx)
        
        return outIdx, followingChars
      end
    else
      local outIdx, followingChars = consumeChar(idx + 1, nesting + 1, false)
      
      followingChars[nesting] = getChar(idx)
      return outIdx, followingChars
    end
  end 
  
  local outIdx, followingChars = consumeChar(idx + 1, 2, false)
  
  followingChars[1] = getChar(idx)
  return outIdx, table.concat(followingChars)
end) * "String"



local lateinitRepo = {}
local lateinitNames = {}

-- Permit circular references using a promise stored in the 'lateinitNames' table
local function lateinit(childPatternName)
  lateinitNames[childPatternName] = true
  local childPattern
  
  return pattern(function(_, idx)
    if not childPattern then
      childPattern = lateinitRepo[childPatternName]
    end
    
    return childPattern(idx)
  end) * childPatternName
end

-- Initialise all promised references by drawing them from the provided table
local function initialiseLateInitRepo(tbl)
  for name, _ in pairs(lateinitNames) do
    lateinitRepo[name] = tbl[name]
  end
end



local kws = {
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

return { Number, Name, String, lateinit, initialiseLateInitRepo, kws }