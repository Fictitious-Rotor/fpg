-- Takes in a stream of tokens, which have been enriched and validated by the parser.
-- Recursively evaluates expressions & statements until code is fully evaluated.
-- Returns final result.


-- I want to load my normal lua parser & evaluator
-- I will then copy all the standard lua tokens across into the output list.
-- However, I will also look out for any syntax which has been labeled as belonging to elu
-- I will expand this syntax out into normal lua code, which will then be added to the output list

-- Once I'm done, I'll shove the output tokens through the lua parser and then through the lua evaluator.

local view = require "fpg.Utils.debugview"

local evaluator = {}

function evaluator.evaluate(tokens)
  print("What we're working with", view(tokens),"\n\n")
  return tokens
end

return evaluator