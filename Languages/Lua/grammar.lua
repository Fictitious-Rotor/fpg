return function(_ENV)
  local definitions = g{
    unop = null
         / "-"
         / "not"
         / "#";
  
    binop = null
          / "+"
          / "-"
          / "*"
          / "/"
          / "^"
          / "%"
          / ".."
          / "<"
          / "<="
          / ">"
          / ">="
          / "=="
          / "~="
          / "and"
          / "or";
  
    fieldsep = null / "," / ";";
    
    namelist = d{ Name, cm{ ",", Name }};
    
    parlist = null
            / "..."
            / d{ Name, c{ ",", parlist }};
    
    funcbody = d{ "(", c{ parlist }, ")", block, "end" };
    
    function_ = d"function"{ "function", funcbody };
    
    expr_terminator = null
                    / "nil"
                    / "false"
                    / "true" 
                    / "..."
                    / tableconstructor
                    / function_
                    / d{ unop, expr }
                    / String
                    / Number
                    / prefixexpr;
    
    expr = d"expr"{ expr_terminator, cm{ binop, expr_terminator }};
    
    field = d{ "[", expr, "]", "=", expr }
          / d{ Name, "=", expr }
          / expr;
    
    fieldlist = d{ field, cm{ fieldsep, field }, c{ fieldsep }};
    
    tableconstructor = d"table"{ "{", c{ fieldlist }, "}" };
    
    exprlist = d{ expr, cm { ",", expr }};
    
    args = d"args"{ d{ "(", c{ exprlist }, ")" }
                  / tableconstructor
                  / String };
    
    var_suffix = d{ "[", expr, "]" }
               / d{ ".", Name };
    
    functioncall_suffix = d{ c{ ":", Name }, args };
    
    var_right_recur = d{ var_suffix, c{ var_right_recur }}
                    / d{ functioncall_suffix, val_right_recur };
    
    var = d"var"{ Name, cm{ var_right_recur }};
    
    functioncall_right_recur = d{ var_suffix, functioncall_right_recur }
                             / d{ functioncall_suffix, c{ functioncall_right_recur }};
    
    functioncall = d"functioncall"{ Name, functioncall_right_recur };
    
    prefixexpr_right_recur = d{ var_suffix, c{ prefixexpr_right_recur }}
                           / d{ functioncall_suffix, c{ prefixexpr_right_recur }};
    
    prefixexpr = functioncall
               / var
               / d{ "(", expr, ")", cm{ var_suffix / functioncall_suffix }};
    
    varlist = d{ var, cm{ ",", var }};
    
    funcname = d{ Name, cm{ ".", Name }, c{ ":", Name }};
    
    retstat = d{ "return", c{ exprlist }, c{ ";" }};
    
    label = d"label"{ "::", Name, "::" };
    
    do_statement = d"do_stmt"{ "do", block, "end" };
    
    goto_statement = d"goto_stmt"{ "goto", Name };
    
    while_statement = d"while_stmt"{ "while", expr, "do", block, "end" };
    
    repeat_statement = d"repeat_stmt"{ "repeat", block, "until", expr };
    
    if_statement = d"if_stmt"{ 
                      "if", expr, "then", 
                        block,
                      cm"elseif"{ "elseif", expr, "then", 
                        block },
                      c"else"{ "else",
                        block },
                      "end" };
    
    for_declaration = d"foridx"{ Name, "=", expr, ",", expr, c{ ",", expr }};
    
    foreach_declaration = d"foreach"{ namelist, "in", exprlist };
    
    for_loop = d"for_loop"{ "for", for_declaration / foreach_declaration, "do", block, "end" };
    
    function_declaration = d"function"{ "function", funcname, funcbody };
    
    local_declaration = d"local"{ "local", d"function"{ "function", Name, funcbody }
                                           / d"var"{ namelist, c{ "=", exprlist }}};
    
    global_assignment = d"global"{ varlist, "=", exprlist };
    
    statement = null
              / ";"
              / "break"
              / do_statement
              / goto_statement
              / while_statement
              / repeat_statement
              / if_statement
              / for_loop
              / function_declaration
              / local_declaration
              / label
              / functioncall
              / global_assignment;
    
    chunk = d{ cm{ statement }, c{ retstat }};
    
    block = chunk;
    
    grammar = block;
  }

  return grammar
end
