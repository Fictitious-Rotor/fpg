local parse = require("parser").parseString

local tests = {
  "if true then print('true!') else print 'false :(' end return true",
  "print('true!') return true",
[[
kw = function(str)
  return setmetatable(toChars(str), { 
    __call = kwCompare, 
    __add = patternIntersection, 
    __div = patternUnion,
    __len = function() return #str end,
    __tostring = function() return str end
  })
end
return true
]],
[[
function kw(str) return str end

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
return true
]],
[[
local strIdx = {}
function strIdx:getValue() return 'no' end
while strIdx:getValue(idx) == ' ' do 
  idx = idx + 1
end
return true
]],
[[
local strIdx = { getValue = function() return ' ' end }, idx = 1

while strIdx:getValue(idx) == ' ' do 
  idx = idx + 1
end
return true
]],
[[
local stridx = { getValue = function() return ' ' end }
local idx = 1

return stridx:getValue(idx) == ' '
]],
[[
return(function()returntrueend)()
]],
[[
returnVariable = 4
return true
]],
[[
local function deepcopy(orig) 
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
    else
        copy = orig
    end
    return copy
end
return true
]],
[[
local rawiter = function(obj, param, state)
    assert(obj ~= nil, "invalid iterator")
    if type(obj) == "table" then
        local mt = getmetatable(obj);
        if mt ~= nil then
            if mt == iterator_mt then
                return obj.gen, obj.param, obj.state
            elseif mt.__ipairs ~= nil then
                return mt.__ipairs(obj)
            elseif mt.__pairs ~= nil then
                return mt.__pairs(obj)
            end
        end
        if #obj > 0 then
            
            return ipairs(obj)
        else
            
            return map_gen, obj, nil
        end
    elseif (type(obj) == "function") then
        return obj, param, state
    elseif (type(obj) == "string") then
        if #obj == 0 then
            return nil_gen, nil, nil
        end
        return string_gen, obj, 0
    end
    error(string.format('object %s of type "%s" is not iterable',
          obj, type(obj)))
end
return true
]],
[[
local obj = true
if type(obj) == "table" then
  local mt = getmetatable(obj);
  if mt ~= nil then
    if mt == iterator_mt then
      return obj.gen, obj.param, obj.state
    elseif mt.__ipairs ~= nil then
      return mt.__ipairs(obj)
    elseif mt.__pairs ~= nil then
      return mt.__pairs(obj)
    end
  end
  if #obj > 0 then
      
    return ipairs(obj)
  else
      
    return map_gen, obj, nil
  end
elseif (type(obj) == "function") then
  return obj, param, state
elseif (type(obj) == "string") then
  if #obj == 0 then
      return nil_gen, nil, nil
  end
  return string_gen, obj, 0
end
return true
]],
[[
local mt = getmetatable(obj);

if mt ~= nil then
  if mt == iterator_mt then
    return obj.gen, obj.param, obj.state
  elseif mt.__ipairs ~= nil then
    return mt.__ipairs(obj)
  elseif mt.__pairs ~= nil then
    return mt.__pairs(obj)
  end
end

return true
]],
[[
local obj = {}
local map_gen = true
if #obj > 0 then
    
  return ipairs(obj)
else
    
  return map_gen, obj, nil
end
]],
[[
local obj = true
if type(obj) == "table" then
  return true
elseif (type(obj) == "function") then
  return obj, param, state
elseif (type(obj) == "string") then
  if #obj == 0 then
      return nil_gen, nil, nil
  end
  return string_gen, obj, 0
end
return true
]]
}

local whitelist = {
  false,
  false,
  false,
  false,
  false,
  false,
  false,
  false,
  false,
  false,
  true,
  true,
  true,
  true,
  true,
}

for no, toParse in ipairs(tests) do
  if whitelist[no] then
    print("|=============#", "Running:", toParse)
    local parsed = parse(toParse)
    print("|=============#", "it returns:", parsed)
    local loaded = load(parsed)
    print("|=============#", "Function succeeds?", loaded() == true)
  end
end