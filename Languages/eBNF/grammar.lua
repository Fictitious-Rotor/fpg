return function(_ENV)
  local definitions = g{
    optional = d"optional"{ "[", def, "]" };
  
    repeated = d"repeated"{ "{", def, "}" };
    
    group = d"group"{ "(", def, ")" };
    
    def_terminator = null
                   / Identifier
                   / String
                   / optional
                   / repeated
                   / group;
    
    alternation_right_recur = d"alternation"{ "|", def_terminator, c{alternation_right_recur} };
    
    concatenation_right_recur = d{ ",", def_terminator, c{concatenation_right_recur} };
    
    def = d"definition"{ d"concatenation"{def_terminator, concatenation_right_recur}
                       / d { def_terminator, c{ alternation_right_recur } }};
    
    rule = d"rule"{ Identifier, "=", def, ";" };
    
    grammar = d"grammar"{ cm{rule} };
  }

  return grammar
end