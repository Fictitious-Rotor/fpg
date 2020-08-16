return function(_ENV)
  local definitions = g {
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
    
    namelist = d { Identifier, r(0){ ",", Identifier } };
  }

  return binop
end
