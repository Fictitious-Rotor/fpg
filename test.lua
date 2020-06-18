local parse = require "ebnf"

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
return(function()returntrueend)()
]],
[[
returnVariable = 4
return true
]]
}

for _, toParse in ipairs(tests) do
  print("|=============#", "Running:", toParse)
  local parsed = parse(toParse)
  print("|=============#", "it returns:", parsed)
  local loaded = load(parsed)
  print("|=============#", "Function succeeds?", loaded())
end
