# Formal Polyglot (fpg) - Write custom languages in pure Lua

## Summary

This project provides a generic framework for writing your own languages in pure lua.
Grammars are expressed in a manner similar to eBNF to improve readability.

This is achieved using combinator parsers & Lua metamethods.

## Usage

Example language implementations can be found in `Languages/`.
To create a new language, you will need:
 - A file for your language's token matchers (i.e. String, Comment, the keyword "while", the symbol "#").
 - Your language's grammar, written using the fpg eBNF notation
 - A bootstrap file to orchestrate the loading of your language.

The representation of eBNF that is used by eLu differs from the standard in the following ways:
| Usage           | Standard notation | fpg notation |
|-----------------|-------------------|--------------|
| Definition      | =                 | =            |
| Concatenation   | ,                 | ,            |
| Termination     | ;                 | ;            |
| Alternation     | \|                | /            |
| Optional        | [ ... ]           | c{ ... }     |
| Zero or more    | { ... }           | cm{ ... }    |
| One or more     | ... { ... }       | m{ ... }     |
| Grouping        | ( ... )           | d{ ... }     |
| Terminal string | " ... "           | " ... "      |
| Terminal string | ' ... '           | " ... "      |
| Comment         | (* ... *)         | --[[ ... ]]  |
| Exception       | -                 | \<Not used>  |

Due to limitations of Lua, concatenation can only be carried out within a definition.
For example the eBNF statement
```lua
handwear = "Red", "Glove";
```
Must be written as follows
```lua
handwear = d{ "Red, "Glove" };
```

Futhermore, alternations cannot begin on string literals, as that would involve overriding Lua's global string metatable.
Thusly, the eBNF statement
```lua
footwear = "Boots" / "Shoes";
```
Must be written as follows
```lua
footwear = null / "Boots" / "Shoes";
```

Nested definitions in the grammar are automatically inlined when ran against a token stream.
This means that grammar definitions can be complex without impacting the complexity of the output stream.
For example the eLu eBNF statement
```lua
gloves = d { d { "Thumb" / "Missing" }, 
             d { "Index" / "Missing" },
             d { "Middle" / "Missing" },
             d { "Ring" / "Missing" },
             d { "Pinky" / "Missing" }};
```
Would, when ran, return a token stream similar to this:
```lua
{
  name = "grammar",
  tokens = {
    { "type" = "Finger", "content" = "Thumb" },
    { "type" = "Finger", "content" = "Missing" },
    { "type" = "Finger", "content" = "Middle" },
    { "type" = "Finger", "content" = "Ring" },
    { "type" = "Finger", "content" = "Missing" }
  }
}
```

However, as nesting often simplifies evaluation, it can still be achieved by naming a definition.
This can be done as follows
```lua
gloves = d { d"Opposables"{ "Thumb" / "Missing" }, 
             d { "Index" / "Missing" },
             d { "Middle" / "Missing" },
             d"Expendables"{ d { "Ring" / "Missing" }, d { "Pinky" / "Missing" }}};
```
Which would return
```lua
{
  name = "grammar",
  tokens = {
    { 
      name = "Opposables", 
      tokens = { 
        { "type" = "Finger", "content" = "Thumb" }
      }
    },
    { "type" = "Finger", "content" = "Missing" },
    { "type" = "Finger", "content" = "Middle" },
    { 
      name = "Expendables",
      tokens = {
        { "type" = "Finger", "content" = "Ring" },
        { "type" = "Finger", "content" = "Missing" }
      }
    }
  }
}
```


## Installation

fpg does not have any dependencies (besides Lua version >= 5.2)
However, your LUA_PATH environment variable should be altered to allow the files to see one another.
For example

```bash
#!/usr/bin/env bash

# Set LUA_PATH before running a test file.
cd /home/lua/fpg/Test/Languages/Lua
(export LUA_PATH='/home/lua/?.lua;;' \
    lua53 test.lua)
```

You can implement a language yourself by loading its bootstrap file.
For example 
```lua
local luaLang = require "fpg.Languages.Lua.bootstrap"
```
