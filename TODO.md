#TODO

Add something that allows you to freely amend `keywords` and `symbols`.

Make all keywords inherit from `pattern`.

Add a function to pattern that allows you to amend it.
For example:
`expr:amend(function(expr) return expr / my_custom_expr end)`
It'd then shift the original value for `expr` into an upvalue, replacing the value at `expr` with whatever is returned from the function.

Ensure that globals defined in a file will automatically be reachable from any file that calls it.
Look into a way to have a file specific global.
...
setfenv is what I was looking for here.
As it's easy to pollute `_G` and hard to fix it, I propose adding a folder where the user would add their custom syntax.
ebnf (or something else down the line) would then call everything in this folder, passing the `_G` from ebnf.
The user would call this other file when loading the parser, allowing them to get the features without polluting their `_G`
...
`_ENV` is the lua 5.2 solution for this and is much better suited for how I plan to carry this out.

Check to see if any uses of 'pattern' should have been `definition`

Add tests for numbers
Add NaN keyword. Add it to Number.


Strings don't parse properly at the moment. It seems as though whitespace is being cropped out, which you can see in the tests. Investigate further.
