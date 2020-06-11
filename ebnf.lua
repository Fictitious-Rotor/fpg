local parser = require "parser"
local Number, Name, String, lateinit, initialiseLateInitRepo, kws = Number, Name, String, lateinit, initialiseLateInitRepo, kws
print(Number, Name, String, lateinit, initialiseLateInitRepo, kws)
for k, v in pairs(kws) do _G[k] = v end -- import kws.*

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

exp_terminator =(kw_nil
               / kw_false
               / kw_true
               / Number
               / String
               / kw_ellipsis
               / lateinit("function_")
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

parlist =((lateinit("namelist") + maybe(kw_comma + kw_ellipsis))
        / kw_ellipsis)
        * "parlist"

funcbody =(kw_paren_open + maybe(parlist) + kw_paren_close + lateinit("block") + kw_end)
         * "funcbody"

function_ =(kw_function + funcbody)
          * "function_"

args =((kw_paren_open + maybe(lateinit("explist")) + kw_paren_close)
     / tableconstructor
     / String)
     * "args"

prefixexp =(((lateinit("var"))
            / (lateinit("functioncall"))
            / ((kw_paren_open + exp_ + kw_paren_close)))
          + maybe(prefixexp))
          * "prefixexp"

functioncall = (maybe(kw_colon + Name) + args) 
             * "functioncall"

explist =(maybemany(exp_ + kw_comma) + exp_)
        * "explist"

namelist =(Name
         / maybemany(kw_comma + Name))
         * "namelist"

var =((Name)
    / (kw_bracket_open + exp_ + kw_bracket_close) 
    / (kw_dot + Name))
    * "var"

varlist =(var + maybemany(kw_comma + var))
        * "varlist"

funcname =(Name + maybemany(kw_dot + Name) + maybe(kw_colon + Name))
         * "funcname"

laststat =((kw_return + maybe(explist))
         / kw_break)
         * "laststat"
         
block =(lateinit("chunk"))
      * "block"
     
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



if_statement = (kw_if + exp_ + kw_then + block --[[ + maybemany(kw_elseif + exp_ + kw_then + block) + maybe(kw_else + block) + kw_end]] )
             * "if_statement"


local idx, tbl = if_statement(1)
print("Index:", idx, "tbl:", view(tbl))


local idx, tbl = Name(13)
print("Attempting to pull var")
print("Index:", idx, "tbl:", view(tbl))