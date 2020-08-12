return function(_ENV)
  local definitions = g {
    block = d { 
      "if", Identifier, "then", 
        Identifier, "(", String, ")", 
      r(0)("elseif"){ "elseif", 
        Identifier, "(", String, ")" }, 
      d "else" { "else", 
        Identifier, "(", String, ")" }, 
      "end" }
          / d { 
      "while", "true", "do", 
        Identifier, "(", r(0){ String, "," }, ")", 
      "end" }
  }

  return block
end
