# eLu - Extended Lua

This project provides a pure lua AST parser that consumes a string and produces a string.
It uses combinator parsers to create a representation of eBNF using lua's tables & metamethods.

To add your own syntax to lua, load the stock eBNF representation of lua (found at ebnf.lua) and add some new eBNF definitions to represent the desired syntax.
You could, for example do the following:
```
require "ebnf" 

local kw_fn = userKw("fn", "function")
local kw_ret = userKw("ret", "return")

-- Add more keywords to the register
keywords:add {
  kw_fn = kw_fn,
  kw_ret = kw_ret
}

my_custom_definiton =(kw_fn + kw_paren_open + args + kw_paren_close + maybemany(stat + kw_semicolon) + maybe(kw_ret + expr + maybe(kw_semicolon)))

functioncall_default = functioncall
functioncall =(functioncall_default
             / my_custom_definiton)
             * "functioncall"
```

The representation used by eLu differs from the standard in the following ways:
| Usage           | Standard notation | eLu notation             |
|-----------------|-------------------|--------------------------|
| Definition      | =                 | =                        |
| Concatenation   | ,                 | +                        |
| Termination     | ;                 | \<Not used>              |
| Alternation     | \|                | /                        |
| Optional        | [ ... ]           | maybe(...)               |
| Zero or more    | { ... }           | maybemany(...)           |
| One or more     | ... { ... }       | many(...)                |
| Grouping        | ( ... )           | ( ... )                  |
| Terminal string | " ... "           | Found in terminators.lua |
| Terminal string | ' ... '           | Found in terminators.lua |
| Comment         | (* ... *)         | --[[ ... ]]              |
| Exception       | -                 | \<Not used>              |

Be cautious - BIDMAS ordering of operators is still in effect, so you'll need to use parenthesis to ensure that your patterns are interpreted correctly.

I have added labels to each pattern for the purposes of debugging the program. When placed between a pattern and a string, the `*` operator binds the string to the `__tostring` metamethod of the pattern.

Be aware that you can nest as many patterns within one another as necessary. An example of this in `ebnf.lua` would be:
```
prefixexp =((varorexp / expr_functioncall)
          + maybe(lateinit("prefixexp")))
          * "prefixexp"
```

Which would map to equivalent eBNF
```
prefixexp = varorexp, [prefixexp]
          | expr_functioncall, [prefixexp]
```
