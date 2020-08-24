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
            / d"default"{ "[", Name, expr, "]", c{ ",", parlist } }
            / d{ Name, c{ ",", parlist }};
    
    funcbody = d{ "(", c{ parlist }, ")", block, "end" };
    
    function_ = d{ "function", funcbody };
    
    lambda_function = d"lambda"{ "fn", "(", c{ parlist }, ")", cm{ block }, c{ expr }, "end" };
    
    choose_expr = d"choose"{ expr, "choose", exprlist, "else", exprlist };
    
    contract_predicate = d"contract_pred"{ Name, ":", (Name / function_ / lambda_function) }
    
    contract_expr = d"contract"{ "contract", Name, "(", cm{ contract_predicate 
                                                          / Name
                                                          / d"optional"{ "[", contract_predicate / Name, "]" }}, ")" }
    
    expr_terminator = null
                    / "nil"
                    / "false"
                    / "true" 
                    / "..."
                    / tableconstructor
                    / function_
                    / lambda_function
                    / d{ unop, expr }
                    / String
                    / Number
                    / prefixexpr;
    
    expr = d{ expr_terminator, cm{ binop, expr_terminator }};
    
    field = d{ "[", expr, "]", "=", expr }
          / d{ Name, "=", expr }
          / expr;
    
    fieldlist = d{ field, cm{ fieldsep, field }, c{ fieldsep }};
    
    tableconstructor = d{ "{", c{ fieldlist }, "}" };
    
    exprlist = d{ expr, cm { ",", expr }};
    
    args = d{ d{ "(", c{ exprlist }, ")" }
               / tableconstructor
               / String };
    
    var_suffix = d{ "[", expr, "]" }
               / d{ ".", Name };
    
    functioncall_suffix = d{ c{ ":", Name }, args };
    
    var_right_recur = d{ var_suffix, c{ var_right_recur }}
                    / d{ functioncall_suffix, val_right_recur };
    
    var = d{ Name, cm{ var_right_recur }};
    
    functioncall_right_recur = d{ var_suffix, functioncall_right_recur }
                             / d{ functioncall_suffix, c{ functioncall_right_recur }};
    
    functioncall = d{ Name, functioncall_right_recur };
    
    prefixexpr_right_recur = d{ var_suffix, c{ prefixexpr_right_recur }}
                           / d{ functioncall_suffix, c{ prefixexpr_right_recur }};
    
    prefixexpr = functioncall
               / var
               / d{ "(", expr, ")", cm{ var_suffix / functioncall_suffix }};
    
    varlist = d{ var, cm{ ",", var }};
    
    funcname = d{ Name, cm{ ".", Name }, c{ ":", Name }};
    
    retstat = d{ "return", c{ exprlist }, c{ ";" }};
    
    label = d{ "::", Name, "::" };
    
    do_statement = d{ "do", block, "end" };
    
    goto_statement = d{ "goto", Name };
    
    while_statement = d{ "while", expr, "do", block, "end" };
    
    repeat_statement = d{ "repeat", block, "until", expr };
    
    if_statement = d{ "if", expr, "then", 
                        block,
                      cm{ "elseif", expr, "then", 
                        block },
                      c{ "else",
                        block },
                      "end" };
    
    for_declaration = d{ Name, "=", expr, ",", expr, c{ ",", expr }};
    
    foreach_declaration = d{ namelist, "in", exprlist };
    
    for_loop = d{ "for", for_declaration / foreach_declaration, "do", block, "end" };
    
    function_declaration = d{ "function", funcname, funcbody };
    
    local_declaration = d{ "local", d{ "function", Name, funcbody }
                                    / d{ namelist, c{ "=", exprlist }}};
    
    assignment = d{ varlist, "=", exprlist };
    
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
              / d"expr_stmt"{ functioncall / assignment };
    
    chunk = d{ cm{ statement }, c{ retstat }};
    
    block = chunk;
    
    grammar = block;
  }

  return grammar
end
