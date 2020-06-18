require "parser" ()

unop =(kw_minus
     / kw_not
     / kw_length)
     * "unop"

binop =(kw_plus
      / kw_minus
      / kw_times
      / kw_divide
      / kw_caret
      / kw_modulo
      / kw_concat
      / kw_lt
      / kw_lte
      / kw_gt
      / kw_gte
      / kw_are_equal
      / kw_not_equal
      / kw_and
      / kw_or)
      * "binop"

fieldsep =(kw_comma
         / kw_semicolon)
         * "fieldsep"

block =(lateinit("chunk"))
      * "block"
      
Name =(checkNotKeywordThenPack(Whitespace + Alphabetic + maybemany(Alphanumeric)))
     * "Name"

-- Introduce support for [===[ [==[ [=[ [[]] ]=] ]==] ]===]
String = packString(Whitespace + 
                    ((kw_speech_mark + maybemany((kw_backslash + kw_speech_mark) / notPattern(kw_speech_mark)) + kw_speech_mark)
                     / (kw_quote + maybemany((kw_backslash + kw_quote) / notPattern(kw_quote)) + kw_quote)
                     / (kw_multiline_open + maybemany(notPattern(kw_multiline_close)) + kw_multiline_close)))
       * "String"

Number =(Whitespace + many(Digit) + maybe(kw_dot + many(Digit)))
       * "Number"

namelist =(Name
         / maybemany(kw_comma + Name))
         * "namelist"

parlist =((namelist + maybe(kw_comma + kw_ellipsis))
        / kw_ellipsis)
        * "parlist"

funcbody =(kw_paren_open + maybe(parlist) + kw_paren_close + block + kw_end)
         * "funcbody"

function_ =(kw_function + funcbody)
          * "function_"

expr_terminator =(kw_nil
               / kw_false
               / kw_true
               / kw_ellipsis
               / lateinit("tableconstructor")
               / function_
               / (unop + lateinit("expr")))
               / String
               / Number
               / lateinit("prefixexp")
               * "expr_terminator"

expr_right_recur = (binop + expr_terminator + maybe(lateinit("expr_right_recur")))
                * "expr_right_recur"

expr = (expr_terminator + maybe(expr_right_recur))
     * "expr"

field =((kw_bracket_open + expr + kw_bracket_close + kw_equals + expr)
      / (Name + kw_equals + expr)
      / expr)
      * "field"

fieldlist =(field + maybemany(fieldsep + field) + maybe(fieldsep))
          * "fieldlist"

tableconstructor =(kw_brace_open + maybe(fieldlist) + kw_brace_close)
                 * "tableconstructor"

explist =(maybemany(expr + kw_comma) + expr)
        * "explist"

args =((kw_paren_open + maybe(explist) + kw_paren_close)
     / tableconstructor
     / String)
     * "args"

var =((Name)
    / (kw_bracket_open + expr + kw_bracket_close)
    / (kw_dot + Name))
    * "var"

expr_functioncall = (maybe(kw_colon + Name) + args) 
             * "expr_functioncall"

varorexp =((var)
         / (kw_paren_open + expr + kw_paren_close))
         * "varorexp"

prefixexp =((varorexp / expr_functioncall)
          + maybe(lateinit("prefixexp")))
          * "prefixexp"
          
prefixstat =((expr_functioncall + maybe(lateinit("prefixstat"))))
           / (varorexp + lateinit("prefixstat"))
           * "prefixstat"
          
stat_functioncall = (varorexp + prefixstat)
                  * "stat_functioncall"

varlist =(var + maybemany(kw_comma + var))
        * "varlist"

funcname =(Name + maybemany(kw_dot + Name) + maybe(kw_colon + Name))
         * "funcname"

laststat =((kw_return + maybe(explist))
         / kw_break)
         * "laststat"

stat =((varlist + kw_equals + explist)
     / stat_functioncall
     / (kw_do + block + kw_end)
     / (kw_while + expr + kw_do + block + kw_end)
     / (kw_repeat + block + kw_until + expr)
     / (kw_if + expr + kw_then + block + maybemany(kw_elseif + expr + kw_then + block) + maybe(kw_else + block) + kw_end)
     / (kw_for + Name + kw_equals + expr + kw_comma + expr + maybe(kw_comma + expr) + kw_do + block + kw_end)
     / (kw_for + namelist + kw_in + explist + kw_do + block + kw_end)
     / (kw_function + funcname + funcbody)
     / (kw_local + namelist + maybe(kw_equals + explist)))
     * "stat"

chunk =(maybemany(stat + maybe(kw_semicolon)) + maybe(laststat + maybe(kw_semicolon)))
      * "chunk"

-- New syntax to introduce could use this?
-- lambdabody =(maybe(maybe(stat + maybe(kw_semicolon)) + returnWrapper(expr)))

initialiseLateInitRepo(_G)

-------------------

local function parse(parser, str, startAt)
  local finalStrIdx, parsedStrs = parser(StringIndexer.new(toChars(str), startAt or 1), null)
  return parsedStrs
end

local tests = {
  { block, "if true then print('true!') else print 'false :(' end" },
  { expr, "true" },
  { Name, "if true then print('true!')", 13 },
  { block, "print('true!')" },
  --[=[{ block, [[
kw = function(str)
  return setmetatable(toChars(str), { 
    __call = kwCompare, 
    __add = patternIntersection, 
    __div = patternUnion,
    __len = function() return #str end,
    __tostring = function() return str end
  })
end ]] }, ]=]
  --[=[test { block, [[
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
} ]] }, test]=]
  { block, "while strIdx:getValue(idx) == ' ' do idx = idx + 1 end" },
  { block, 'keywordExports = { kw_do = kw "do", kw_if = kw "if", kw_in = kw "in", kw_or = kw "or", kw_end = kw "end", }' },
  { block, 'kw = function(str) return setmetatable(toChars(str), { __call = kwCompare, __add = patternIntersection, __div = patternUnion, __len = function() return #str end, __tostring = function() return str end }) end' }
}

for _, test in ipairs(tests) do
  local parser = test[1]
  local toParse = test[2]
  local startAt = test[3] or 1
  
  print("|=============#", "Running:", parser, "on:", toParse, "startingAt:", startAt)
  print("|=============#", "it returns:", parse(parser, toParse, startAt))
end
