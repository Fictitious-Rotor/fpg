return function(_ENV)
  local definitions = l {
    block = d { "if", Identifier, "then", Identifier, "(", String, ")", "end" }
          / d { "while", "true", "do", Identifier, "(", r(0){ String, "," }, ")", "end" }
  }

  return block
end
