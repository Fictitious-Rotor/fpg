require "parser" ()
local StringIndexer = require "StringIndexer"

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

Alphanumeric =(Digit 
             / Alphabetic)
             * "Alphanumeric"

Name =(Whitespace + Alphabetic + maybemany(Alphanumeric))
     * "Name"

String =((Whitespace + 
          ((kw_speech_mark + maybemany(EscapableChar) + kw_speech_mark)
         / (kw_quote + maybemany(EscapableChar) + kw_quote))))
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

exp_terminator =(kw_nil
               / kw_false
               / kw_true
               / Number
               / String
               / kw_ellipsis
               / function_
               / lateinit("prefixexp")
               / lateinit("tableconstructor")
               / (unop + lateinit("exp_")))
               * "exp_terminator"

exp_right_recur = (binop + exp_terminator + maybe(lateinit("exp_right_recur")))
                * "exp_right_recur"

exp_ = (exp_terminator + maybe(exp_right_recur))
     * "exp_"

field =((kw_bracket_open + exp_ + kw_bracket_close + kw_equals + exp_)
      / (Name + kw_equals + exp_)
      / exp_)
      * "field"

fieldlist =(field + maybemany(fieldsep + field) + maybe(fieldsep))
          * "fieldlist"

tableconstructor =(kw_brace_open + maybe(fieldlist) + kw_brace_close)
                 * "tableconstructor"

explist =(maybemany(exp_ + kw_comma) + exp_)
        * "explist"

args =((kw_paren_open + maybe(explist) + kw_paren_close)
     / tableconstructor
     / String)
     * "args"

var =((Name)
    / (kw_bracket_open + exp_ + kw_bracket_close) 
    / (kw_dot + Name))
    * "var"

functioncall = (maybe(kw_colon + Name) + args) 
             * "functioncall"
     
prefixexp =(((var)
            / (functioncall)
            / ((kw_paren_open + exp_ + kw_paren_close)))
          + maybe(prefixexp))
          * "prefixexp"

varlist =(var + maybemany(kw_comma + var))
        * "varlist"

funcname =(Name + maybemany(kw_dot + Name) + maybe(kw_colon + Name))
         * "funcname"

laststat =((kw_return + maybe(explist))
         / kw_break)
         * "laststat"

stat =((varlist + kw_equals + explist)
     / functioncall
     / (kw_do + block + kw_end)
     / (kw_while + exp_ + kw_do + block + kw_end)
     / (kw_repeat + block + kw_until + exp_)
     / (kw_if + exp_ + kw_then + block + maybemany(kw_elseif + exp_ + kw_then + block) + maybe(kw_else + block) + kw_end)
     / (kw_for + Name + kw_equals + exp_ + kw_comma + exp_ + maybe(kw_comma + exp_) + kw_do + block + kw_end)
     / (kw_for + namelist + kw_in + explist + kw_do + block + kw_end)
     / (kw_function + funcname + funcbody)
     / (kw_local + namelist + maybe(kw_equals + explist)))
     * "stat"

chunk =(maybemany(stat + maybe(kw_semicolon)) + maybe(laststat + maybe(kw_semicolon)))
      * "chunk"

initialiseLateInitRepo(_G)

-------------------

local function parse(parser, str, startAt)
  local finalStrIdx, parsedStrs = parser(StringIndexer.new(toChars(str), startAt or 1), null)
  return parsedStrs
end


if_statement = (kw_if + exp_ + kw_then + block --[[ + maybemany(kw_elseif + exp_ + kw_then + block) + maybe(kw_else + block) + kw_end]] )
             * "if_statement"

local tests = { 
  { if_statement, "if true then print('true!') else print 'false :(' end" },
  --{ exp_, "true" },
  --{ Name, "if true then print('true!')", 13 }
}

for _, test in ipairs(tests) do
  local parser = test[1]
  local toParse = test[2]
  local startAt = test[3] or 1
  
  print("|==========|", "Running:", parser, "on:", toParse, "startingAt:", startAt, "it returns:", parse(parser, toParse, startAt))
end