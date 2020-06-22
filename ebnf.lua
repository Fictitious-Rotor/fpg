-- Entrypoint
block =(lateinit("chunk"))
      * "block"
--
unop =(kw_minus
     / kw_not
     / kw_hash)
     * "unop"
--
binop =(kw_plus
      / kw_minus * "ignore"
      / kw_times * "ignore"
      / kw_divide * "ignore"
      / kw_caret * "ignore"
      / kw_modulo * "ignore"
      / kw_concat * "ignore"
      / kw_lt * "ignore"
      / kw_lte * "ignore"
      / kw_gt * "ignore"
      / kw_gte * "ignore"
      / kw_are_equal * "ignore"
      / kw_not_equal * "ignore"
      / kw_and * "ignore"
      / kw_or * "ignore")
      * "binop"
--
fieldsep =(kw_comma
         / kw_semicolon)
         * "fieldsep"
--
Name =(checkNotKeywordThenPack(Whitespace + Alphabetic + maybemany(Alphanumeric)))
     * "Name"

-- Introduce support for [===[ [==[ [=[ [[]] ]=] ]==] ]===]
String = packString(Whitespace + 
                    ((kw_speech_mark + maybemany((kw_backslash + kw_speech_mark) * "ignore" / notPattern(kw_speech_mark) * "ignore") * "ignore" + kw_speech_mark) * 'String ""'
                     / (kw_quote + maybemany((kw_backslash + kw_quote) * "ignore" / notPattern(kw_quote) * "ignore") * "ignore" + kw_quote) * "String ''"
                     / (kw_multiline_open + maybemany(notPattern(kw_multiline_close) * "ignore") * "ignore" + kw_multiline_close) * "String [[]]") * "String")
       * "String"
--

Number = packString(Whitespace + many(Digit) + maybe(kw_dot + many(Digit)))
       * "Number"
--
namelist =(Name + maybemany(kw_comma + Name))
         * "namelist"
--
parlist =((namelist + maybe(kw_comma + kw_ellipsis))
        / kw_ellipsis)
        * "parlist"
--
funcbody =(kw_paren_open + maybe(parlist) + kw_paren_close + block + kw_end)
         * "funcbody"
--
function_ =(kw_function + funcbody)
          * "function_"
--
expr_terminator =(kw_nil
                / kw_false
                / kw_true
                / kw_ellipsis
                / lateinit("tableconstructor")
                / function_
                / (unop + lateinit("expr")))
                / String
                / Number
                / lateinit("prefixexpr")
                * "expr_terminator"
--
expr_right_recur = (binop + expr_terminator + maybe(lateinit("expr_right_recur")))
                * "expr_right_recur"
--
expr = (expr_terminator + maybe(expr_right_recur))
     * "expr"
--
field =((kw_bracket_open + expr + kw_bracket_close + kw_equals + expr) * "dynamic field key assignment"
      / (Name + kw_equals + expr) * "static field key assignment"
      / expr)
      * "field"
--
fieldlist =(field + maybemany(fieldsep + field) + maybe(fieldsep))
          * "fieldlist"
--
tableconstructor =(kw_brace_open + maybe(fieldlist) + kw_brace_close)
                 * "tableconstructor"
--
explist =(expr + maybemany(kw_comma + expr))
        * "explist"
--
args =((kw_paren_open + maybe(explist) + kw_paren_close) * "argument list"
     / tableconstructor
     / String)
     * "args"
--

-- Suffixes
var_suffix =((kw_bracket_open + expr + kw_bracket_close) * "bracket index"
           / (kw_dot + Name) * "dot index")
           * "var_suffix"
--
functioncall_suffix =(maybe(kw_colon + Name) + args)
                    * "functioncall_suffix"
--

-- Variables
var_right_recur =((var_suffix + maybe(lateinit("var_right_recur"))) / (functioncall_suffix + lateinit("var_right_recur")))
                * "var_right_recur"
--
var =(Name + maybemany(var_right_recur))
    * "var"
--

-- Functioncall
functioncall_right_recur =((var_suffix + lateinit("functioncall_right_recur")) / (functioncall_suffix + maybe(lateinit("functioncall_right_recur"))))
                         * "functioncall_right_recur"
--
functioncall =(Name + functioncall_right_recur)
             * "functioncall"
--

-- Prefix expression
prefixexpr_right_recur =((var_suffix + maybe(lateinit("prefixexpr_right_recur")))
                       / (functioncall_suffix + maybe(lateinit("prefixexpr_right_recur"))))
                       * "prefixexpr_right_recur"
--
prefixexpr =(functioncall -- Var is more permissive than functioncall, so functioncall is checked first.
           / var
           / (kw_paren_open + expr + kw_paren_close + maybemany(var_suffix / functioncall_suffix)))
           * "prefixexpr"
--

varlist =(var + maybemany(kw_comma + var))
        * "varlist"
--
funcname =(Name + maybemany(kw_dot + Name) + maybe(kw_colon + Name))
         * "funcname"
--
retstat =(kw_return + maybe(explist) + maybe(kw_semicolon))
        * "retstat"
--
label =(kw_label_delim + Name + kw_label_delim)
      * "label"
--

-- Statements

do_statement =(kw_do + block + kw_end)
             * "do statement"
--
goto_statement =(kw_goto + Name)
               * "goto"
--
while_statement =(kw_while + expr + kw_do + block + kw_end)
                * "while statement"
--
repeat_statement =(kw_repeat + block + kw_until + expr)
                 * "repeat statement"
--
if_statement =(kw_if + expr + kw_then + block + maybemany(kw_elseif + expr + kw_then + block) + maybe(kw_else + block) + kw_end)
             * "if statement"
--
for_loop =(kw_for + Name + kw_equals + expr + kw_comma + expr + maybe(kw_comma + expr) + kw_do + block + kw_end)
         * "for loop"
--
foreach_loop =(kw_for + namelist + kw_in + explist + kw_do + block + kw_end)
             * "foreach loop"
--
function_declaration =(kw_function + funcname + funcbody)
                     * "function declaration"
--
local_function_declaration =(kw_local + kw_function + Name + funcbody)
                           * "local function declaration"
--
local_declaration =(kw_local + namelist + maybe(kw_equals + explist))
                  * "local declaration"
--
global_assignment =(varlist + kw_equals + explist)
                  * "global_assignment"
--

statement =(kw_semicolon
          / do_statement
          / goto_statement
          / while_statement
          / repeat_statement
          / if_statement
          / for_loop
          / foreach_loop
          / function_declaration
          / local_function_declaration
          / local_declaration
          / label
          / functioncall
          / global_assignment)
          * "statement"

chunk =(maybemany(statement) + maybe(retstat))
      * "chunk"

initialiseLateInitRepo()

-- New syntax to introduce could use this?
-- lambdabody =(maybe(maybe(stat + maybe(kw_semicolon)) + returnWrapper(expr)))

-- Entrypoint is 'block'
