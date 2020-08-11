return function(_ENV)
  local definitions = l {
    block = d { "if", Identifier, "then", Identifier, "(", String, ")", "end" }
  }

  return block
end
