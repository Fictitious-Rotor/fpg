local parse = require("parser").parseString

local tests = {
  {"if true then print('true!') else print 'false :(' end ", true},
  {"  print('true!')", true},
{[[
kw = function(str)
  return setmetatable(toChars(str), { 
    __call = kwCompare, 
    __add = patternIntersection, 
    __div = patternUnion,
    __len = function() return #str end,
    __tostring = function() return str end
  })
end
]], true},
{[[
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
]], true},
{[[
local strIdx = {}
function strIdx:getValue() return 'no' end
while strIdx:getValue(idx) == ' ' do 
  idx = idx + 1
end
]], true},
{[[
local strIdx, idx = { getValue = function() return ' ' end }, 1

while strIdx:getValue(idx) == ' ' do 
  idx = idx + 1
end
]], true},
{[[
local stridx = { getValue = function() return ' ' end }
local idx = 1

return stridx:getValue(idx) == ' '
]], true},
{[[
return(function()returntrueend)()
]], true},
{[[
return(function()return true end)()
]], true},
{[[
returnVariable = 4
]], true},
{[[
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
]], true},
{[[
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
]], true},
{[[
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
]], true},
{[[
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
]], true},
{[[
local obj = {}
local map_gen = true
if #obj > 0 then
    
  return ipairs(obj)
else
    
  return map_gen, obj, nil
end
]], true},
{[[
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
]], true},
{[[
local nil_gen = true
]], true},
{[[
return nil_gen
]], true},
{[[local range = function(start, stop, step)
    assert(type(start) == "number", "start must be a number")

    if step == nil then
        if stop == nil then
            if start == 0 then
                return nil_gen, nil, nil
            end
            stop = start
            start = stop > 0 and 1 or -1
        end
        step = start <= stop and 1 or -1
    end

    assert(type(stop) == "number", "stop must be a number")
    assert(type(step) == "number", "step must be a number")
    assert(step ~= 0, "step must not be zero")

    if (step > 0) then
        return wrap(range_gen, {stop, step}, start - step)
    elseif (step < 0) then
        return wrap(range_rev_gen, {stop, step}, start - step)
    end
end]], true},
{[[local range = function(start, stop, step)
    assert(type(start) == "number", "start must be a number")

    if step == nil then
        if stop == nil then
            if start == 0 then
                return nil_gen, nil, nil
            end
            stop = start
            start = stop > 0 and 1 or -1
        end
        step = start <= stop and 1 or -1
    end
end]], true},
{[[if step == nil then
        if stop == nil then
            if start == 0 then
                return nil_gen, nil, nil
            end
            stop = start
            start = stop > 0 and 1 or -1
        end
        step = start <= stop and 1 or -1
    end]], true},
{[[step = start <= stop and 1 or -1]], true},
{[[
local filter1_gen = function(fun, gen_x, param_x, state_x, a)
    while true do
        if state_x == nil or fun(a) then break; end
        state_x, a = gen_x(param_x, state_x)
    end
    return state_x, a
end
]], true},
{[[
local filter1_gen = function(fun, gen_x, param_x, state_x, a)
    return state_x, a
end
]], true},
{[[while true do
        if state_x == nil or fun(a) then break; end
        state_x, a = gen_x(param_x, state_x)
    end]], true},
{[[if state_x == nil or fun(a) then break; end]], true}
}

local markerString = "#=============#"
local newlineMarkerString = "\n" .. markerString

local function toMarkedString(str)
  return newlineMarkerString .. str:gsub("\n", newlineMarkerString)
end

local parsed
local verbose = false

for _, test in ipairs(tests) do
  local toParse = test[1]
  local enabled = test[2]
  
  if not enabled then
    local function parseFn() parsed = parse(toParse) end
    local function errorHandler(errorMessage)
      print(markerString .. "WHEN RUNNING:", toMarkedString(toParse))
      print(markerString .. "IT FAILED WITH:", toMarkedString(errorMessage))
      print(markerString .. "=-=-=-=-=-=-=-=-=-=-=")
    end
  
    local success = xpcall(parseFn, errorHandler)
    
    if success then
      if parsed ~= toParse then
        print(markerString .. "WHEN RUNNING:", toMarkedString(toParse))
        print(markerString .. "THE PARSER FAILED TO MATCH THE INPUT, PRODUCING:", toMarkedString(parsed))
        print(markerString .. "=-=-=-=-=-=-=-=-=-=-=")
      elseif verbose then
        print(markerString .. "WHEN RUNNING:", toMarkedString(toParse))
        print(markerString .. "THE PARSER SUCCEEDED")
        print(markerString .. "=-=-=-=-=-=-=-=-=-=-=")
      end
    end
  end
end
